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


module dispatch_stage_2 (
	input         							clock,                  // system clock
	input         							reset,                  // system reset
	// input         						mem_wb_valid_inst,      // only go to next instruction when true
	//                                       						// makes pipeline behave as single-cycle
	input 		  							stall_0,
	input 		  							stall_1,
	// input         							ex_mem_take_branch,		// taken-branch signal
	// input					[`XLEN-1:0]		ex_mem_target_pc,		// target pc: use if take_branch is TRUE
	input					[63:0] 			Icache_data_out,			// Data coming back from instruction-memory
	input									Icache_valid_out,
	input	ROB_ID_PACKET       			rob_id_0,
	input	ROB_ID_PACKET       			rob_id_1,

	// output	IF_ID_PACKET 				if_packet_out			// Output data packet from IF going to ID, see sys_defs for signal information 
	// input	IF_ID_PACKET				if_id_packet_in,
	
	output	logic			[`XLEN-1:0] 	proc2Imem_addr,    		// Address sent to Instruction memory
	output	ID_EX_PACKET					id_packet_out_0,
	output	ID_EX_PACKET					id_packet_out_1
);

	logic	[`XLEN-1:0] 					PC_reg;             	// PC we are currently fetching	
	logic	[`XLEN-1:0] 					PC_plus_4;
	logic	[`XLEN-1:0] 					PC_plus_8;
	logic	[`XLEN-1:0] 					next_PC;

	logic           						PC_enable_0;
	logic           						PC_enable_1;
	
	assign proc2Imem_addr 					= {PC_reg[`XLEN-1:3], 3'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign id_packet_out_0.inst 			= PC_reg[2]	? Icache_data_out[63:32]
														: Icache_data_out[31:0];
	assign id_packet_out_1.inst 			= PC_reg[2]	? 32'b0
														: Icache_data_out[63:32];
														
	
	// default next PC value
	assign PC_plus_4 						= PC_reg + 4;
	assign PC_plus_8						= PC_reg + 8;
	

	`ifdef BRANCH_MODE
		logic [`XLEN-1:0]		NPC_out;
		assign next_PC 						= rob_id_0.squash ? rob_id_0.target_pc :
											  rob_id_1.squash ? rob_id_1.target_pc : 
											  					NPC_out;
		assign id_packet_out.NPC_out		= NPC_out;
	`else
		assign next_PC 						= rob_id_0.squash ? rob_id_0.target_pc : 
											  rob_id_1.squash ? rob_id_1.target_pc : 
											  PC_enable_1	  ? PC_plus_8		   :
											  					PC_plus_4;
		assign id_packet_out_0.NPC_out		= PC_plus_4;
		assign id_packet_out_1.NPC_out		= PC_plus_8;
	`endif
	
	
	assign PC_enable_0 						= id_packet_out_0.valid || rob_id_0.squash || rob_id_1.squash;
	assign PC_enable_1 						= id_packet_out_1.valid;
	
	
	// Pass PC+4 down pipeline w/instruction
	assign id_packet_out_0.NPC				= PC_plus_4;
	assign id_packet_out_0.PC				= PC_reg;
	assign id_packet_out_1.NPC				= PC_plus_8;
	assign id_packet_out_1.PC				= PC_plus_4;

	DEST_REG_SEL dest_reg_select_0, dest_reg_select_0; 

	// instantiate the instruction decoder
	logic valid_inst_0;
	decoder decoder_0 (
		.valid(~stall_0),
		.inst(id_packet_out_0.inst),
		.NPC(id_packet_out_0.NPC),
		.PC(id_packet_out_0.PC),
		// .if_packet(if_id_packet_in),	 
		// Outputs
		.opa_select(id_packet_out_0.opa_select),
		.opb_select(id_packet_out_0.opb_select),
		.alu_func(id_packet_out_0.alu_func),
		.dest_reg(dest_reg_select_0),
		.rd_mem(id_packet_out_0.rd_mem),
		.wr_mem(id_packet_out_0.wr_mem),
		.cond_branch(id_packet_out_0.cond_branch),
		.uncond_branch(id_packet_out_0.uncond_branch),
		.csr_op(id_packet_out_0.csr_op),
		.mult_op(id_packet_out_0.mult_op),
		.halt(id_packet_out_0.halt),
		.illegal(id_packet_out_0.illegal),
		.valid_inst(valid_inst_0)
	);

	logic valid_inst_1;
	decoder decoder_1 (
		.valid(~stall_0 && ~stall_1 && ~PC_reg[2]),
		.inst(id_packet_out_1.inst),
		.NPC(id_packet_out_1.NPC),
		.PC(id_packet_out_1.PC),
		// .if_packet(if_id_packet_in),	 
		// Outputs
		.opa_select(id_packet_out_1.opa_select),
		.opb_select(id_packet_out_1.opb_select),
		.alu_func(id_packet_out_1.alu_func),
		.dest_reg(dest_reg_select_1),
		.rd_mem(id_packet_out_1.rd_mem),
		.wr_mem(id_packet_out_1.wr_mem),
		.cond_branch(id_packet_out_1.cond_branch),
		.uncond_branch(id_packet_out_1.uncond_branch),
		.csr_op(id_packet_out_1.csr_op),
		.mult_op(id_packet_out_1.mult_op),
		.halt(id_packet_out_1.halt),
		.illegal(id_packet_out_1.illegal),
		.valid_inst(valid_inst_1)
	);

	assign id_packet_out_0.valid = valid_inst_0 && Icache_valid_out;
	assign id_packet_out_1.valid = valid_inst_1 && Icache_valid_out;


	//Branch predictor
	`ifdef BRANCH_MODE
		logic ras_full;
		//logic [4:0] ex_dirp_tag;
		npc_control_1point2 npc_control_0(
    		//INPUT
    		.clock(clock),
    		.reset(reset),
			.squash(rob_id_0.squash || rob_id_1.squash),

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

			.fu_id_0(fu_id_0),
			.fu_id_1(fu_id_1),


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
		case (dest_reg_select_0)
			DEST_RD:    id_packet_out_0.dest_reg_idx = id_packet_out_0.inst.r.rd;
			DEST_NONE:  id_packet_out_0.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out_0.dest_reg_idx = `ZERO_REG; 
		endcase

		id_packet_out_0.req_reg[0]					= 1'b0;
		id_packet_out_0.input_reg_idx[0]			= 5'b0;
		casez (id_packet_out_0.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL: begin
				id_packet_out_0.req_reg[0]			= 1'b0;
				id_packet_out_0.input_reg_idx[0]	= 5'b0;
			end
			default: begin
				id_packet_out_0.req_reg[0]			= 1'b1;
				id_packet_out_0.input_reg_idx[0]	= id_packet_out_0.inst.r.rs1;
			end
		endcase

		id_packet_out_0.req_reg[1]					= 1'b0;
		id_packet_out_0.input_reg_idx[1]			= 5'b0;
		casez (id_packet_out_0.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL, `RV32_JALR, `RV32_LB, `RV32_LH, 
			`RV32_LW, `RV32_LBU, `RV32_LHU, `RV32_ADDI, `RV32_SLTI, `RV32_SLTIU, `RV32_ANDI, 
			`RV32_ORI, `RV32_XORI, `RV32_SLLI, `RV32_SRLI, `RV32_SRAI: begin
				id_packet_out_0.req_reg[1]			= 1'b0;
				id_packet_out_0.input_reg_idx[1]	= 5'b0;
			end
			default: begin
				id_packet_out_0.req_reg[1] 			= 1'b1;
				id_packet_out_0.input_reg_idx[1]	= id_packet_out_0.inst.r.rs2;
			end
		endcase

		`ifndef BRANCH_MODE	
			id_packet_out_0.take_branch				= 1'b0;
		`endif
	end

	always_comb begin
		case (dest_reg_select_1)
			DEST_RD:    id_packet_out_1.dest_reg_idx = id_packet_out_1.inst.r.rd;
			DEST_NONE:  id_packet_out_1.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out_1.dest_reg_idx = `ZERO_REG; 
		endcase


		id_packet_out_1.req_reg[0]					= 1'b0;
		id_packet_out_1.input_reg_idx[0]			= 5'b0;
		casez (id_packet_out_1.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL: begin
				id_packet_out_1.req_reg[0]			= 1'b0;
				id_packet_out_1.input_reg_idx[0]	= 5'b0;
			end
			default: begin
				id_packet_out_1.req_reg[0]			= 1'b1;
				id_packet_out_1.input_reg_idx[0]	= id_packet_out_1.inst.r.rs1;
			end
		endcase

		id_packet_out_1.req_reg[1]					= 1'b0;
		id_packet_out_1.input_reg_idx[1]			= 5'b0;
		casez (id_packet_out_1.inst) 
			`RV32_LUI, `RV32_AUIPC, `RV32_JAL, `RV32_JALR, `RV32_LB, `RV32_LH, 
			`RV32_LW, `RV32_LBU, `RV32_LHU, `RV32_ADDI, `RV32_SLTI, `RV32_SLTIU, `RV32_ANDI, 
			`RV32_ORI, `RV32_XORI, `RV32_SLLI, `RV32_SRLI, `RV32_SRAI: begin
				id_packet_out_1.req_reg[1]			= 1'b0;
				id_packet_out_1.input_reg_idx[1]	= 5'b0;
			end
			default: begin
				id_packet_out_1.req_reg[1] 			= 1'b1;
				id_packet_out_1.input_reg_idx[1]	= id_packet_out_1.inst.r.rs2;
			end
		endcase

		`ifndef BRANCH_MODE	
			id_packet_out_1.take_branch				= 1'b0;
		`endif
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable_0)
			PC_reg <= `SD next_PC; // transition to next PC
	end  // always

endmodule // module dispatch_stage_2
