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
	wire signed 	[2*`XLEN-1:0]   signed_mul, mixed_mul;
	wire        	[2*`XLEN-1:0]   unsigned_mul;

	logic [2:0]						cnt;

	assign signed_opa   = opa;
	assign signed_opb   = opb;
	assign signed_mul   = signed_opa * signed_opb;
	assign unsigned_mul = opa * opb;
	assign mixed_mul    = signed_opa * opb;

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
			ALU_MUL:      out_result = signed_mul[`XLEN-1:0];
			ALU_MULH:     out_result = signed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   out_result = mixed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHU:    out_result = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      out_result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
        out_valid = val_valid && cnt[2];
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || ~val_valid) begin
			valid		<=	`SD	1'b0;
			result		<=	`SD	`XLEN'b0;
			cnt			<=	`SD 3'b001;
		end else if (refresh) begin
			valid		<=	`SD	out_valid;
			result		<=	`SD out_result;
			cnt			<=	`SD 3'b001;
		// 	// clear intermediate values
		end else begin
			valid		<=	`SD	out_valid;
			result		<=	`SD out_result;
			if (cnt == 3'b001) begin
				cnt		<=	`SD 3'b010;
			end else if (cnt == 3'b010) begin
				cnt		<=	`SD 3'b100;
			end else begin
				cnt		<=	`SD 3'b100;
			end
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


module fu_alu(
	input                           clock,               // system clock
	input                           reset,               // system reset
    input	ID_RS_PACKET			id_fu,
	input   RS_FU_PACKET            rs_fu,

    output  FU_RS_PACKET            fu_rs,
	output							fu_result_valid
);
	logic 	[`XLEN-1:0] 			opa_mux_out, opb_mux_out;
	logic 							brcond_result;
	logic							brcond_result_valid;
	logic	[`XLEN-1:0]				alu_result;
    logic                           alu_result_valid;
	ID_RS_PACKET					working_id_fu;
	RS_FU_PACKET					working_rs_fu;

	// Pass-throughs
	assign fu_rs.NPC            = working_id_fu.NPC;
	assign fu_rs.rs2_value      = working_rs_fu.rs_value[1];
	assign fu_rs.rd_mem         = working_id_fu.rd_mem;
	assign fu_rs.wr_mem         = working_id_fu.wr_mem;
	assign fu_rs.dest_reg_idx   = working_id_fu.dest_reg_idx;
	assign fu_rs.halt           = working_id_fu.halt;
	assign fu_rs.illegal        = working_id_fu.illegal;
	assign fu_rs.csr_op         = working_id_fu.csr_op;
	assign fu_rs.mem_size       = working_id_fu.inst.r.funct3;
	assign fu_result_valid		= ~working_rs_fu.selected &&
								  working_id_fu.valid && working_rs_fu.rs_value_valid && 
								  brcond_result_valid && alu_result_valid;
	
	//
	// ALU opA mux
	//
	always_comb begin
		opa_mux_out = `XLEN'hdeadfbac;
		case (working_id_fu.opa_select)
			OPA_IS_RS1:  opa_mux_out = working_rs_fu.rs_value[0];
			OPA_IS_NPC:  opa_mux_out = working_id_fu.NPC;
			OPA_IS_PC:   opa_mux_out = working_id_fu.PC;
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
		case (working_id_fu.opb_select)
			OPB_IS_RS2:   opb_mux_out = working_rs_fu.rs_value[1];
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(working_id_fu.inst);
			OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(working_id_fu.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(working_id_fu.inst);
			OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(working_id_fu.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(working_id_fu.inst);
		endcase 
	end


	//
	// instantiate the ALU
	//
	alu alu_0 (// Inputs
		.clock(clock),
		.reset(reset),

		.refresh(working_rs_fu.squash || working_rs_fu.selected),
		.val_valid(working_rs_fu.rs_value_valid),
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(working_id_fu.alu_func),

		// Output
		.valid(alu_result_valid),
		.result(alu_result)
	);

	// 
	 // instantiate the branch condition tester
	 //
	brcond brcond (// Inputs
		.clock(clock),
		.reset(reset),

		.refresh(working_rs_fu.squash || working_rs_fu.selected),
		.val_valid(working_rs_fu.rs_value_valid),
		.rs1(working_rs_fu.rs_value[0]), 
		.rs2(working_rs_fu.rs_value[1]),
		.func(working_id_fu.inst.b.funct3), // inst bits to determine check

		// Output
		.valid(brcond_result_valid),
		.cond(brcond_result)
	);

	 // ultimate "take branch" signal:
	 //	unconditional, or conditional and the condition is true
	assign fu_rs.take_branch = working_id_fu.uncond_branch || 
							   (working_id_fu.cond_branch & brcond_result);
	assign fu_rs.alu_result	 = alu_result;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || rs_fu.squash) begin
			working_id_fu				<=	`SD	0;
			working_rs_fu				<=	`SD	0;
		end else if (rs_fu.selected) begin
			if (id_fu.valid && id_fu.dispatch_enable) begin
				working_id_fu			<=	`SD	id_fu;
			end else begin
				working_id_fu			<=	`SD	0;
			end
			if (id_fu.valid && id_fu.dispatch_enable && rs_fu.rs_value_valid) begin
				working_rs_fu			<=	`SD	rs_fu;
			end else begin
				working_rs_fu			<=	`SD	{	1'b0,
													1'b1,
													{`XLEN'b0, `XLEN'b0},
													1'b0	};
			end
		end else begin
			if (id_fu.valid && id_fu.dispatch_enable && ~working_id_fu.valid) begin
				working_id_fu			<=	`SD	id_fu;
			end
			if (((id_fu.valid && id_fu.dispatch_enable) || working_id_fu.valid) &&
				rs_fu.rs_value_valid && ~working_rs_fu.rs_value_valid) begin
				working_rs_fu			<=	`SD	rs_fu;
			end else if (working_rs_fu.selected) begin
				working_rs_fu.selected	<=	`SD	1'b0;
			end
		end
	end

endmodule // module fu_alu
`endif // __FU_ALU_V__
