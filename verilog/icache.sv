`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)
`define MSHR_SIZE 4

module icache(
    input clock,
    input reset,
    input [3:0]  Imem2proc_response,
    input [63:0] Imem2proc_data,
    input [3:0]  Imem2proc_tag,

    input [`XLEN-1:0] proc2Icache_addr,

    output logic [1:0] proc2Imem_command,
    output logic [`XLEN-1:0] proc2Imem_addr,

    output logic [63:0] Icache_data_out, // value is memory[proc2Icache_addr]
    output logic Icache_valid_out      // when this is high
);

    //MSHR (temporary set size to 4)
    `ifdef PREFETCH_MODE
        logic [$clog2(`MSHR_SIZE)-1:0]       MSHR_count_1;//allocate
        logic [$clog2(`MSHR_SIZE)-1:0]       MSHR_count_2;//sent
        logic [$clog2(`MSHR_SIZE)-1:0]       MSHR_count_3;//answered

        logic [`MSHR_SIZE-1:0][3:0]          MSHR_response;
        logic [`MSHR_SIZE-1:0][`XLEN-1:0]    MSHR_addr;
        logic [`MSHR_SIZE-1:0]               MSHR_valid;
        logic [`MSHR_SIZE-1:0]               MSHR_sent;
        logic [`CACHE_LINE_BITS - 1:0] mshr_idx;
        logic [12 - `CACHE_LINE_BITS:0] mshr_tag;

        assign {mshr_tag, mshr_idx} = MSHR_addr[MSHR_count_3][15:3];
        assign MSHR_write_enable = (MSHR_response[MSHR_count_3]==Imem2proc_tag) && (Imem2proc_tag != 0) 
                                && MSHR_valid[MSHR_count_3] && MSHR_sent[MSHR_count_3];
    `endif

    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;
    logic [12 - `CACHE_LINE_BITS:0] current_tag, last_tag;

    assign {current_tag, current_index} = proc2Icache_addr[15:3];
    

    logic [3:0] current_mem_tag;
    logic miss_outstanding;

    assign data_write_enable = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);

    assign changed_addr      = (current_index != last_index) || (current_tag != last_tag);

    assign update_mem_tag    = changed_addr || miss_outstanding || data_write_enable;

    assign unanswered_miss   = changed_addr ? !Icache_valid_out :
                                        miss_outstanding && (Imem2proc_response == 0);

   // assign proc2Imem_addr    = {proc2Icache_addr[31:3], 3'b0};
    always @(negedge clock) begin
        $display("icache debug: %h %h %h %h %h", proc2Icache_addr, current_index, last_index, current_tag, last_tag);
        $display("icache debug outstanding, changed_addr: %h %h", miss_outstanding, changed_addr);
    end
    
    
    //assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;
    `ifdef PREFETCH_MODE
        assign proc2Imem_addr    = (miss_outstanding && !changed_addr) ? {proc2Icache_addr[31:3], 3'b0}:
                                                                    MSHR_addr[MSHR_count_2];
                                                                    
        assign proc2Imem_command = ((miss_outstanding && !changed_addr) 
                                || (MSHR_valid[MSHR_count_2] && ~MSHR_sent[MSHR_count_2])) ?  BUS_LOAD : BUS_NONE;
    `else
        assign proc2Imem_addr    = {proc2Icache_addr[31:3], 3'b0};
        assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;
    `endif
    
   
    
    //Cache memory
    logic [`CACHE_LINES-1:0] [63:0]                     data;
    logic [`CACHE_LINES-1:0] [12 - `CACHE_LINE_BITS:0]  tags;
    logic [`CACHE_LINES-1:0]                            valids;

    
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

    assign Icache_data_out = valids[current_index] ? data[current_index] : 64'b0;
    assign Icache_valid_out = valids[current_index] && (tags[current_index] == current_tag);

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

            //prefetch initialize
            //for prefetch
            `ifdef PREFETCH_MODE
                MSHR_response    <= `SD 0;
                MSHR_addr        <= `SD 0;
                MSHR_valid       <= `SD 0;
                MSHR_sent        <= `SD 0;
                MSHR_count_1     <= `SD 0;
                MSHR_count_2     <= `SD 0;
                MSHR_count_3     <= `SD 0;
            `endif

        end else begin
            last_index              <= `SD current_index;
            last_tag                <= `SD current_tag;
            miss_outstanding        <= `SD unanswered_miss;
            
            if (miss_outstanding) begin
                current_mem_tag     <= `SD Imem2proc_response;
            end else if (changed_addr || data_write_enable) begin
                current_mem_tag     <= `SD 4'b0;
            end
            `ifdef PREFETCH_MODE
                //prefetch: add to MSHR
                if (~Icache_valid_out && ~MSHR_valid[MSHR_count_1]) begin
                    MSHR_addr[MSHR_count_1]   <= `SD proc2Icache_addr + 8;
                    MSHR_valid[MSHR_count_1]  <= `SD 1'b1; 
                    MSHR_count_1              <= `SD MSHR_count_1 + 1;
                end

                //prefetch: send request
                if(proc2Imem_addr == MSHR_addr[MSHR_count_2] && MSHR_valid[MSHR_count_2] && ~MSHR_sent[MSHR_count_2]) begin
                    MSHR_sent[MSHR_count_2]  <= `SD 1'b1; 
                    MSHR_response[MSHR_count_2] <= `SD Imem2proc_response;
                    MSHR_count_2             <= `SD MSHR_count_2 + 1;
                end

                //prefetch: write to Icache + clear MSHR entry
                if (MSHR_write_enable) begin
                    data[mshr_idx]                  <= `SD Imem2proc_data;
                    tags[mshr_idx]                  <= `SD mshr_tag;
                    valids[mshr_idx]                <= `SD 1;
                    MSHR_addr[MSHR_count_3]         <= `SD 0;
                    MSHR_valid[MSHR_count_3]        <= `SD 0;
                    MSHR_response[MSHR_count_3]     <= `SD 0;
                    MSHR_sent[MSHR_count_3]         <= `SD 0;
                    MSHR_count_3                    <= `SD MSHR_count_3 + 1; 
                end
            `endif

            if (data_write_enable) begin
                data[current_index]     <= `SD Imem2proc_data;
                tags[current_index]     <= `SD current_tag;
                valids[current_index]   <= `SD 1;
            end
        end
    end

endmodule
