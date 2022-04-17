`ifndef SS_2

`define CACHE_LINES     32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)
`define FETCH_SIZE      4
`define MSHR_SIZE 2

module icache(
    input clock,
    input reset,
    input squash,

    input [3:0]  Imem2proc_response,
    input [63:0] Imem2proc_data,
    input [3:0]  Imem2proc_tag,

    input [`XLEN-1:0] proc2Icache_addr,

    output logic [1:0] proc2Imem_command,
    output logic [`XLEN-1:0] proc2Imem_addr,

    output logic [63:0] Icache_data_out, // value is memory[proc2Icache_addr]
    output logic Icache_valid_out      // when this is high
);
    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;
    logic [12 - `CACHE_LINE_BITS:0] current_tag, last_tag;


    assign {current_tag, current_index} = proc2Icache_addr[15:3];

    //Cache memory
    logic [`CACHE_LINES-1:0] [63:0]                     data;
    logic [`CACHE_LINES-1:0] [12 - `CACHE_LINE_BITS:0]  tags;
    logic [`CACHE_LINES-1:0]                            valids;

    assign Icache_data_out  = valids[current_index] ? data[current_index] : 64'b0;
    assign Icache_valid_out = valids[current_index] && (tags[current_index] == current_tag);

    //MSHR (temporary set size to 4)
    `ifdef PREFETCH_MODE
        logic   [`FETCH_SIZE-1:0]           not_in_cache;
        logic   [`FETCH_SIZE-1:0]           to_fetch;

        logic   [`FETCH_SIZE-1:0][12:0]     mem_addr;
        logic   [`FETCH_SIZE-1:0][3:0]      mem_tag;
        logic   [`FETCH_SIZE-1:0][12:0]     last_mem_addr;
        logic   [`FETCH_SIZE-1:0][3:0]      last_mem_tag;

        logic   [$clog2(`FETCH_SIZE)-1:0]   fetch_idx;
        logic   [`FETCH_SIZE-1:0]           tag_match;

        always_comb begin
            for (int i = 0; i < `FETCH_SIZE; i += 1) begin
                mem_addr[i]     = proc2Icache_addr[15:3] + i;
                mem_tag[i]      = 4'b0;
                for (int j = 0; j < `FETCH_SIZE; j += 1) begin
                    if (mem_addr[i] == last_mem_addr[j]) begin
                        mem_tag[i] = last_mem_tag[j];
                    end
                end
                not_in_cache[i] = ~valids[mem_addr[i][`CACHE_LINE_BITS-1:0]] || ~(tags[mem_addr[i][`CACHE_LINE_BITS-1:0]] == mem_addr[i][12:`CACHE_LINE_BITS]);
                to_fetch[i]     = not_in_cache[i] && (mem_tag[i] == 4'b0);
            end
        end

        inv_ps4_num fetch_selector (
            .req(to_fetch),
            .num(fetch_idx)
        );

        always_comb begin
            for (int i = 0; i < `FETCH_SIZE; i += 1) begin
                tag_match[i]    = (mem_tag[i] == Imem2proc_tag) && (mem_tag[i] != 4'b0);
            end
        end

        assign changed_addr      = (current_index != last_index) || (current_tag != last_tag);

        assign proc2Imem_addr    = {16'b0, mem_addr[fetch_idx], 3'b0};
        assign proc2Imem_command = (~changed_addr && to_fetch[fetch_idx]) ?  BUS_LOAD : BUS_NONE;

        // synopsys sync_set_reset "reset"
        always_ff @(posedge clock) begin
            if(reset) begin
                last_index              <= `SD -1;   // These are -1 to get ball rolling when
                last_tag                <= `SD -1;   // reset goes low because addr "changes"

                data                    <= `SD 0;
                tags                    <= `SD 0;
                valids                  <= `SD `CACHE_LINES'b0;

                last_mem_addr           <= `SD 0; 
                last_mem_tag            <= `SD 0;
            end else begin
                if (squash) begin
                    last_index              <= `SD -1;   // These are -1 to get ball rolling when
                    last_tag                <= `SD -1;   // reset goes low because addr "changes"
                end else begin
                    last_index              <= `SD current_index;
                    last_tag                <= `SD current_tag;
                end

                last_mem_addr           <= `SD mem_addr; 

                for (int i = 0; i < `FETCH_SIZE; i += 1) begin
                    if (i == fetch_idx && to_fetch[i]) begin
                        last_mem_tag[i] <= `SD Imem2proc_response;
                    end else begin
                        if (tag_match[i]) begin
                            data[mem_addr[i][`CACHE_LINE_BITS-1:0]]     <= `SD Imem2proc_data;
                            tags[mem_addr[i][`CACHE_LINE_BITS-1:0]]     <= `SD mem_addr[i][12:`CACHE_LINE_BITS];
                            valids[mem_addr[i][`CACHE_LINE_BITS-1:0]]   <= `SD 1;
                            last_mem_tag[i]                             <= `SD 4'b0;
                        end else begin                      
                            last_mem_tag[i]                             <= `SD mem_tag[i];
                        end
                    end
                end
            end
        end


    `else
        logic [3:0] current_mem_tag;
        logic miss_outstanding;

        assign data_write_enable = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);
        assign changed_addr      = (current_index != last_index) || (current_tag != last_tag);
        assign update_mem_tag    = changed_addr || miss_outstanding || data_write_enable;
        assign unanswered_miss   = changed_addr ? !Icache_valid_out :
                                        miss_outstanding && (Imem2proc_response == 4'b0);
        assign proc2Imem_addr    = {proc2Icache_addr[31:3], 3'b0};
        assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;

        // synopsys sync_set_reset "reset"
        always_ff @(posedge clock) begin
            if(reset) begin
                last_index              <= `SD -1;   // These are -1 to get ball rolling when
                last_tag                <= `SD -1;   // reset goes low because addr "changes"
                current_mem_tag         <= `SD 0;
                miss_outstanding        <= `SD 0;
                data                    <= `SD 0;
                tags                    <= `SD 0;
                valids                  <= `SD `CACHE_LINES'b0;  
            end else if (squash) begin
                last_index              <= `SD -1;   // These are -1 to get ball rolling when
                last_tag                <= `SD -1;   // reset goes low because addr "changes"
                current_mem_tag         <= `SD 0;
                miss_outstanding        <= `SD 0;
            end else begin
                last_index              <= `SD current_index;
                last_tag                <= `SD current_tag;
                miss_outstanding        <= `SD unanswered_miss;
                
                if (miss_outstanding) begin
                    current_mem_tag     <= `SD Imem2proc_response;
                end else if (changed_addr || data_write_enable) begin
                    current_mem_tag     <= `SD 4'b0;
                end

                if (data_write_enable) begin
                    data[current_index]     <= `SD Imem2proc_data;
                    tags[current_index]     <= `SD current_tag;
                    valids[current_index]   <= `SD 1;
                end
            end
        end
    `endif
    


    `ifdef DEBUG
    always @(negedge clock) begin
        $display("icache debug: %h %h %h %h %h", proc2Icache_addr, current_index, last_index, current_tag, last_tag);
        $display("icache debug outstanding, changed_addr: %h %h", miss_outstanding, changed_addr);
    end
    `endif
    
    // DEBUG show the icache state
    `ifdef DEBUG
    logic [31:0] cycle_count;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `CACHE_LINES; i += 1) begin
                $display("DEBUG %4d: icache[%2d]: valids = %h, tags = %h, data = %h", cycle_count, i, valids[i], tags[i], data[i]);
            end
            cycle_count = cycle_count + 1;
        end
    end
    `endif
endmodule

`endif