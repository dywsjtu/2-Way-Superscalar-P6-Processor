/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cdb.sv                                        //
//                                                                     //
//  Description :  common data bus;                                          // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __CDB_V__
`define __CDB_V__

`timescale 1ns/100ps


module cdb (
    //INPUT
    input logic                 clock,
    input logic                 reset,
    input logic                 squash,
    input logic                 FU_valid,
    input logic [`ROB_IDX_LEN:0]  FU_tag,
    input logic [`XLEN-1:0]     FU_value,

    //OUTPUT
    output CDB_ENTRY            cdb_out,
    //output logic                full//whether CDB is full
);
    /*Need to be discussed*/
    //CDB_ENTRY cdb_list = '{`ZERO_REG,0};

    //assign full          = (FU_tag != `ZERO_TAG & ~reset & ~squash);
    assign cdb_out.tag   = FU_tag;
    assign cdb_out.value = FU_value;
    assign cdb_out.valid = FU_valid;
    
endmodule
`endif // `__CDB_V__