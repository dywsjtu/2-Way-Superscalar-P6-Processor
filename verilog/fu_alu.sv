`ifndef __FU_ALU_V__
`define __FU_ALU_V__

`timescale 1ns/100ps

//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module alu(
	input val_valid,
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC     func,

	output valid,
	output logic [`XLEN-1:0] result
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
	assign valid = val_valid;
	assign signed_opa = opa;
	assign signed_opb = opb;
	assign signed_mul = signed_opa * signed_opb;
	assign unsigned_mul = opa * opb;
	assign mixed_mul = signed_opa * opb;

	always_comb begin
		case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			ALU_MUL:      result = signed_mul[`XLEN-1:0];
			ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end
endmodule // alu

//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//
module brcond(// Inputs
	input val_valid,
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input  [2:0] func,  // Specifies which condition to check

	output logic valid,
	output logic cond    // 0/1 condition result (False/True)
);
	assign valid = val_valid;

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (func)
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond


module fu_alu(
	input                           clock,               // system clock
	input                           reset,               // system reset
    input   RS_FU_PACKET            rs_fu,
	// input   ID_EX_PACKET   id_ex_packet_in,

    output  FU_RS_PACKET            fu_rs,
	output							fu_result_valid
	// output  EX_MEM_PACKET           ex_packet_out
);
	logic 	[`XLEN-1:0] 			opa_mux_out, opb_mux_out;
	logic 							brcond_result;
	logic							brcond_result_valid;
	logic	[`XLEN-1:0]				alu_result;
    logic                           alu_result_valid;
	RS_FU_PACKET					working_rs_fu;

	// Pass-throughs
	assign fu_rs.NPC            = working_rs_fu.NPC;
	assign fu_rs.rs2_value      = working_rs_fu.rs_value[1];
	assign fu_rs.rd_mem         = working_rs_fu.rd_mem;
	assign fu_rs.wr_mem         = working_rs_fu.wr_mem;
	assign fu_rs.dest_reg_idx   = working_rs_fu.dest_reg_idx;
	assign fu_rs.halt           = working_rs_fu.halt;
	assign fu_rs.illegal        = working_rs_fu.illegal;
	assign fu_rs.csr_op         = working_rs_fu.csr_op;
	assign fu_rs.mem_size       = working_rs_fu.inst.r.funct3;
	assign fu_rs.T_dest         = working_rs_fu.dest_tag;
	// assign fu_rs.valid			= rs_fu.valid && brcond_result_valid && alu_result_valid;
	assign fu_result_valid		= working_rs_fu.valid && working_rs_fu.rs_value_valid && brcond_result_valid && alu_result_valid;
	
	//
	// ALU opA mux
	//
	always_comb begin
		opa_mux_out = `XLEN'hdeadfbac;
		case (working_rs_fu.opa_select)
			OPA_IS_RS1:  opa_mux_out = working_rs_fu.rs_value[0];
			OPA_IS_NPC:  opa_mux_out = working_rs_fu.NPC;
			OPA_IS_PC:   opa_mux_out = working_rs_fu.PC;
			OPA_IS_ZERO: opa_mux_out = 0;
		endcase
	end

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out = `XLEN'hfacefeed;
		case (working_rs_fu.opb_select)
			OPB_IS_RS2:   opb_mux_out = working_rs_fu.rs_value[1];
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(working_rs_fu.inst);
			OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(working_rs_fu.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(working_rs_fu.inst);
			OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(working_rs_fu.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(working_rs_fu.inst);
		endcase 
	end


	//
	// instantiate the ALU
	//
	alu alu_0 (// Inputs
		//.clock(clock),
		//.reset(reset),

		.val_valid(working_rs_fu.rs_value_valid),
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(working_rs_fu.alu_func),

		// Output
		.valid(alu_result_valid),
		.result(alu_result)
	);

	// 
	 // instantiate the branch condition tester
	 //
	brcond brcond (// Inputs
		//.clock(clock),
		//.reset(reset),

		.val_valid(working_rs_fu.rs_value_valid),
		.rs1(working_rs_fu.rs_value[0]), 
		.rs2(working_rs_fu.rs_value[1]),
		.func(working_rs_fu.inst.b.funct3), // inst bits to determine check

		// Output
		.valid(brcond_result_valid),
		.cond(brcond_result)
	);

	 // ultimate "take branch" signal:
	 //	unconditional, or conditional and the condition is true
	assign fu_rs.take_branch = working_rs_fu.uncond_branch
		                        | (working_rs_fu.cond_branch & brcond_result);
	assign fu_rs.alu_result	 = alu_result;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || rs_fu.squash || rs_fu.selected) begin
			working_rs_fu		<=	`SD 0;
		end else if (rs_fu.valid && (~working_rs_fu.rs_value_valid || ~working_rs_fu.valid)) begin
			working_rs_fu		<=	`SD rs_fu;
		end
	end

endmodule // module fu_alu
`endif // __FU_ALU_V__
