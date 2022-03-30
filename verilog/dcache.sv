/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv                                           //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __DCACHE_V__
`define __DCACHE_V__

`timescale 1ns/100ps

`define CACHE_LINES 16
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

module dcache(
    input clock,
    input reset,

    //Feedback from Dmem
    input [3:0]  Dmem2proc_response,
    input [63:0] Dmem2proc_data,
    input [3:0]  Dmem2proc_tag,

    //Control signals
    input read_en,
    input write_en,

    //Read from Dcache
    input [`XLEN-1:0] proc2Dcache_addr_r,

    //Write to Dcache
    input [`XLEN-1:0] proc2Dcache_addr_w,
    input [`XLEN-1:0] proc2Dcache_data, //TODO: change to allow different sizes

    //Read from Dcache
    output logic [63:0] Dcache_data_out, // value is memory[proc2Dcache_addr]
    output logic Dcache_valid_out      // when this is high

    //Write to Dcache
    output logic [1:0] proc2Dmem_command,
    output logic [`XLEN-1:0] proc2Dmem_addr,
    );

    //Cache memory (2-way associative)
    logic [1:0][`CACHE_LINES-1:0] [63:0]                     data;
    logic [1:0][`CACHE_LINES-1:0] [12 - `CACHE_LINE_BITS:0]  tags;
    logic [1:0][`CACHE_LINES-1:0]                            valids;
    logic [`CACHE_LINES-1:0]                                 LRU_idx;

    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;
    logic [12 - `CACHE_LINE_BITS:0] current_tag, last_tag;

    logic data_write_enable; //load from mem
    assign data_write_enable = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);

    //for now defer WRITE for READ
    assign {current_tag, current_index} = (read_en)  ? proc2Dcache_addr_r[15:3] :
                                          (write_en) ? proc2Dcache_addr_w[15:3] : 13'b0;
    

    //Read from Dcache
    assign Dcache_data_out = (~read_en) ? 64'b0:
                      (tags[0][current_index] == current_tag && valids[0][current_index]) ? data[0][current_index] :
                      (tags[1][current_index] == current_tag && valids[1][current_index]) ? data[1][current_index] :
                      64'b0; 
    assign Dcache_valid_out = read_en && 
                              ((tags[0][current_index] == current_tag && valids[0][current_index]) ||
                              (tags[1][current_index] == current_tag && valids[1][current_index]));
                    
    always_comb begin
        LRU_next = LRU_idx;
        if (data_write_enable || write_en) begin
            LRU_next[current_idx] += 1;
        end
    end
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            valids[0] <= `SD 0;
            valids[0] <= `SD 0;
            LRU_idx   <= `SD 0;
        end else begin
            if (data_write_enable || write_en) begin
                valids[LRU_idx[current_idx]] <= `SD 1'b1;
                tags[LRU_idx[current_idx]]   <= `SD current_tag;
                data[LRU_idx[current_idx]]   <= `SD (data_write_enable) ? Dmem2proc_data : proc2Dcache_data;
            end
            LRU_idx   <= `SD LRU_next;
        end
    end

endmodule
`endif