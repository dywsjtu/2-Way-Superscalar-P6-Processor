`ifndef __ICACHE_L2__
`define __ICACHE_L2__

`define ICACHE_LINES_L2         16
`define ICACHE_LINE_BITS_L2     $clog2(`ICACHE_LINES_L2)
`define ICACHE_LINE_SIZE_L2     2
`define ICACHE_FETCH_SIZE_L2    4

module icache_l2 (
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
    logic   [`ICACHE_LINE_BITS_L2 - 1:0]      current_index, last_index;
    logic   [12 - `ICACHE_LINE_BITS_L2:0]     current_tag, last_tag;


    assign  {current_tag, current_index} = proc2Icache_addr[15:3];

    //Cache memory
    logic   [`ICACHE_LINE_SIZE_L2-1:0] [`ICACHE_LINES_L2-1:0] [63:0]                        data;
    logic   [`ICACHE_LINE_SIZE_L2-1:0] [`ICACHE_LINES_L2-1:0] [12 - `ICACHE_LINE_BITS_L2:0] tags;
    logic   [`ICACHE_LINE_SIZE_L2-1:0] [`ICACHE_LINES_L2-1:0]                               valids;

    logic   match_0, match_1;
    assign  match_0          =  valids[0][current_index] && (tags[0][current_index] == current_tag);
    assign  match_1          =  valids[1][current_index] && (tags[1][current_index] == current_tag);
    assign  Icache_data_out  =  match_0 ? data[0][current_index] : 
                                match_1 ? data[1][current_index] : 64'b0;
    assign  Icache_valid_out =  match_0 || match_1;


    logic   [`ICACHE_FETCH_SIZE_L2-1:0]           not_in_cache;
    logic   [`ICACHE_FETCH_SIZE_L2-1:0]           to_fetch;

    logic   [`ICACHE_FETCH_SIZE_L2-1:0][12:0]     mem_addr;
    logic   [`ICACHE_FETCH_SIZE_L2-1:0][3:0]      mem_tag;
    logic   [`ICACHE_FETCH_SIZE_L2-1:0][12:0]     last_mem_addr;
    logic   [`ICACHE_FETCH_SIZE_L2-1:0][3:0]      last_mem_tag;

    logic   [$clog2(`ICACHE_FETCH_SIZE_L2)-1:0]   fetch_idx;
    logic   [`ICACHE_FETCH_SIZE_L2-1:0]           tag_match;

    always_comb begin
        for (int i = 0; i < `ICACHE_FETCH_SIZE_L2; i += 1) begin
            mem_addr[i]     = proc2Icache_addr[15:3] + i;
            mem_tag[i]      = 4'b0;
            for (int j = 0; j < `ICACHE_FETCH_SIZE_L2; j += 1) begin
                if (mem_addr[i] == last_mem_addr[j]) begin
                    mem_tag[i] = last_mem_tag[j];
                end
            end
            not_in_cache[i] = (~valids[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]] || ~(tags[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]] == mem_addr[i][12:`ICACHE_LINE_BITS_L2])) &&
                              (~valids[1][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]] || ~(tags[1][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]] == mem_addr[i][12:`ICACHE_LINE_BITS_L2]));
            to_fetch[i]     = not_in_cache[i] && (mem_tag[i] == 4'b0);
        end
    end

    inv_ps4_num fetch_selector (
        .req(to_fetch),
        .num(fetch_idx)
    );

    always_comb begin
        for (int i = 0; i < `ICACHE_FETCH_SIZE_L2; i += 1) begin
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
            valids                  <= `SD 0;

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

            for (int i = 0; i < `ICACHE_FETCH_SIZE_L2; i += 1) begin
                if (i == fetch_idx && to_fetch[i]) begin
                    last_mem_tag[i] <= `SD Imem2proc_response;
                end else begin
                    if (tag_match[i]) begin
                        data[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]      <= `SD Imem2proc_data;
                        tags[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]      <= `SD mem_addr[i][12:`ICACHE_LINE_BITS_L2];
                        valids[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]    <= `SD 1;
                        data[1][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]      <= `SD data[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]];
                        tags[1][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]      <= `SD tags[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]];
                        valids[1][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]]    <= `SD valids[0][mem_addr[i][`ICACHE_LINE_BITS_L2-1:0]];
                        last_mem_tag[i]                                 <= `SD 4'b0;
                    end else begin
                        last_mem_tag[i]                                 <= `SD mem_tag[i];
                    end
                end
            end
        end
    end



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
            for(int i = 0; i < `ICACHE_LINES_L2; i += 1) begin
                $display("DEBUG %4d: icache[%2d]: valids = %h, tags = %h, data = %h", cycle_count, i, valids[i], tags[i], data[i]);
            end
            cycle_count = cycle_count + 1;
        end
    end
    `endif
endmodule

`endif