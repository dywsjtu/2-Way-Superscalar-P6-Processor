/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dispatch_stage.v                                    //
//                                                                     //
//   Description : dispatch (D) stage of the pipeline;			       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps


module dispatch_stage_1point2 (
	input         							clock,                  // system clock
	input         							reset,                  // system reset
	// input         						mem_wb_valid_inst,      // only go to next instruction when true
	//                                       						// makes pipeline behave as single-cycle
	input 		  							stall,
	// input         							ex_mem_take_branch,		// taken-branch signal
	// input					[`XLEN-1:0]		ex_mem_target_pc,		// target pc: use if take_branch is TRUE
	input					[63:0] 			Icache_data_out,			// Data coming back from instruction-memory
	input									Icache_valid_out,
	input	ROB_ID_PACKET       			rob_id_0,
	input	ROB_ID_PACKET       			rob_id_1,

	// output	IF_ID_PACKET 				if_packet_out			// Output data packet from IF going to ID, see sys_defs for signal information 
	// input	IF_ID_PACKET				if_id_packet_in,
	
	output	logic			[`XLEN-1:0] 	proc2Imem_addr,    		// Address sent to Instruction memory
	output	ID_EX_PACKET					id_packet_out
);

	logic	[`XLEN-1:0] 					PC_reg;             	// PC we are currently fetching	
	logic	[`XLEN-1:0] 					PC_plus_4;
	logic	[`XLEN-1:0] 					next_PC;
	logic           						PC_enable;
	
	assign proc2Imem_addr 					= {PC_reg[`XLEN-1:3], 3'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign id_packet_out.inst 				= PC_reg[2]	? Icache_data_out[63:32] 
														: Icache_data_out[31:0];
	
	// default next PC value
	assign PC_plus_4 						= PC_reg + 4;
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	// assign next_PC 							= ex_mem_take_branch 	? ex_mem_target_pc 
	// 																: PC_plus_4;
	
	// // The take-branch signal must override stalling (otherwise it may be lost)
	// assign PC_enable 						= id_packet_out.valid | ex_mem_take_branch;
	`ifdef BRANCH_MODE
		logic [`XLEN-1:0]		NPC_out;
		assign next_PC 							= rob_id_0.squash ? rob_id_0.target_pc :
												  rob_id_1.squash ? rob_id_1.target_pc : 
												  					NPC_out;
		assign id_packet_out.NPC_out			= NPC_out;
	`else
		assign next_PC 							= rob_id_0.squash ? rob_id_0.target_pc : 
												  rob_id_1.squash ? rob_id_1.target_pc : 
												  					PC_plus_4;
		assign id_packet_out.NPC_out			= PC_plus_4;
	`endif
	
	
	assign PC_enable 						= id_packet_out.valid || rob_id_0.squash || rob_id_1.squash;
	
	
	// Pass PC+4 down pipeline w/instruction
	assign id_packet_out.NPC				= PC_plus_4;
	assign id_packet_out.PC					= PC_reg;
	// This register holds the PC value
	// synopsys sync_set_reset "reset"

	
	// This FF controls the stall signal that artificially forces
	// fetch to stall until the previous instruction has completed
	// This must be removed for Project 3
	// synopsys sync_set_reset "reset"
	// always_ff @(posedge clock) begin
	// 	if (reset)
	// 		if_packet_out.valid <= `SD 1;  // must start with something
	// 	else
	// 		if_packet_out.valid <= `SD mem_wb_valid_inst;
	// end

	DEST_REG_SEL dest_reg_select; 

	// Instantiate the register file used by this pipeline
	// regfile regf_0 (
	// 	.rda_idx(if_id_packet_in.inst.r.rs1),
	// 	.rda_out(id_packet_out.rs1_value), 

	// 	.rdb_idx(if_id_packet_in.inst.r.rs2),
	// 	.rdb_out(id_packet_out.rs2_value),

	// 	.wr_clk(clock),
	// 	.wr_en(wb_reg_wr_en_out),
	// 	.wr_idx(wb_reg_wr_idx_out),
	// 	.wr_data(wb_reg_wr_data_out)
	// );

	// instantiate the instruction decoder
	logic valid_inst;
	decoder decoder_0 (
		.valid(!stall),
		.inst(id_packet_out.inst),
		.NPC(id_packet_out.NPC),
		.PC(id_packet_out.PC),
		// .if_packet(if_id_packet_in),	 
		// Outputs
		.opa_select(id_packet_out.opa_select),
		.opb_select(id_packet_out.opb_select),
		.alu_func(id_packet_out.alu_func),
		.dest_reg(dest_reg_select),
		.rd_mem(id_packet_out.rd_mem),
		.wr_mem(id_packet_out.wr_mem),
		.cond_branch(id_packet_out.cond_branch),
		.uncond_branch(id_packet_out.uncond_branch),
		.csr_op(id_packet_out.csr_op),
		.mult_op(id_packet_out.mult_op),
		.halt(id_packet_out.halt),
		.illegal(id_packet_out.illegal),
		.valid_inst(valid_inst)
	);

	assign id_packet_out.valid = valid_inst && Icache_valid_out;

	//Branch predictor
	`ifdef BRANCH_MODE
		logic ras_full;
		//logic [4:0] ex_dirp_tag;
		npc_control_1point2 npc_control_0(
    		//INPUT
    		.clock(clock),
    		.reset(reset),
			.squash(rob_id_0.squash || rob_id_1.squash),

			//.is_return(1'b0),
    		.is_return(id_packet_out.uncond_branch && id_packet_out.inst[6:0] == `RV32_JALR_OP && id_packet_out.valid),
    		.is_branch(id_packet_out.cond_branch && id_packet_out.valid),
    		.is_jump(id_packet_out.uncond_branch && id_packet_out.inst[6:0] == `RV32_JAL_OP && id_packet_out.valid),

    		.PC_in(id_packet_out.PC),
    		.PC_plus_4(id_packet_out.NPC),

    		.ex_result_valid_0(rob_id_0.result_valid),
    		.ex_branch_taken_0(rob_id_0.branch_taken),
    		.ex_is_branch_0(rob_id_0.is_branch),
    		.PC_ex_0(rob_id_0.PC),
    		.ex_result_0(rob_id_0.targetPC),
    		.ex_branch_idx_0(rob_id_0.dirp_tag),

			.ex_result_valid_1(rob_id_1.result_valid),
    		.ex_branch_taken_1(rob_id_1.branch_taken),
    		.ex_is_branch_1(rob_id_1.is_branch),
    		.PC_ex_1(rob_id_1.PC),
    		.ex_result_1(rob_id_1.targetPC),
    		.ex_branch_idx_1(rob_id_1.dirp_tag),


    		//OUTPUT
			.dirp_tag(id_packet_out.dirp_tag),
    		.branch_predict(id_packet_out.take_branch),
    		.NPC_out(NPC_out)
    		//.ras_full(ras_full)
		);
		`ifdef DEBUG
		logic [31:0] cycle_count;
		always_ff@(negedge clock) begin
			if (reset) begin
				cycle_count = 0;
			end else begin
				$display("DEBUG %4d: fu_result_valid = %b, fu_is_branch = %b", cycle_count, id_packet_out.result_valid, id_packet_out.is_branch);
				cycle_count += 1;
			end
		end 
		`endif
	`endif

	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		case (dest_reg_select)
			DEST_RD:    id_packet_out.dest_reg_idx = id_packet_out.inst.r.rd;
			DEST_NONE:  id_packet_out.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out.dest_reg_idx = `ZERO_REG; 
		endcase


		id_packet_out.req_reg[0]				= 1'b0;
		id_packet_out.input_reg_idx[0]			= 5'b0;
		casez (id_packet_out.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL: begin
				id_packet_out.req_reg[0]		= 1'b0;
				id_packet_out.input_reg_idx[0]	= 5'b0;
			end
			default: begin
				id_packet_out.req_reg[0]		= 1'b1;
				id_packet_out.input_reg_idx[0]	= id_packet_out.inst.r.rs1;
			end
		endcase

		id_packet_out.req_reg[1]				= 1'b0;
		id_packet_out.input_reg_idx[1]			= 5'b0;
		casez (id_packet_out.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL, `RV32_JALR, `RV32_LB, `RV32_LH, 
			`RV32_LW, `RV32_LBU, `RV32_LHU, `RV32_ADDI, `RV32_SLTI, `RV32_SLTIU, `RV32_ANDI, 
			`RV32_ORI, `RV32_XORI, `RV32_SLLI, `RV32_SRLI, `RV32_SRAI: begin
				id_packet_out.req_reg[1]		= 1'b0;
				id_packet_out.input_reg_idx[1]	= 5'b0;
			end
			default: begin
				id_packet_out.req_reg[1] 		= 1'b1;
				id_packet_out.input_reg_idx[1]	= id_packet_out.inst.r.rs2;
			end
		endcase

		`ifndef BRANCH_MODE	
			id_packet_out.take_branch				= 1'b0;
		`endif
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
	end  // always

endmodule // module dispatch_stage
