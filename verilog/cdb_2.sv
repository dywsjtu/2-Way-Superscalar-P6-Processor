/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cdb.sv                                        //
//                                                                     //
//  Description :  common data bus;                                          // 
/////////////////////////////////////////////////////////////////////////


//`define DEBUG
`ifndef __CDB_V__
`define __CDB_V__

`timescale 1ns/100ps


module cdb_2 (
    //INPUT
    input   logic               clock,
    input   logic               reset,

    input   CDB_ENTRY           rs_cdb_0,
    input   CDB_ENTRY           rs_cdb_1,

    //OUTPUT
    output  CDB_ENTRY           cdb_out_0,
    output  CDB_ENTRY           cdb_out_1
);
    assign cdb_out_0.tag            = rs_cdb_0.tag;
    assign cdb_out_0.value          = rs_cdb_0.value;
    assign cdb_out_0.valid          = rs_cdb_0.valid;
    assign cdb_out_0.take_branch    = rs_cdb_0.take_branch;

    assign cdb_out_1.tag            = rs_cdb_1.tag;
    assign cdb_out_1.value          = rs_cdb_1.value;
    assign cdb_out_1.valid          = rs_cdb_1.valid;
    assign cdb_out_1.take_branch    = rs_cdb_1.take_branch;

    `ifdef DEBUG
        logic [31:0] cycle_count;
        // synopsys sync_set_reset "reset"
        always_ff @(negedge clock) begin
            if(reset) begin
                cycle_count = 0;
            end else begin
                $display("DEBUG %4d: cdb_out.tag = %d, cdb_out.value = %d, cdb_out.valid =  %d, take_branch = %d", cycle_count, cdb_out.tag, cdb_out.value, cdb_out.valid, cdb_out.take_branch);
                cycle_count = cycle_count + 1;
            end
        
        end
    `endif
    
endmodule
`endif // `__CDB_V__