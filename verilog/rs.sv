/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs.sv                                               //
//                                                                     //
//  Description :  reservation station;                                // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module rs(
    input                       clock,
    input                       reset,
    input    ID_RS_PACKET        id_rs,
    input    MT_RS_PACKET        mt_rs,
    input    REG_RS_PACKET       reg_rs,

    output   RS_FU_PACKET        rs_fu,
    output   RS_REG_PACKET       rs_reg,
    output   REG_RS_PACKET        reg_rs
);  


`endif // `__RS_V__