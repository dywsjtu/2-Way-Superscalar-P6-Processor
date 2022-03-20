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

	// output logic [3:0]  pipeline_completed_insts,
	// output EXCEPTION_CODE   pipeline_error_status,
	// output logic [4:0]  pipeline_commit_wr_idx,
	// output logic [`XLEN-1:0] pipeline_commit_wr_data,
	// output logic        pipeline_commit_wr_en,
	// output logic [`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory


	// // Outputs from IF-Stage 
	// output logic [`XLEN-1:0] if_NPC_out,
	// output logic [31:0] if_IR_out,
	// output logic        if_valid_inst_out,
	
	// // Outputs from IF/ID Pipeline Register
	// output logic [`XLEN-1:0] if_id_NPC,
	// output logic [31:0] if_id_IR,
	// output logic        if_id_valid_inst,
	
	
	// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst
	
	
	// // Outputs from EX/MEM Pipeline Register
	// output logic [`XLEN-1:0] ex_mem_NPC,
	// output logic [31:0] ex_mem_IR,
	// output logic        ex_mem_valid_inst,
	
	
	// // Outputs from MEM/WB Pipeline Register
	// output logic [`XLEN-1:0] mem_wb_NPC,
	// output logic [31:0] mem_wb_IR,
	// output logic        mem_wb_valid_inst

);

	// Pipeline register enables
	logic   if_id_enable, dispatch_enable;//id_ex_enable, ex_mem_enable, mem_wb_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	// IF_ID_PACKET if_packet;

	// Outputs from IF/ID Pipeline Register
	// IF_ID_PACKET if_id_packet;

	// Outputs from ID stage
	ID_EX_PACKET id_packet;
	//logic dispatch_enable;

	// Outputs from ID/EX Pipeline Register
	ID_EX_PACKET id_packet_out;
	logic [`XLEN-1:0] wb_reg_wr_data_out;
	logic  [4:0] wb_reg_wr_idx_out;
	logic        wb_reg_wr_en_out;
	logic [`XLEN-1:0] mem_wb_NPC;
	
	// assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	// assign pipeline_error_status =  mem_wb_illegal             ? ILLEGAL_INST :
	//                                 mem_wb_halt                ? HALTED_ON_WFI :
	//                                 (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	//                                 NO_ERROR;
	
	// assign pipeline_commit_wr_idx = wb_reg_wr_idx_out;
	// assign pipeline_commit_wr_data = wb_reg_wr_data_out;
	// assign pipeline_commit_wr_en = wb_reg_wr_en_out;
	// assign pipeline_commit_NPC = mem_wb_NPC;

	
	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;
	
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
//              Dispatch-Stage                  //
//                                              //
//////////////////////////////////////////////////

	logic         							ex_mem_take_branch;		// taken-branch signal
	logic					[`XLEN-1:0]		ex_mem_target_pc;		// target pc: use if take_branch is TRUE
	assign ex_mem_take_branch				= 1'b0;
	assign ex_mem_target_pc					= `XLEN'b0;

	dispatch_stage dispatch_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		// .mem_wb_valid_inst(mem_wb_valid_inst),
		.stall (dispatch_enable),
		// .ex_mem_take_branch(ex_mem_packet.take_branch),
		// .ex_mem_target_pc(ex_mem_packet.alu_result),
		.ex_mem_take_branch(ex_mem_take_branch),
		.ex_mem_target_pc(ex_mem_target_pc),
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.id_packet_out(id_packet)
	);


//////////////////////////////////////////////////
//                                              //
//     Dispatch/ROBRSMT Pipeline Register       //
//                                              //
//////////////////////////////////////////////////

	assign id_ex_NPC        = id_packet_out.NPC;
	assign id_ex_IR         = id_packet_out.inst;
	assign id_ex_valid_inst = id_packet_out.valid;

	assign id_ex_enable 	= 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			id_packet_out 	<= `SD '{	{`XLEN{1'b0}},
										{`XLEN{1'b0}}, 
 
										OPA_IS_RS1, 
										OPB_IS_RS2, 
										`NOP,
										
										`ZERO_REG,
										{5'b0,5'b0},

										ALU_ADD, 
										1'b0, //rd_mem
										1'b0, //wr_mem
										1'b0, //cond
										1'b0, //uncond
										1'b0, //halt
										1'b0, //illegal
										1'b0, //csr_op
										1'b0, //valid
										2'b0
									}; 
		end else begin // if (reset)
			if (id_ex_enable) begin
				id_packet_out <= `SD id_packet;
			end // if
		end // else: !if(reset)
	end // always


//////////////////////////////////////////////////
//                                              //
//       ROB RS MT balabala start here          //
//                                              //
//////////////////////////////////////////////////


	// ID
	ID_ROB_PACKET       id_rob;   
	ID_RS_PACKET        id_rs;

	// CDB
	CDB_ENTRY           cdb_out;
	
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

	
	assign dispatch_enable = !rob_full && !rs_entry_full; // TO DO check lsq not full
	//ID TO ROB
	assign id_rob.dispatch_enable = dispatch_enable;
	assign id_rob.dest_reg_idx = id_packet_out.dest_reg_idx;
	assign id_rob.PC = id_packet_out.PC;
	//ID TO RS
	assign id_rs = {
						id_packet_out.NPC,			
						id_packet_out.PC,			                             
						dispatch_enable,                    
						id_packet_out.opa_select,	
						id_packet_out.opb_select,	
						id_packet_out.inst,	
						id_packet_out.dest_reg_idx,    
						id_packet_out.input_reg_idx,
						id_packet_out.alu_func,		
						id_packet_out.rd_mem,		
						id_packet_out.wr_mem,		
						id_packet_out.cond_branch,
						id_packet_out.uncond_branch,	
						id_packet_out.halt,			
						id_packet_out.illegal,		
						id_packet_out.csr_op,		
						id_packet_out.valid,		
						id_packet_out.req_reg 	
					};                           
	//ID TO MT
	logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch; // where does this come from??
	assign rd_dispatch = id_packet_out.dest_reg_idx;

    FU_ROB_PACKET       fu_rob;


	REG_RS_PACKET       reg_rs;
	RS_REG_PACKET    	rs_reg;

	regfile regf_0 (
		/*RS TO REG*/
		.rda_idx(rs_reg.register_idxes[0]),
		.rda_out(reg_rs.rs_values[0]), 

		.rdb_idx(rs_reg.register_idxes[1]),
		.rdb_out(reg_rs.rs_values[1]),

		/*ROB TO REG*/
		.wr_clk(clock),
		.wr_en(rob_reg.dest_valid),
		.wr_idx(rob_reg.dest_reg_idx),
		.wr_data(rob_reg.dest_value)
	);


	//temporary input from fu
	logic FU_valid;
	logic [`ROB_IDX_LEN:0] FU_tag;
	logic [`XLEN-1:0] FU_value;

	cdb cdb_0(
		//INPUT
        .clock(clock),
		.reset(reset),
		.squash(rob_rs.squash),
		.FU_valid(FU_valid),
		.FU_tag(FU_tag),
		.FU_value(FU_value),

		//OUTPUT
		.cdb_out(cdb_out)
	);

	// TODO fix this
	map_table map_table_0 (
        //input
        .clock(clock),
		.reset(reset),
        .dispatch_enable(dispatch_enable),
        .rd_dispatch(id_packet_out.dest_reg_idx),
        .rob_mt(rob_mt),

        .cdb_in(cdb_out),
        .rs_mt(rs_mt),

        //input logic [$clog2(`REG_SIZE)-1:0]     rd_retire, // rd idx to clear in retire stage
        //input logic                             clear, //tag-clear signal in retire stage (should sent from ROB?)         

        //output
        .mt_rs(mt_rs)
    );


	rs rs_0(
		// input
		.clock(clock),
		.reset(reset),
		.id_rs(id_rs),
		.mt_rs(mt_rs),
		.reg_rs(reg_rs),
		.cdb_rs(cdb_out),
		.rob_rs(rob_rs),
		// output
		.rs_mt(rs_mt),
		.rs_reg(rs_reg),
		//.rs_fu(rs_fu),
		.rs_rob(rs_rob),
		.rs_entry_full(rs_entry_full)
	);

	rob rob_0(
		// input
		.clock(clock),
		.reset(reset),

		.id_rob(id_rob),
		.rs_rob(rs_rob),
		.fu_rob(fu_rob),
		// output
		.rob_full(rob_full),

		.rob_rs(rob_rs),
		.rob_mt(rob_mt),
		.rob_reg(rob_reg)
	);  


// 	//////////////////////////////////////////////////
// //                                              //
// //            ID/EX Pipeline Register           //
// //                                              //
// //////////////////////////////////////////////////

// 	assign id_ex_NPC        = id_ex_packet.NPC;
// 	assign id_ex_IR         = id_ex_packet.inst;
// 	assign id_ex_valid_inst = id_ex_packet.valid;

// 	assign id_ex_enable = 1'b1; // always enabled
// 	// synopsys sync_set_reset "reset"
// 	always_ff @(posedge clock) begin
// 		if (reset) begin
// 			id_ex_packet <= `SD '{{`XLEN{1'b0}},
// 				{`XLEN{1'b0}}, 
// 				{`XLEN{1'b0}}, 
// 				{`XLEN{1'b0}}, 
// 				OPA_IS_RS1, 
// 				OPB_IS_RS2, 
// 				`NOP,
// 				`ZERO_REG,
// 				ALU_ADD, 
// 				1'b0, //rd_mem
// 				1'b0, //wr_mem
// 				1'b0, //cond
// 				1'b0, //uncond
// 				1'b0, //halt
// 				1'b0, //illegal
// 				1'b0, //csr_op
// 				1'b0 //valid
// 			}; 
// 		end else begin // if (reset)
// 			if (id_ex_enable) begin
// 				id_ex_packet <= `SD id_packet;
// 			end // if
// 		end // else: !if(reset)
// 	end // always


// //////////////////////////////////////////////////
// //                                              //
// //                  EX-Stage                    //
// //                                              //
// //////////////////////////////////////////////////
// 	ex_stage ex_stage_0 (
// 		// Inputs
// 		.clock(clock),
// 		.reset(reset),
// 		.id_ex_packet_in(id_ex_packet),
// 		// Outputs
// 		.ex_packet_out(ex_packet)
// 	);


// //////////////////////////////////////////////////
// //                                              //
// //           EX/MEM Pipeline Register           //
// //                                              //
// //////////////////////////////////////////////////
	
// 	assign ex_mem_NPC        = ex_mem_packet.NPC;
// 	assign ex_mem_valid_inst = ex_mem_packet.valid;

// 	assign ex_mem_enable = 1'b1; // always enabled
// 	// synopsys sync_set_reset "reset"
// 	always_ff @(posedge clock) begin
// 		if (reset) begin
// 			ex_mem_IR     <= `SD `NOP;
// 			ex_mem_packet <= `SD 0;
// 		end else begin
// 			if (ex_mem_enable)   begin
// 				// these are forwarded directly from ID/EX registers, only for debugging purposes
// 				ex_mem_IR     <= `SD id_ex_IR;
// 				// EX outputs
// 				ex_mem_packet <= `SD ex_packet;
// 			end // if
// 		end // else: !if(reset)
// 	end // always

   
// //////////////////////////////////////////////////
// //                                              //
// //                 MEM-Stage                    //
// //                                              //
// //////////////////////////////////////////////////
// 	mem_stage mem_stage_0 (// Inputs
// 		.clock(clock),
// 		.reset(reset),
// 		.ex_mem_packet_in(ex_mem_packet),
// 		.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),
		
// 		// Outputs
// 		.mem_result_out(mem_result_out),
// 		.proc2Dmem_command(proc2Dmem_command),
// 		.proc2Dmem_size(proc2Dmem_size),
// 		.proc2Dmem_addr(proc2Dmem_addr),
// 		.proc2Dmem_data(proc2Dmem_data)
// 	);


// //////////////////////////////////////////////////
// //                                              //
// //           MEM/WB Pipeline Register           //
// //                                              //
// //////////////////////////////////////////////////
// 	assign mem_wb_enable = 1'b1; // always enabled

endmodule  // module verisimple
`endif // __PIPELINE_V__
