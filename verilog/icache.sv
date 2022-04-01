`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

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

    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;
    logic [12 - `CACHE_LINE_BITS:0] current_tag, last_tag;

    assign {current_tag, current_index} = proc2Icache_addr[15:3];

    logic [3:0] current_mem_tag;
    // Trying to implement prefetching here ... 
    logic [1:0] miss_offset; // Goes from 3 -> 2 -> 1 -> 0 as we prefetch memory at the offset

    wire [`CACHE_LINE_BITS - 1:0] current_index_offset;

    assign current_index_offset = current_index + miss_offset; // Index plus offset

    assign data_write_enable = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);

    assign changed_addr      = (current_index != last_index) || (current_tag != last_tag);

    assign update_mem_tag    = changed_addr || miss_outstanding || data_write_enable;

    assign proc2Imem_addr    = {proc2Icache_addr[31:3] + miss_offset, 3'b0};
    always @(negedge clock) begin
        $display("icache debug: %h %h %h %h %h", proc2Icache_addr, current_index, last_index, current_tag, last_tag);
        $display("icache debug outstanding, changed_addr: %h %h", miss_outstanding, changed_addr);
    end
    assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;

    //Cache memory
    logic [`CACHE_LINES-1:0] [63:0]                     data;
    logic [`CACHE_LINES-1:0] [12 - `CACHE_LINE_BITS:0]  tags;
    logic [`CACHE_LINES-1:0]                            valids;

    assign Icache_data_out = data[current_index];
    assign Icache_valid_out = valids[current_index] && (tags[current_index] == current_tag);

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            last_index       <= `SD -1;   // These are -1 to get ball rolling when
            last_tag         <= `SD -1;   // reset goes low because addr "changes"
            current_mem_tag  <= `SD 0;
            miss_offset      <= `SD 0;

            valids <= `SD `CACHE_LINES'b0;  
        end else begin
            last_index              <= `SD current_index;
            last_tag                <= `SD current_tag;
            if(miss_offset == 0 && changed_addr && !Icache_valid_out) begin // Initial miss
                miss_offset <= `SD 3;
            end
            else if(miss_offset != 0 && Imem2proc_response == 0) begin // Hit prefetch, now reduce offset
                miss_offset <= `SD miss_offset - 1;
            end


            if(update_mem_tag)
                current_mem_tag     <= `SD Imem2proc_response;

                if(data_write_enable) begin
                    data[current_index_offset]     <= `SD Imem2proc_data;
                    tags[current_index_offset]     <= `SD current_tag;
                    valids[current_index_offset]   <= `SD 1;
                end
        end
    end

endmodule