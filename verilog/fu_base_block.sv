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

//
// The MLU
//
// alu for mult
//
// This module is purely combinational
//
module mlu #(parameter NUM_STAGE = 4) (
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
	logic 			[2*`XLEN-1:0]	mcand_out, mplier_out, mcand_in, mplier_in;
	logic			[2*`XLEN-1:0]	product_out, product_in;
	logic			[2:0]			step_counter;

	logic [1:0] sign;
	always_comb begin
		case (func)
			ALU_MULHSU:   sign = 2'b01;
			ALU_MULHU:    sign = 2'b00;
			default:      sign = 2'b11;
		endcase
	end

	always_comb begin
		case (func)
			ALU_MUL:      result = product_out[`XLEN-1:0];
			default:      result = product_out[2*`XLEN-1:`XLEN];
		endcase
	end

	mult_stage #(.NUM_STAGE(NUM_STAGE)) mstage (
		.mplier_in(mplier_in),
		.mcand_in(mcand_in),
		.product_in(product_in),
		.mplier_out(mplier_out),
		.mcand_out(mcand_out),
		.product_out(product_out)
	);

	always_ff @(posedge clock) begin
		if (reset || ~val_valid) begin
			mcand_in  		<= `SD 64'b0;
			mplier_in 		<= `SD 64'b0;
			product_in		<= `SD 64'b0;
			step_counter	<= `SD 3'b0;
			valid			<= `SD 1'b0;
		end else if (refresh) begin
			mcand_in  		<= `SD sign[0] ? {{`XLEN{opa[`XLEN-1]}}, opa} : {{`XLEN{1'b0}}, opa};
			mplier_in 		<= `SD sign[1] ? {{`XLEN{opb[`XLEN-1]}}, opb} : {{`XLEN{1'b0}}, opb};
			product_in		<= `SD 64'b0;
			step_counter	<= `SD 3'b0;
			valid			<= `SD 1'b0;
		end else begin
			if (step_counter == (NUM_STAGE)) begin
				valid			<= `SD 1'b1;
			end else begin
				mcand_in  		<= `SD mcand_out;
				mplier_in 		<= `SD mplier_out;
				product_in		<= `SD product_out;
				step_counter	<= `SD step_counter + 1;
				valid			<= `SD 1'b0;
			end
		end
	end

endmodule // mlu

module mult_stage #(parameter NUM_STAGE = 4) (
	input [(2*`XLEN)-1:0] mplier_in, mcand_in,
	input [(2*`XLEN)-1:0] product_in,

	output logic [(2*`XLEN)-1:0] mplier_out, mcand_out,
	output logic [(2*`XLEN)-1:0] product_out
);
	logic [(2*`XLEN)-1:0] partial_prod;
	parameter NUM_BITS = (2*`XLEN)/NUM_STAGE;

	assign product_out = product_in + partial_prod;
	assign partial_prod = mplier_in[(NUM_BITS-1):0] * mcand_in;

	assign mplier_out = {{(NUM_BITS){1'b0}},mplier_in[2*`XLEN-1:(NUM_BITS)]};
	assign mcand_out  = {mcand_in[(2*`XLEN-1-NUM_BITS):0],{(NUM_BITS){1'b0}}};

endmodule

`endif // __FU_BASE_BLOCK__