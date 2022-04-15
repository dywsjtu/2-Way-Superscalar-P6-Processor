`ifndef __FU_BASE_BLOCK__
`define __FU_BASE_BLOCK__
`timescale 1ns/100ps
//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module alu (
	input							clock,
	input							reset,

	input							refresh,
	input							val_valid,
	input           [`XLEN-1:0]     opa,
	input           [`XLEN-1:0]     opb,
	ALU_FUNC                        func,

    output logic                    valid,
	output logic    [`XLEN-1:0]     result
);
	logic							out_valid;
	logic			[`XLEN-1:0]		out_result;

	wire signed 	[`XLEN-1:0]     signed_opa, signed_opb;

	assign signed_opa   = opa;
	assign signed_opb   = opb;

	always_comb begin
		case (func)
			ALU_ADD:      out_result = opa + opb;
			ALU_SUB:      out_result = opa - opb;
			ALU_AND:      out_result = opa & opb;
			ALU_SLT:      out_result = signed_opa < signed_opb;
			ALU_SLTU:     out_result = opa < opb;
			ALU_OR:       out_result = opa | opb;
			ALU_XOR:      out_result = opa ^ opb;
			ALU_SRL:      out_result = opa >> opb[4:0];
			ALU_SLL:      out_result = opa << opb[4:0];
			ALU_SRA:      out_result = signed_opa >>> opb[4:0]; // arithmetic from logical shift

			default:      out_result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
		out_valid = val_valid;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || ~val_valid) begin
			valid		<=	`SD	1'b0;
			result		<=	`SD	`XLEN'b0;
		// end else if (refresh) begin
		// 	valid		<=	`SD	out_valid;
		// 	result		<=	`SD out_result;
		// // 	// clear intermediate values
		end else begin
			valid		<=	`SD	out_valid;
			result		<=	`SD out_result;
		end
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
module brcond (// Inputs
	input							clock,
	input							reset,

	input							refresh,
	input							val_valid,
	input   [`XLEN-1:0]     		rs1,    	// Value to check against condition
	input   [`XLEN-1:0]     		rs2,
	input   [2:0]           		func,  		// Specifies which condition to check

	output	logic					valid,
	output	logic					cond    	// 0/1 condition result (False/True)
);

	logic						out_valid;
	logic						out_cond;
	logic signed [`XLEN-1:0] 	signed_rs1, signed_rs2;

	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;

	always_comb begin
		out_cond = 0;
		case (func)
			3'b000: out_cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: out_cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: out_cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: out_cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: out_cond = rs1 < rs2;           // BLTU
			3'b111: out_cond = rs1 >= rs2;          // BGEU
		endcase
		out_valid = val_valid;
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || ~val_valid) begin
			valid		<=	`SD	1'b0;
			cond		<=	`SD	1'b0;
		// end else if (refresh) begin
		// 	// clear intermediate values
		end else begin
			valid		<=	`SD	out_valid;
			cond		<=	`SD out_cond;
		end
	end
endmodule // brcond
`endif // __FU_BASE_BLOCK__

//
// The MLU
//
// alu for mult
//
// This module is purely combinational
//
module mlu (
	input							clock,
	input							reset,

	input							refresh,
	input							val_valid,
	input           [`XLEN-1:0]     opa,
	input           [`XLEN-1:0]     opb,
	ALU_FUNC                        func,

    output logic                    valid,
	output logic    [`XLEN-1:0]     result
);
	
	logic			[2*`XLEN-1:0]		out_result;

	logic [1:0] sign;
	always_comb begin
		case (func)
			ALU_MUL:      sign = 2'b11;
			ALU_MULH:     sign = 2'b11;
			ALU_MULHSU:   sign = 2'b01;
			ALU_MULHU:    sign = 2'b00;

			default:      sign = 2'b11;  // here to prevent latches
		endcase
	end

	always_comb begin
		case (func)
			ALU_MUL:      result = out_result[`XLEN-1:0];
			ALU_MULH:     result = out_result[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   result = out_result[2*`XLEN-1:`XLEN];
			ALU_MULHU:    result = out_result[2*`XLEN-1:`XLEN];

			default:      result = `XLEN'h0;  // here to prevent latches
		endcase
	end

	mult mult_0 (
		.clock(clock),
		.reset(reset || refresh),
		.start(val_valid),
		.sign(sign),
		.mcand(opa),
		.mplier(opb),

		.product(out_result),
		.done(valid)
	);


endmodule // mlu
