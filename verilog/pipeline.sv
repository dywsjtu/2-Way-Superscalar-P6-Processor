/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [3:0]  pipeline_completed_insts,
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
	
	// Outputs from IF-Stage 
	output logic [`XLEN-1:0] if_NPC_out,
	output logic [31:0] if_IR_out,
	output logic        if_valid_inst_out,
	
	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] if_id_NPC,
	output logic [31:0] if_id_IR,
	output logic        if_id_valid_inst,
	
	
	// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst,
	
	
	// Outputs from EX/MEM Pipeline Register
	output logic [`XLEN-1:0] ex_mem_NPC,
	output logic [31:0] ex_mem_IR,
	output logic        ex_mem_valid_inst,
	
	
	// Outputs from MEM/WB Pipeline Register
	output logic [`XLEN-1:0] mem_wb_NPC,
	output logic [31:0] mem_wb_IR,
	output logic        mem_wb_valid_inst

);

	// Pipeline register enables
	logic   if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET if_packet;

	// Outputs from IF/ID Pipeline Register
	IF_ID_PACKET if_id_packet;

	// Outputs from ID stage
	ID_EX_PACKET id_packet;

	// Outputs from ID/EX Pipeline Register
	ID_EX_PACKET id_ex_packet;
	
	assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	assign pipeline_error_status =  mem_wb_illegal             ? ILLEGAL_INST :
	                                mem_wb_halt                ? HALTED_ON_WFI :
	                                (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	                                NO_ERROR;
	
	assign pipeline_commit_wr_idx = wb_reg_wr_idx_out;
	assign pipeline_commit_wr_data = wb_reg_wr_data_out;
	assign pipeline_commit_wr_en = wb_reg_wr_en_out;
	assign pipeline_commit_NPC = mem_wb_NPC;
	
	assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? BUS_LOAD : proc2Dmem_command;
	assign proc2mem_addr =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size =
	     (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = {32'b0, proc2Dmem_data};

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_NPC_out        = if_packet.NPC;
	assign if_IR_out         = if_packet.inst;
	assign if_valid_inst_out = if_packet.valid;
	
	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.mem_wb_valid_inst(mem_wb_valid_inst),
		.ex_mem_take_branch(ex_mem_packet.take_branch),
		.ex_mem_target_pc(ex_mem_packet.alu_result),
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.if_packet_out(if_packet)
	);


//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC        = if_id_packet.NPC;
	assign if_id_IR         = if_id_packet.inst;
	assign if_id_valid_inst = if_id_packet.valid;
	assign if_id_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin 
			if_id_packet.inst  <= `SD `NOP;
			if_id_packet.valid <= `SD `FALSE;
            if_id_packet.NPC   <= `SD 0;
            if_id_packet.PC    <= `SD 0;
		end else begin// if (reset)
			if (if_id_enable) begin
				if_id_packet <= `SD if_packet; 
			end // if (if_id_enable)	
		end
	end // always

   
//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	id_stage id_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.if_id_packet_in(if_id_packet),
		.wb_reg_wr_en_out   (wb_reg_wr_en_out),
		.wb_reg_wr_idx_out  (wb_reg_wr_idx_out),
		.wb_reg_wr_data_out (wb_reg_wr_data_out),
		
		// Outputs
		.id_packet_out(id_packet)
	);


	// ID
	ID_ROB_PACKET       id_rob;
	ID_RS_PACKET        id_rs;

	// CDB
	CDB_ENTRY           cdb_out,
	
	// Map table
	MT_RS_PACKET        mt_rs;

	// RS
	logic rs_entry_full;
	RS_ROB_PACKET       rs_rob;
	RS_MT_PACKET        rs_mt;
    RS_FU_PACKET        rs_fu;

	// ROB
	logic rob_full;
    ROB_RS_PACKET       rob_rs;
    ROB_MT_PACKET       rob_mt;
    ROB_REG_PACKET      rob_reg;

	assign dispatch_enable = !rob_full && !rs_entry_full; // TODO check lsq not full
	logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch // where does this come from??

    FU_ROB_PACKET       fu_rob;


	REG_RS_PACKET       reg_rs;


	cdb cdb_0(
		//INPUT
        .clock(clock),
		.reset(reset),
		.squash(rob_rs.squash),
		input logic                 FU_valid,
		input logic [`ROB_IDX_LEN:0]  FU_tag,
		input logic [`XLEN-1:0]     FU_value,

		//OUTPUT
		.cdb_out(cdb_out)
	);

	// TODO fix this
	map_table map_table_0 (
        //INPUT
        .clock(clock),
		.reset(reset),
        .dispatch_enable(dispatch_enable)
        .rob_mt(rob_mt),
        .rd_dispatch(rob_mt.rob_tail),

        .cdb_in(cdb_out);
        .rs_mt(rs_mt),

        input logic [$clog2(`REG_SIZE)-1:0]     rd_retire, // rd idx to clear in retire stage
        input logic                             clear, //tag-clear signal in retire stage (should sent from ROB?)         

        //OUTPUT
        .mt_rs(mt_rs)
    );


	rs rs_0(
		.clock(clock),
		.reset(reset),
		.id_rs(id_rs),
		.mt_rs(mt_rs),
		.reg_rs(reg_rs),
		.cdb_rs(cdb_rs),
		.rob_rs(rob_rs),
		.rs_mt(rs_mt),
		.rs_fu(rs_fu),
		.rs_rob(rs_rob),
		.rs_entry_full(rs_entry_full)
	);

	rob rob_0(
		.clock(clock),
		.reset(reset),

		.id_rob(id_rob),
		.rs_rob(rs_rob),
		.fu_rob(fu_rob),

		.rob_full(rob_full),

		.rob_rs(rob_rs),
		.rob_mt(rob_mt),
		.rob_reg(rob_reg)
	);  

endmodule  // module verisimple
`endif // __PIPELINE_V__
