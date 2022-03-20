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

  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	// input [31:0] inst,
	// input valid_inst_in,	// ignore inst when low, outputs will
	                    	// reflect noop (except valid_inst)
	// see sys_defs.svh for definition
	// input IF_ID_PACKET if_packet,
	input									valid,		// If low, the data in this struct is garbage
    input	INST							inst,		// fetched instruction out
	input					[`XLEN-1:0] 	NPC,		// PC + 4
	input					[`XLEN-1:0] 	PC,			// PC 
	
	output	ALU_OPA_SELECT 					opa_select,
	output	ALU_OPB_SELECT 					opb_select,
	output	DEST_REG_SEL   					dest_reg, 	// mux selects
	output	ALU_FUNC						alu_func,
	output	logic 							rd_mem, wr_mem, cond_branch, uncond_branch,
	output	logic 							csr_op,		// used for CSR operations, we only used this as 
	                        							// a cheap way to get the return code out
	output	logic 							halt,		// non-zero on a halt
	output	logic 							illegal,    // non-zero on an illegal instruction
	output	logic 							valid_inst  // for counting valid instructions executed
	                        							// and for making the fetch stage die on halts/
	                        							// keeping track of when to allow the next
														// instruction out of fetch
	                        							// 0 for HALT and illegal instructions (die on halt)
);

	assign valid_inst	= valid & ~illegal;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		opa_select		= OPA_IS_RS1;
		opb_select 		= OPB_IS_RS2;
		alu_func 		= ALU_ADD;
		dest_reg 		= DEST_NONE;
		csr_op 			= `FALSE;
		rd_mem 			= `FALSE;
		wr_mem 			= `FALSE;
		cond_branch 	= `FALSE;
		uncond_branch 	= `FALSE;
		halt 			= `FALSE;
		illegal 		= `FALSE;
		if(valid) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   		= DEST_RD;
					opa_select 		= OPA_IS_ZERO;
					opb_select 		= OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   		= DEST_RD;
					opa_select 		= OPA_IS_PC;
					opb_select 		= OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					dest_reg      	= DEST_RD;
					opa_select    	= OPA_IS_PC;
					opb_select    	= OPB_IS_J_IMM;
					uncond_branch 	= `TRUE;
				end
				`RV32_JALR: begin
					dest_reg      	= DEST_RD;
					opa_select    	= OPA_IS_RS1;
					opb_select    	= OPB_IS_I_IMM;
					uncond_branch 	= `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  	= OPA_IS_PC;
					opb_select  	= OPB_IS_B_IMM;
					cond_branch 	= `TRUE;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					rd_mem     		= `TRUE;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select 		= OPB_IS_S_IMM;
					wr_mem     		= `TRUE;
				end
				`RV32_ADDI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
				end
				`RV32_SLTI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_SLT;
				end
				`RV32_SLTIU: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_SLTU;
				end
				`RV32_ANDI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_AND;
				end
				`RV32_ORI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_OR;
				end
				`RV32_XORI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_XOR;
				end
				`RV32_SLLI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_SLL;
				end
				`RV32_SRLI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_SRL;
				end
				`RV32_SRAI: begin
					dest_reg   		= DEST_RD;
					opb_select 		= OPB_IS_I_IMM;
					alu_func   		= ALU_SRA;
				end
				`RV32_ADD: begin
					dest_reg   		= DEST_RD;
				end
				`RV32_SUB: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SUB;
				end
				`RV32_SLT: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SLT;
				end
				`RV32_SLTU: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SLTU;
				end
				`RV32_AND: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_AND;
				end
				`RV32_OR: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_OR;
				end
				`RV32_XOR: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_XOR;
				end
				`RV32_SLL: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SLL;
				end
				`RV32_SRL: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SRL;
				end
				`RV32_SRA: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_SRA;
				end
				`RV32_MUL: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MUL;
				end
				`RV32_MULH: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULH;
				end
				`RV32_MULHSU: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULHSU;
				end
				`RV32_MULHU: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op 			= `TRUE;
				end
				`WFI: begin
					halt 			= `TRUE;
				end
				default: begin
					illegal 		= `TRUE;
				end
		endcase 	// casez (inst)
		end 		// if(valid)
	end 			// always
endmodule 			// decoder


module dispatch_stage(
	input         							clock,                  // system clock
	input         							reset,                  // system reset
	// input         						mem_wb_valid_inst,      // only go to next instruction when true
	//                                       						// makes pipeline behave as single-cycle
	input 		  							stall,
	input         							ex_mem_take_branch,		// taken-branch signal
	input					[`XLEN-1:0]		ex_mem_target_pc,		// target pc: use if take_branch is TRUE
	input					[63:0] 			Imem2proc_data,			// Data coming back from instruction-memory
	
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
	assign id_packet_out.inst 				= PC_reg[2]	? Imem2proc_data[63:32] 
														: Imem2proc_data[31:0];
	
	// default next PC value
	assign PC_plus_4 						= PC_reg + 4;
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	assign next_PC 							= ex_mem_take_branch 	? ex_mem_target_pc 
																	: PC_plus_4;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable 						= id_packet_out.valid | ex_mem_take_branch;
	
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
		.halt(id_packet_out.halt),
		.illegal(id_packet_out.illegal),
		.valid_inst(id_packet_out.valid)
	);

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
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
	end  // always

endmodule // module dispatch_stage
