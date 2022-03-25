`ifndef __FU_BEQ_V__
`define __FU_BEQ_V__

`timescale 1ns/100ps

module fu_beq(
	input                           clock,               // system clock
	input                           reset,               // system reset
	input							valid,
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
			if (valid && id_fu.valid && id_fu.dispatch_enable) begin
				working_id_fu			<=	`SD	id_fu;
				working_rs_fu.squash		<=	`SD	rs_fu.squash;
				working_rs_fu.selected		<=	`SD	1'b1;
				working_rs_fu.rs_value		<=	`SD rs_fu.rs_value;
				working_rs_fu.rs_value_valid<=	`SD rs_fu.rs_value_valid;
			end else begin
				working_id_fu			<=	`SD	0;
				working_rs_fu			<=	`SD	{	1'b0,
													1'b1,
													{`XLEN'b0, `XLEN'b0},
													1'b0	};
			end
		end else begin
			if (valid && id_fu.valid && id_fu.dispatch_enable && ~working_id_fu.valid) begin
				working_id_fu				<=	`SD	id_fu;
				working_rs_fu.squash		<=	`SD	rs_fu.squash;
				working_rs_fu.selected		<=	`SD	1'b1;
				working_rs_fu.rs_value		<=	`SD rs_fu.rs_value;
				working_rs_fu.rs_value_valid<=	`SD rs_fu.rs_value_valid;
			end else begin 
				if (working_id_fu.valid && rs_fu.rs_value_valid && ~working_rs_fu.rs_value_valid) begin
					// working_rs_fu			<=	`SD	rs_fu;
					working_rs_fu.squash		<=	`SD	rs_fu.squash;
					working_rs_fu.selected		<=	`SD	1'b1;
					working_rs_fu.rs_value		<=	`SD rs_fu.rs_value;
					working_rs_fu.rs_value_valid<=	`SD rs_fu.rs_value_valid;
				end else if (working_rs_fu.selected) begin
					working_rs_fu.selected	<=	`SD	1'b0;
				end
			end
		end
	end

endmodule // module fu_beq
`endif // __FU_BEQ_V__
