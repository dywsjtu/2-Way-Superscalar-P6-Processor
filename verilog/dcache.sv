/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`define DEBUG
`ifndef __DCACHE_V__
`define __DCACHE_V__

`timescale 1ns/100ps

`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

module dcache(
    input clock,
    input reset,
    input stall,

    //From Dmem
    input [3:0]  Dmem2proc_response,
    input [63:0] Dmem2proc_data,
    input [3:0]  Dmem2proc_tag,

    //From LSQ
    input LSQ_LOAD_DCACHE_PACKET  lsq_load,
    input LSQ_STORE_DCACHE_PACKET lsq_store,

    //To LSQ
    output DCACHE_STORE_LSQ_PACKET dcache_store,
    output DCACHE_LOAD_LSQ_PACKET  dcache_load,

    //To Dmem
    `ifndef CACHE_MODE
	    output  MEM_SIZE proc2Dmem_size, //BYTE, HALF, WORD or DOUBLE
    `endif
    output logic [`XLEN-1:0]        proc2Dmem_data,
    output logic [1:0]              proc2Dmem_command,
    output logic [`XLEN-1:0]        proc2Dmem_addr
);
    assign  dcache_store.halt_valid = 1'b1; // TODO: Change this.

    //Cache memory (2-way associative + LRU)
    logic [1:0][`CACHE_LINES-1:0] [31:0]                     data;
    logic [1:0][`CACHE_LINES-1:0] [13 - `CACHE_LINE_BITS:0]  tags;
    logic [1:0][`CACHE_LINES-1:0]                            valids;
    //logic [1:0][`CACHE_LINES-1:0]                            dirty;
    logic [`CACHE_LINES-1:0]                                 LRU_idx, LRU_next;

    logic [`CACHE_LINE_BITS - 1:0]  current_idx_l, current_idx_s, current_idx;
    logic [13 - `CACHE_LINE_BITS:0] current_tag_l, current_tag_s,current_tag;
    logic [3:0]                     current_mem_tag;

    //Load from mem
    logic data_write_enable; 
    logic write2mem;
    logic block_idx; 

    assign {current_tag_l, current_idx_l} = lsq_load.addr[15:2];
    assign {current_tag_s, current_idx_s} = lsq_store.addr[15:2];
    assign data_write_enable = lsq_load.valid && (Dmem2proc_response == Dmem2proc_tag) && (Dmem2proc_response != 0);
    //assign data_write_enable = (current_mem_tag == Dmem2proc_tag) && (current_mem_tag != 0);
    assign proc2Dmem_addr    = (lsq_load.valid && ~dcache_load.valid) ? {lsq_load.addr[31:2],2'b0} :  
                               (write2mem) ? {lsq_store.addr[31:2],2'b0} : BUS_NONE; 
    //assign proc2Dmem_addr = (write2mem) ? {16'b0,tags[block_idx][current_idx_s], current_idx_s,2'b0}: {lsq_load.addr[31:2],2'b0};
    assign proc2Dmem_command = (lsq_load.valid && ~dcache_load.valid) ? BUS_LOAD :  
                               (write2mem) ? BUS_STORE : BUS_NONE; 
    assign proc2Dmem_data    = (write2mem) ? lsq_store.value : 32'b0;
    `ifndef CACHE_MODE
	    assign proc2Dmem_size = WORD; 
    `endif
    
    

    
    //Read from Dcache
    logic hit0,hit1;
    assign hit0 = lsq_load.valid && tags[0][current_idx_l] == current_tag && valids[0][current_idx_l];
    assign hit1 = lsq_load.valid && tags[1][current_idx_l] == current_tag && valids[1][current_idx_l];
    assign dcache_load.value = hit0 ? data[0][current_idx_l] :
                             hit1 ? data[1][current_idx_l] : 32'b0; 
    assign dcache_load.valid = hit0 || hit1;

    assign current_idx =  (data_write_enable) ? current_idx_l : current_idx_s;
    assign current_tag =  (data_write_enable) ? current_tag_l : current_idx_s;
    
    //Update LRU
                   
    always_comb begin
        LRU_next = LRU_idx;
        //WRITE
        if (data_write_enable || lsq_store.valid) begin
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
        //READ
        if (hit0 || hit1) begin
            if(current_tag_l == tags[0][current_idx_l] && valids[0][current_idx_l]) begin
                block_idx             = 1'b0;
                LRU_next[current_idx_l] = 1'b1;
            end else if (current_tag_l == tags[1][current_idx_l] && valids[1][current_idx_l]) begin
                block_idx             = 1'b1;
                LRU_next[current_idx_l] = 1'b0;
            end else begin
                block_idx             = LRU_idx[current_idx_l];
                LRU_next[current_idx_l] = LRU_idx[current_idx_l] + 1;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 2; i += 1) begin
                valids[i]   <= `SD 0;
                tags[i]     <= `SD 0;
                data[i]     <= `SD 0;
            end
            LRU_idx         <= `SD 0;
            current_mem_tag <= `SD 0;
            write2mem       <= `SD 0;
        end else begin
            current_mem_tag <= `SD Dmem2proc_response;
            if (lsq_store.valid || data_write_enable) begin
                valids[block_idx][current_idx] <= `SD 1'b1;
                tags[block_idx][current_idx]   <= `SD current_tag;
                data[block_idx][current_idx]   <= `SD (data_write_enable) ? Dmem2proc_data : lsq_store.value;
                dcache_store.valid <= ~data_write_enable && lsq_store.valid;
                write2mem <= `SD (data_write_enable) ? 1'b0 : 
                                                       (lsq_store.valid && tags[block_idx][current_idx] != current_tag);
            end else begin
                write2mem       <= `SD 0;
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
                    $display("DEBUG %4d: data[%4d] = %d, tag[%4d]=%d, valids[%4d]=%d", cycle_count,i,data[0][i],i,tags[0][i],i,valids[0][i]);
                end
                $display("Block 1:");
                for(int i = 0; i < `CACHE_LINES; i +=1) begin
                    $display("DEBUG %4d: data[%4d] = %d, tag[%4d]=%d, valids[%4d]=%d", cycle_count,i,data[1][i],i,tags[1][i],i,valids[1][i]);
                end
                //$display("DEBUG %4d: data_write_enable = %d", cycle_count, data_write_enable);
                $display("DEBUG %4d: load_idx = %d, load_tag = %d", cycle_count, current_idx_l, current_tag_l);
                $display("DEBUG %4d: store_idx = %d, store_tag = %d", cycle_count, current_idx_s, current_tag_s);
                //$display("DEBUG %4d: Dmem2proc_tag = %d, Dmem2proc_response = %d", cycle_count, Dmem2proc_tag, Dmem2proc_response);
                $display("DEBUG %4d: proc2Dmem_command = %d, proc2Dmem_addr = %d, proc2Dmem_data = %d", cycle_count, proc2Dmem_command, proc2Dmem_addr, proc2Dmem_data);
                //$display("DEBUG %4d: proc2Dcache_addr = 0x%x, current_tag = %d, current_idx = %d", cycle_count, proc2Dcache_addr, current_tag, current_idx);
                $display("DEBUG %4d: read_en = %d, hit0 = %d, hit1 = %d, Dcache_data_out = %d, hit = %d", cycle_count, lsq_load.valid, hit0, hit1, dcache_load.value, dcache_load.valid);
                cycle_count += 1;
            end
        end
        always_ff @(posedge clock) begin
            $display("DEBUG %4d: current_mem_tag = %d, Dmem2proc_tag = %d, Dmem2proc_response = %d", cycle_count, current_mem_tag, Dmem2proc_tag, Dmem2proc_response);
        end
    `endif

endmodule
`endif