/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  npc_control.sv                                      //
//                                                                     //
//  Description :  npc predictor                                       // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __NPC_CONTROL_V__
`define __NPC_CONTROL_V__

`timescale 1ns/100ps

module npc_control (
    //INPUT
    input clock,
    input reset,
	input squash,

    input is_return,
    input is_branch,
    input is_jump,

    input [`XLEN-1:0] PC_in,
    input [`XLEN-1:0] PC_plus_4, 

    input ex_result_valid,
    input ex_branch_taken,
    input ex_is_branch,
    input [`XLEN-1:0] PC_ex,
    input [`XLEN-1:0] ex_result,
    input [`DIRP_IDX_LEN-1:0] ex_branch_idx,


    //OUTPUT
    output logic [`DIRP_IDX_LEN-1:0] dirp_tag,
    output logic branch_predict,
    output logic [`XLEN-1:0] NPC_out
    //output logic ras_full

);
    logic [`XLEN-1:0] PC_btb_out, PC_ras_out;
    logic btb_hit, ras_valid, branch_taken;
	assign branch_predict = branch_taken && btb_hit;

    assign NPC_out = (is_return && ras_valid) ? PC_ras_out :
                     branch_predict? PC_btb_out : PC_plus_4;

	// assign NPC_out = branch_predict ? PC_btb_out : PC_plus_4;  

    //Branch Predictor
    dirp_local dirp_0(
        .clock(clock),
        .reset(reset),

        //Branch History
        .branch_result_valid(ex_result_valid && ex_is_branch),
        .branch_result(ex_branch_taken && ex_is_branch), //1 for taken, 0 for not taken
        .ex_idx(ex_branch_idx), //the previous idx to update PHT

        //Branch Prediction
        .is_branch(is_branch),
        .targetPC_in(PC_in),

        .branch_taken(branch_taken),
        .dirp_tag(dirp_tag)
    );

    //Branch Target Buffer
    btb btb_0(
        //INPUT
        .clock(clock),
        .reset(reset),

        //Read from BTB
        .read_en(is_branch),
        .PC_in_r(PC_in),

        //Write into BTB
        .write_en(ex_is_branch && ex_result_valid),       
        .targetPC_in(ex_result),
        .PC_in_w(PC_ex),

    //OUTPUT
        .targetPC_out(PC_btb_out),
        .hit(btb_hit) //if the targetPC is valid
);

    //Returen Address
    ras ras_0(
        .clock(clock),
        .reset(reset),
		.squash(squash),
        .is_jump(is_jump),
        .is_return(is_return),
        .NPC(PC_plus_4),

        .PC_return(PC_ras_out),
        //.ras_full(ras_full),
		.ras_valid(ras_valid)
    );

endmodule
`endif