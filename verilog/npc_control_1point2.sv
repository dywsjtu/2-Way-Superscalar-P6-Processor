/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  npc_control.sv                                      //
//                                                                     //
//  Description :  npc predictor                                       // 
/////////////////////////////////////////////////////////////////////////
`ifndef SS_2
//`define DEBUG
`ifndef __NPC_CONTROL_1POINT2_V__
`define __NPC_CONTROL_1POINT2_V__

`timescale 1ns/100ps

module npc_control_1point2 (
    //INPUT
    input clock,
    input reset,
	input squash,

    input is_return,
    input is_branch,
    input is_jump,

    input [`XLEN-1:0] PC_in,
    input [`XLEN-1:0] PC_plus_4, 

    //Retire update
    input ex_result_valid_0,
    input ex_branch_taken_0,
    input ex_is_branch_0,
    input [`XLEN-1:0] PC_ex_0,
    input [`XLEN-1:0] ex_result_0,
    input [`DIRP_IDX_LEN-1:0] ex_branch_idx_0,

    input ex_result_valid_1,
    input ex_branch_taken_1,
    input ex_is_branch_1,
    input [`XLEN-1:0] PC_ex_1,
    input [`XLEN-1:0] ex_result_1,
    input [`DIRP_IDX_LEN-1:0] ex_branch_idx_1,

    input FU_ID_PACKET fu_id_0,
    input FU_ID_PACKET fu_id_1,

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
                     ((is_jump && btb_hit) ||branch_predict) ? PC_btb_out : PC_plus_4;


     //Branch Predictor
    dirp_local_1point2 dirp_0(
        .clock(clock),
        .reset(reset),

        //Branch History
        .branch_result_valid_0(ex_result_valid_0 && ex_is_branch_0),
        .branch_result_0(ex_branch_taken_0 && ex_is_branch_0), //1 for taken, 0 for not taken
        .ex_idx_0(ex_branch_idx_0), 

        .branch_result_valid_1(ex_result_valid_1 && ex_is_branch_1),
        .branch_result_1(ex_branch_taken_1 && ex_is_branch_1), //1 for taken, 0 for not taken
        .ex_idx_1(ex_branch_idx_1), 

        //Branch Prediction
        .is_branch(is_branch),
        .targetPC_in(PC_in),

        .branch_taken(branch_taken),
        .dirp_tag(dirp_tag)
    );

    //Branch Target Buffer
    btb_1point2 btb_0(
        //INPUT
        .clock(clock),
        .reset(reset),

        //Read from BTB
        .read_en(is_branch || is_jump),
        .PC_in_r(PC_in),

        //Write into BTB
        .write_en_0(fu_id_0.is_valid && fu_id_0.is_branch),       
        .targetPC_in_0(fu_id_0.targetPC),
        .PC_in_w_0(fu_id_0.PC),

        .write_en_1(fu_id_1.is_valid && fu_id_1.is_branch),       
        .targetPC_in_1(fu_id_1.targetPC),
        .PC_in_w_1(fu_id_1.PC),

    //OUTPUT
        .targetPC_out(PC_btb_out),
        .hit(btb_hit)
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
		.ras_valid(ras_valid)
    );

endmodule
`endif
`endif