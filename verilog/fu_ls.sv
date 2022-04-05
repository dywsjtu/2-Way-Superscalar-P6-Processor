`ifndef __FU_LS_V__
`define __FU_LS_V__

`timescale 1ns/100ps

module fu_ls(
	input                           clock,               // system clock
	input                           reset,               // system reset
	input							valid,
    input	ID_RS_PACKET			id_fu,
	input   RS_FU_PACKET            rs_fu,
	// input	[`LSQ_IDX_LEN-1:0]		loadq_pos,
    input	[`LSQ_IDX_LEN-1:0]		storeq_pos,
	input	LSQ_FU_PACKET			lsq_fu,

    output  FU_RS_PACKET            fu_rs,
	output							fu_result_valid,
	output  FU_LSQ_PACKET			fu_lsq
);
	logic 	[`XLEN-1:0] 			opa_mux_out, opb_mux_out;
	logic	[`XLEN-1:0]				alu_result;
	ID_RS_PACKET					working_id_fu;
	RS_FU_PACKET					working_rs_fu;
	// logic	[`LSQ_IDX_LEN-1:0]		working_loadq_pos;
	logic	[`LSQ_IDX_LEN-1:0]		working_storeq_pos;

	// Pass-throughs
	assign fu_rs.NPC            = working_id_fu.NPC;
	assign fu_rs.rs2_value      = working_rs_fu.rs_value[1];
	assign fu_rs.rd_mem         = working_id_fu.rd_mem;
	assign fu_rs.wr_mem         = working_id_fu.wr_mem;
	assign fu_rs.dest_reg_idx   = working_id_fu.dest_reg_idx;
	assign fu_rs.halt           = working_id_fu.halt;
	assign fu_rs.illegal        = working_id_fu.illegal;
	assign fu_rs.csr_op         = working_id_fu.csr_op;
	assign fu_rs.mem_size       = MEM_SIZE'(working_id_fu.inst.r.funct3[1:0]);


	assign alu_result 			= working_rs_fu.rs_value[0] + 
								  working_id_fu.opb_select == OPB_IS_I_IMM 	? `RV32_signext_Iimm(working_id_fu.inst)
																			: `RV32_signext_Simm(working_id_fu.inst);
	assign fu_rs.take_branch 	= 1'b0;


	assign fu_lsq.load			= working_id_fu.rd_mem;
	assign fu_lsq.store			= working_id_fu.wr_mem;
	assign fu_lsq.valid			= ~working_rs_fu.selected &&
								  working_id_fu.valid && working_rs_fu.rs_value_valid;
	assign fu_lsq.addr			= alu_result;
	assign fu_lsq.value			= working_rs_fu.rs_value[1];
	// assign fu_lsq.lq_pos		= working_loadq_pos;
	assign fu_lsq.sq_pos		= working_storeq_pos;
	
	// assign fu_result_valid		= ~reset && ~working_rs_fu.selected &&
	// 							  working_id_fu.valid && working_rs_fu.rs_value_valid;
	assign fu_result_valid		= ~reset && ~working_rs_fu.selected &&
								  working_id_fu.valid && working_rs_fu.rs_value_valid &&
								  (working_id_fu.wr_mem ? fu_lsq.valid : lsq_fu.valid);
	assign fu_rs.alu_result	 	= working_id_fu.wr_mem ? `XLEN'b0 : lsq_fu.value;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset || rs_fu.squash) begin
			working_id_fu				<=	`SD	0;
			working_rs_fu				<=	`SD	0;
			// working_loadq_pos			<=	`SD 0;
			working_storeq_pos			<=	`SD 0;
		end else if (rs_fu.selected) begin
			if (valid && id_fu.valid && id_fu.dispatch_enable) begin
				working_id_fu				<=	`SD	id_fu;
				// working_loadq_pos			<=	`SD loadq_pos;
				working_storeq_pos			<=	`SD storeq_pos;
				working_rs_fu.squash		<=	`SD	rs_fu.squash;
				working_rs_fu.selected		<=	`SD	1'b1;
				working_rs_fu.rs_value		<=	`SD rs_fu.rs_value;
				working_rs_fu.rs_value_valid<=	`SD rs_fu.rs_value_valid;
			end else begin
				working_id_fu				<=	`SD	0;
				// working_loadq_pos			<=	`SD 0;
				working_storeq_pos			<=	`SD 0;
				working_rs_fu				<=	`SD	{	1'b0,
														1'b1,
														{`XLEN'b0, `XLEN'b0},
														1'b0	};
			end
		end else begin
			if (valid && id_fu.valid && id_fu.dispatch_enable && ~working_id_fu.valid) begin
				working_id_fu				<=	`SD	id_fu;
				// working_loadq_pos			<=	`SD loadq_pos;
				working_storeq_pos			<=	`SD storeq_pos;
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

endmodule // module fu_ls
`endif // __FU_LS_V__
