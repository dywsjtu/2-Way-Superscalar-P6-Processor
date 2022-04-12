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


module cdb (
    //INPUT
    input logic                     clock,
    input logic                     reset,

    input   CDB_ENTRY               rs_cdb,
    // input logic                     squash,
    // input logic                     FU_valid,
    // input logic [`ROB_IDX_LEN:0]    FU_tag,
    // input logic [`XLEN-1:0]         FU_value,

    //OUTPUT
    output CDB_ENTRY                cdb_out
    //output logic                full//whether CDB is full
);
    /*Need to be discussed*/
    //CDB_ENTRY cdb_list = '{`ZERO_REG,0};

    //assign full          = (FU_tag != `ZERO_TAG & ~reset & ~squash);
    assign cdb_out.tag              = rs_cdb.tag;
    assign cdb_out.value            = rs_cdb.value;
    assign cdb_out.valid            = rs_cdb.valid;
    assign cdb_out.take_branch      = rs_cdb.take_branch;
    assign cdb_out.branch_target    = rs_cdb.branch_target;

    
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