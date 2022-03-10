`ifndef SYNTHESIS

//
// This is an automatically generated file from 
// dc_shell Version S-2021.06-SP1 -- Jul 13, 2021
//

// For simulation only. Do not modify.

module rob_svsim(
    input                       clock,
    input                       reset,

    input   ID_ROB_PACKET       id_rob,
    input   RS_ROB_PACKET       rs_rob,
    input   FU_ROB_PACKET       fu_rob,

    output  logic               rob_full,

    output  ROB_RS_PACKET       rob_rs,
    output  ROB_MT_PACKET       rob_mt,
    output  ROB_REG_PACKET      rob_reg

     
        , output logic      [3-1:0]  rob_head
        , output logic      [3-1:0]  rob_tail
        , output logic      [3:0]    rob_counter
        , output ROB_ENTRY  [8-1:0]     rob_entries
    
);  
     

    

  rob rob( {>>{ clock }}, {>>{ reset }}, {>>{ id_rob }}, {>>{ rs_rob }}, 
        {>>{ fu_rob }}, {>>{ rob_full }}, {>>{ rob_rs }}, {>>{ rob_mt }}, 
        {>>{ rob_reg }}, {>>{ rob_head }}, {>>{ rob_tail }}, 
        {>>{ rob_counter }}, {>>{ rob_entries }} );
endmodule
`endif
