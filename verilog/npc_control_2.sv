/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  npc_control.sv                                      //
//                                                                     //
//  Description :  npc predictor                                       // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __NPC_CONTROL_2_V__
`define __NPC_CONTROL_2_V__

`timescale 1ns/100ps

module npc_control_2 (
    //INPUT
    input clock,
    input reset,
	input squash,

    input is_return_0,
    input is_branch_0,
    input is_jump_0,
    
    input is_return_1,
    input is_branch_1,
    input is_jump_1,

    input [`XLEN-1:0] PC_in_0,
    input [`XLEN-1:0] PC_plus_4_0, 
    input [`XLEN-1:0] PC_in_1,
    input [`XLEN-1:0] PC_plus_4_1, 

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
    output logic [`DIRP_IDX_LEN-1:0] dirp_tag_0,
    output logic branch_predict_0,
    output logic [`XLEN-1:0] NPC_out_0,
    output logic [`DIRP_IDX_LEN-1:0] dirp_tag_1,
    output logic branch_predict_1,
    output logic [`XLEN-1:0] NPC_out_1
);
    logic [`XLEN-1:0] PC_btb_out_0, PC_btb_out_1, PC_ras_out;
    logic btb_hit_0, btb_hit_1, ras_valid, branch_taken_0, branch_taken_1;

	assign branch_predict_0 = branch_taken_0 && btb_hit_0;
    assign branch_predict_1 = branch_taken_1 && btb_hit_1;

    assign NPC_out_0 = (is_return_0 && ras_valid) ? PC_ras_out :
                     ((is_jump_0 && btb_hit_0) ||branch_predict_0) ? PC_btb_out_0 : PC_plus_4_0;
    assign NPC_out_1 = (~is_return_0 && is_return_1 && ras_valid) ? PC_ras_out :
                     ((is_jump_1 && btb_hit_1) ||branch_predict_1) ? PC_btb_out_1 : PC_plus_4_1;
                     
	
    //Branch Predictor
    dirp_local_2 dirp_0(
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
        .is_branch_0(is_branch_0),
        .targetPC_in_0(PC_in_0),
        .is_branch_1(is_branch_1),
        .targetPC_in_1(PC_in_1),

        .branch_taken_0(branch_taken_0),
        .dirp_tag_0(dirp_tag_0),
        .branch_taken_1(branch_taken_1),
        .dirp_tag_1(dirp_tag_1)
    );

    //Branch Target Buffer
    btb_2 btb_0(
        //INPUT
        .clock(clock),
        .reset(reset),

        //Read from BTB
        .read_en_0(is_branch_0 || is_jump_0),
        .PC_in_r_0(PC_in_0),
        .read_en_1(is_branch_1 || is_jump_1),
        .PC_in_r_1(PC_in_1),

         //Write into BTB
        .write_en_0(fu_id_0.is_valid && fu_id_0.is_branch),       
        .targetPC_in_0(fu_id_0.targetPC),
        .PC_in_w_0(fu_id_0.PC),

        .write_en_1(fu_id_1.is_valid && fu_id_1.is_branch),       
        .targetPC_in_1(fu_id_1.targetPC),
        .PC_in_w_1(fu_id_1.PC),

        //OUTPUT
        .targetPC_out_0(PC_btb_out_0),
        .hit_0(btb_hit_0),
        .targetPC_out_1(PC_btb_out_1),
        .hit_1(btb_hit_1)
        );

    //Returen Address
    ras ras_0(
        .clock(clock),
        .reset(reset),
		.squash(squash),
        .is_jump(is_jump_0 ? 1'b1 : is_jump_1),
        .is_return(is_return_0 ? 1'b1 : is_return_1),
        .NPC(is_jump_0 ? PC_plus_4_0 : PC_plus_4_1),

        .PC_return(PC_ras_out),
		.ras_valid(ras_valid)
    );

endmodule
`endif