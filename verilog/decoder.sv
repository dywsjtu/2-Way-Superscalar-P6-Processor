/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  decoder.sv                                          //
//                                                                     //
//  Description :  decoder                                             // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DECODER_V__
`define __DECODER_V__
`timescale 1ns/100ps

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
	output	logic							mult_op,	// whether it is a mult operation
	output	logic 							halt,		// non-zero on a halt
	output	logic 							illegal,    // non-zero on an illegal instruction
	output	logic 							valid_inst  // for counting valid instructions executed
	                        							// and for making the fetch stage die on halts/
	                        							// keeping track of when to allow the next
														// instruction out of fetch
	                        							// 0 for HALT and illegal instructions (die on halt)
);

	assign valid_inst	= valid && ~illegal;
	
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
		mult_op			= `FALSE;
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
					mult_op			= `TRUE;
				end
				`RV32_MULH: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULH;
					mult_op			= `TRUE;
				end
				`RV32_MULHSU: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULHSU;
					mult_op			= `TRUE;
				end
				`RV32_MULHU: begin
					dest_reg   		= DEST_RD;
					alu_func   		= ALU_MULHU;
					mult_op			= `TRUE;
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
`endif // `__DECODER_V__