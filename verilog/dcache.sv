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

    // Address
    input [`XLEN-1:0] proc2Dcache_addr, //MUX logic outside

    // Write data
    input [63:0] proc2Dcache_data, 

    //Load output
    output logic [63:0] Dcache_data_out, // value is memory[proc2Dcache_addr]
    output logic Dcache_valid_out,      // when this is high

    //Store output
    output logic write_done, //if data is written into dcache

    //Output to Dmem
    output logic [63:0]             proc2Dmem_data,
    output logic [1:0]              proc2Dmem_command,
    output logic [`XLEN-1:0]        proc2Dmem_addr
    );

    //Cache memory (2-way associative + LRU)
    logic [1:0][`CACHE_LINES-1:0] [63:0]                     data;
    logic [1:0][`CACHE_LINES-1:0] [12 - `CACHE_LINE_BITS:0]  tags;
    logic [1:0][`CACHE_LINES-1:0]                            valids;
    logic [1:0][`CACHE_LINES-1:0]                            dirty;
    logic [`CACHE_LINES-1:0]                                 LRU_idx, LRU_next;

    logic [`CACHE_LINE_BITS - 1:0]  current_index;
    logic [12 - `CACHE_LINE_BITS:0] current_tag;
    logic [3:0]                     current_mem_tag;

    //Load from mem
    logic data_write_enable; 
    logic write2mem;
    assign {current_tag, current_idx} = proc2Dcache_addr[15:3];

    assign data_write_enable = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);
    assign proc2Dmem_addr    = (write2mem) ? {16'b0,current_tag, current_idx,3'b0}: {proc2Dcache_addr[31:3],3'b0};
    assign proc2Dmem_command = (read_en && ~Dcache_valid_out) ? BUS_LOAD :  
                               (write2mem) ? BUS_STORE : BUS_NONE; 
    assign proc2Dmem_data    = (write2mem && dirty[LRU_idx[current_idx]]) ? data[LRU_idx[current_idx]] : 64'b0;
    
    
    
    //Read from Dcache
    assign Dcache_data_out = (read_en && tags[0][current_index] == current_tag && valids[0][current_index]) ? data[0][current_index] :
                             (read_en && tags[1][current_index] == current_tag && valids[1][current_index]) ? data[1][current_index] : 64'b0; 

    assign Dcache_valid_out = read_en && ((tags[0][current_index] == current_tag && valids[0][current_index]) ||
                                          (tags[1][current_index] == current_tag && valids[1][current_index]));

    

    //Update LRU                
    always_comb begin
        LRU_next = LRU_idx;
        if (data_write_enable || write_en) begin
            LRU_next[current_idx] += 1;
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            valids[0]       <= `SD 0;
            valids[1]       <= `SD 0;
            LRU_idx         <= `SD 0;
            current_mem_tag <= `SD 0;
            write2mem       <= `SD 0;
        end else begin
            current_mem_tag <= `SD Dmem2proc_response;
            if (data_write_enable || write_en) begin
                valids[LRU_idx[current_idx]] <= `SD 1'b1;
                tags[LRU_idx[current_idx]]   <= `SD current_tag;
                data[LRU_idx[current_idx]]   <= `SD (data_write_enable) ? Dmem2proc_data : proc2Dcache_data;
                write_done                   <= `SD ~data_write_enable && write_en;
                if (tags[LRU_idx[current_idx]] == current_tag) begin
                    dirty[LRU_idx[current_idx]] <= `SD 1'b1;
                end else begin
                    write2mem <= `SD dirty[LRU_idx[current_idx]];
                end
            end
            LRU_idx   <= `SD LRU_next;
        end
    end

endmodule
`endif