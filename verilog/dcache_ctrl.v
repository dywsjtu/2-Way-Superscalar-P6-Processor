/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_CTRL_V__
`define __DCACHE_CTRL_V__

`timescale 1ns/100ps



module dcache_control (
    input logic clock,
    input logic reset,
    input logic chosen2Mem,  

    //From Dmem
    input logic                                   Dmem2proc_valid,
    input logic [3:0]                             Dmem2proc_response,
    input logic [63:0]                            Dmem2proc_data,
    input logic [3:0]                             Dmem2proc_tag,

    //From LSQ
    input logic load_en,
    input logic [`XLEN-1:0] load_addr,
    input logic store_en,
    input logic [`XLEN-1:0] store_addr,
    //input logic [63:0] store_data,
   

    //From Dcache
    input logic load_hit_in,
    input logic store_hit_in,
    input logic [63:0] store_data_in,

    //OUTPUT

    //TO Dcache
    output   logic mem_en,
    output   logic [`XLEN-1:0] mem_addr_out,
    output   logic [63:0]      mem_data_out,
    
    //TO LSQ
    output logic store_complete,
    output logic halt_valid,

    //TO Dmem
    output logic                            proc2Dmem_valid,
    output logic [63:0]                     proc2Dmem_data,
    output logic [1:0]                      proc2Dmem_command,
    output logic [`XLEN-1:0]                proc2Dmem_addr
);

    MISS_ENTRY_NEW      [`MISS_LINES-1:0]       mshr_entries, next_mshr_entries;

    logic temp_valid, request_sent;



    always_comb begin

        //Initialize
        next_mshr_entries   = mshr_entries;
        store_complete      = 1'b0;
        mem_en              = 1'b0;
        halt_valid          = 1'b1;
        
        //Check output from Dmem
        if (Dmem2proc_valid) begin
            temp_valid = 1'b0;
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (~temp_valid && Dmem2proc_tag != 0 && mshr_entries[i].valid && mshr_entries[i].sent && mshr_entries[i].tag == Dmem2proc_tag) begin
                    mem_en = 1'b1;
                    temp_valid = 1'b1;
                    mem_addr_out = mshr_entries[i].addr;
                    mem_data_out = Dmem2proc_data;
                    next_mshr_entries[i] = 0;
                end
            end
        end

        //Update MSHR
        if (load_en && ~load_hit_in) begin
            temp_valid = 1'b0;
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (~temp_valid && next_mshr_entries[i].valid && next_mshr_entries[i].addr[`XLEN-1:3] == load_addr[`XLEN-1:3]) begin
                    temp_valid = 1'b1;
                end
            end

            if (~temp_valid) begin
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (~temp_valid && ~next_mshr_entries[i].valid && ~next_mshr_entries[i].sent) begin
                        temp_valid = 1'b1;
                        next_mshr_entries[i].valid = 1'b1;
                        next_mshr_entries[i].sent  = 1'b0;
                        next_mshr_entries[i].addr = {load_addr[`XLEN-1:3],3'b0};
                    end
                end
            end
            
        end

        if (store_en && ~store_hit_in) begin //Load block before store
            temp_valid      = 1'b0;
            halt_valid      = 1'b0;
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (~temp_valid && next_mshr_entries[i].valid && next_mshr_entries[i].addr[`XLEN-1:3] == store_addr[`XLEN-1:3]) begin
                    temp_valid = 1'b1;
                end
            end
            if (~temp_valid) begin
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (~temp_valid && ~next_mshr_entries[i].valid && ~next_mshr_entries[i].sent) begin
                        temp_valid = 1'b1;
                        next_mshr_entries[i].valid = 1'b1;
                        next_mshr_entries[i].sent  = 1'b0;
                        next_mshr_entries[i].addr = {store_addr[`XLEN-1:3], 3'b0};
                    end
                end
            end
            
        end

        //Send request to Dmem
        proc2Dmem_valid     = 1'b0;
        proc2Dmem_data      = 64'b0;
        proc2Dmem_command   = BUS_NONE;
        proc2Dmem_addr      = `XLEN'b0;

        if (store_hit_in && store_en) begin
            proc2Dmem_valid     = 1'b1;
            proc2Dmem_data      = store_data_in;
            proc2Dmem_command   = BUS_STORE;
            proc2Dmem_addr      = {store_addr[`XLEN-1:3], 3'b0};
            store_complete      = (Dmem2proc_response != 4'b0) && chosen2Mem;
            halt_valid          = (Dmem2proc_response != 4'b0) && chosen2Mem;
            request_sent        = 1'b1;
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (next_mshr_entries[i].valid && next_mshr_entries[i].addr[`XLEN-1:3] == proc2Dmem_addr[`XLEN-1:3]) begin
                    next_mshr_entries[i].valid = 1'b0;
                    next_mshr_entries[i].sent = 1'b0;
                end
            end
        end else begin
            request_sent = 1'b0;
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (~request_sent && next_mshr_entries[i].valid && ~next_mshr_entries[i].sent) begin
                    proc2Dmem_valid     = 1'b1;
                    proc2Dmem_data      = 64'b0;
                    proc2Dmem_command   = BUS_LOAD;
                    proc2Dmem_addr      = next_mshr_entries[i].addr;
                    next_mshr_entries[i].tag = Dmem2proc_response;
                    next_mshr_entries[i].sent = (Dmem2proc_response != 4'b0) && chosen2Mem;
                    request_sent = 1'b1;
                end
            end
        end

    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            mshr_entries <= `SD 0;
        end else begin
            mshr_entries <= `SD next_mshr_entries;
        end
    end
    `ifdef DEBUG
    logic [31:0] cycle_count;
    MISS_ENTRY cur_entry;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `MISS_LINES; i += 1) begin
                cur_entry = mshr_entries[i];
                $display("DEBUG %4d: MSHR[%2d] = %p", cycle_count, i, cur_entry);
            end
            $display("proc2Dmemcommand = %b", proc2Dmem_command);
            cycle_count = cycle_count + 1;
        end
    end
    `endif


endmodule
`endif

