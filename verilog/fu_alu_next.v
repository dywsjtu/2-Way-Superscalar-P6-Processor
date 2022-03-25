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
        out_valid = val_valid;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || ~val_valid) begin
			valid		<=	`SD	1'b0;
			result		<=	`SD	`XLEN'b0;
		// end else if (refresh) begin
		// 	// clear intermediate values
		end else begin
			valid		<=	`SD	out_valid;
			result		<=	`SD out_result;
		end
	end
endmodule // alu


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
								  working_id_fu.valid && working_rs_fu.rs_value_valid && alu_result_valid;
	
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

	// placeholder
	assign fu_rs.take_branch = 1'b0;
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