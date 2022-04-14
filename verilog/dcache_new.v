/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_V__
`define __DCACHE_V__

`timescale 1ns/100ps

module dcache (
    input                                   clock,
    input                                   reset,
    // From Pipeline
    input                                   chosen2Mem,

    // From Dmem
    input                                   Dmem2proc_valid,
    input [3:0]                             Dmem2proc_response,
    input [63:0]                            Dmem2proc_data,
    input [3:0]                             Dmem2proc_tag,

    // To Dmem
    output logic                            proc2Dmem_valid,
    output logic [63:0]                     proc2Dmem_data,
    output logic [1:0]                      proc2Dmem_command,
    output logic [`XLEN-1:0]                proc2Dmem_addr,

    // From LSQ
    input LSQ_LOAD_DCACHE_PACKET            lsq_load_dc,
    input LSQ_STORE_DCACHE_PACKET           lsq_store_dc,

    // To LSQ
    output DCACHE_LOAD_LSQ_PACKET           dc_load_lsq,
    output DCACHE_STORE_LSQ_PACKET          dc_store_lsq
);
    logic load_hit, store_hit, mem_en;
    logic [`XLEN-1:0] mem_addr;
    logic [63:0] mem_data;
    EXAMPLE_CACHE_BLOCK store_data_in, read_data_out;

    dcache_control dcache_control_0(
        .clock(clock),
        .reset(reset),  
        .chosen2Mem(chosen2Mem),

        .Dmem2proc_valid(Dmem2proc_valid),
        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_tag(Dmem2proc_tag),
 
        //From LSQ
        //.load_en(lsq_load_dc.valid && (~lsq_store_dc.halt || ~lsq_store_dc.valid)),
        .load_en(lsq_load_dc.valid),
        .load_addr(lsq_load_dc.addr),
        //.store_en(lsq_store_dc.valid && ~lsq_store_dc.halt),
        .store_en(lsq_store_dc.valid),
        .store_addr(lsq_store_dc.addr),


        //From Dcache
        .load_hit_in(load_hit),
        .store_hit_in(store_hit),
        .store_data_in(store_data_in),

        //OUTPUT
        
        //TO Dcache
        .mem_en(mem_en),
        .mem_addr_out(mem_addr),
        .mem_data_out(mem_data),
    
        //TO LSQ
        .store_complete(dc_store_lsq.valid),
        .halt_valid(dc_store_lsq.halt_valid),

        //TO Dmem
        .proc2Dmem_valid(proc2Dmem_valid),
        .proc2Dmem_data(proc2Dmem_data),
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr)
        );

     dcahce_in dcache_in_0(
        .clock(clock),
        .reset(reset),

        .read_en(lsq_load_dc.valid && (~lsq_store_dc.halt || ~lsq_store_dc.valid)),
        .read_addr(lsq_load_dc.addr),
        .write_en(lsq_store_dc.valid && ~lsq_store_dc.halt),
        .write_addr(lsq_store_dc.addr),
        .write_mem_size(lsq_store_dc.mem_size),
        .write_data_in(lsq_store_dc.value),

        .mem_en(mem_en),
        .mem_addr(mem_addr),
        .mem_data_in(mem_data),

        .read_hit(dc_load_lsq.valid),
        .read_data_out(read_data_out),
        .write_data_out(store_data_in),
        .write_hit(store_hit));

    always_comb begin
        dc_load_lsq.value = 32'b0;
        if (dc_load_lsq.valid) begin
            casez (lsq_load_dc.mem_size)
                BYTE: dc_load_lsq.value = {24'b0,   read_data_out.byte_level[lsq_load_dc.addr[2:0]]};
                HALF: dc_load_lsq.value = {16'b0,   read_data_out.half_level[lsq_load_dc.addr[2:1]]};
                WORD: dc_load_lsq.value =           read_data_out.word_level[lsq_load_dc.addr[2]];
            endcase
        end 
    end

    

endmodule
`endif