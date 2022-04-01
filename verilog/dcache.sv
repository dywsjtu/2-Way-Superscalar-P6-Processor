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

    logic [`CACHE_LINE_BITS - 1:0]  current_idx;
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
    logic hit0,hit1;
    assign hit0 = read_en && tags[0][current_idx] == current_tag && valids[0][current_idx];
    assign hit1 = read_en && tags[1][current_idx] == current_tag && valids[1][current_idx];
    assign Dcache_data_out = hit0 ? data[0][current_idx] :
                             hit1 ? data[1][current_idx] : 64'b0; 
    assign Dcache_valid_out = hit0 || hit1;

    
    //Update LRU
    logic block_idx;                
    always_comb begin
        LRU_next = LRU_idx;
        if (data_write_enable || write_en) begin
            if(current_tag == tags[0][current_idx] && valids[0][current_idx]) begin
                block_idx             = 1'b0;
                LRU_next[current_idx] = 1'b1;
            end else if (current_tag == tags[1][current_idx] && valids[1][current_idx]) begin
                block_idx             = 1'b1;
                LRU_next[current_idx] = 1'b0;
            end else begin
                block_idx             = LRU_idx[current_idx];
                LRU_next[current_idx] = LRU_idx[current_idx] + 1;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 2; i += 1) begin
                valids[i]   <= `SD 0;
                tags[i]     <= `SD 0;
                dirty[i]    <= `SD 0;
                data[i]     <= `SD 0;
            end
            LRU_idx         <= `SD 0;
            current_mem_tag <= `SD 0;
            write2mem       <= `SD 0;
        end else begin
            current_mem_tag <= `SD Dmem2proc_response;
            if (write_en || data_write_enable) begin
                valids[block_idx][current_idx] <= `SD 1'b1;
                tags[block_idx][current_idx]   <= `SD current_tag;
                //data[block_idx][current_idx]   <= `SD proc2Dcache_data;
                data[block_idx][current_idx]   <= `SD (data_write_enable) ? Dmem2proc_data : proc2Dcache_data;
                if (write_en && tags[block_idx][current_idx] == current_tag && data[block_idx][current_idx] != proc2Dcache_data && valids[block_idx][current_idx]) begin
                    dirty[block_idx][current_idx] <= `SD 1'b1;
                end else begin
                    write2mem <= `SD dirty[block_idx][current_idx];
                end
            end
            LRU_idx   <= `SD LRU_next;
        end
    end

    `ifdef DEBUG
        logic [31:0] cycle_count;
        always_ff @(negedge clock) begin
            if (reset) begin
                cycle_count = 0;
                $display("Reset");
            end
            else begin
                $display("Block 0:");
                for(int i = 0; i < `CACHE_LINES; i +=1) begin
                    $display("DEBUG %4d: data[%4d] = %d, tag[%4d]=%d, valids[%4d]=%d, dirty[%4d]=%d", cycle_count,i,data[0][i],i,tags[0][i],i,valids[0][i], i, dirty[0][i]);
                end
                $display("Block 1:");
                for(int i = 0; i < `CACHE_LINES; i +=1) begin
                    $display("DEBUG %4d: data[%4d] = %d, tag[%4d]=%d, valids[%4d]=%d, dirty[%4d]=%d", cycle_count,i,data[1][i],i,tags[1][i],i,valids[1][i], i, dirty[1][i]);
                end
                $display("DEBUG %4d: data_write_enable = %d", cycle_count, data_write_enable);
                //$display("DEBUG %4d: Dmem2proc_tag = %d, Dmem2proc_response = %d", cycle_count, Dmem2proc_tag, Dmem2proc_response);
                $display("DEBUG %4d: proc2Dmem_command = %d, proc2Dmem_addr = %d", cycle_count, proc2Dmem_command, proc2Dmem_addr);
                $display("DEBUG %4d: proc2Dcache_addr = 0x%x, current_tag = %d, current_idx = %d", cycle_count, proc2Dcache_addr, current_tag, current_idx);
                $display("DEBUG %4d: read_en = %d, hit0 = %d, hit1 = %d, Dcache_data_out = %d, hit = %d", cycle_count, read_en, hit0, hit1, Dcache_data_out, Dcache_valid_out);
                cycle_count += 1;
            end
        end
    `endif

endmodule
`endif