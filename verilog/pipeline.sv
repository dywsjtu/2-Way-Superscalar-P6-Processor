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

	output logic [3:0]  		pipeline_completed_insts,
	output EXCEPTION_CODE   	pipeline_error_status,
	output logic [4:0]  		pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] 	pipeline_commit_wr_data,
	output logic        		pipeline_commit_wr_en,
	output logic [`XLEN-1:0] 	pipeline_commit_NPC,
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst
	

);

//////////////////////////////////////////////////
//                                              //
//       ROB RS MT balabala packet def          //
//                                              //
//////////////////////////////////////////////////


	// ID
	ID_ROB_PACKET       id_rob;   
	ID_RS_PACKET        id_rs;
	// logic				sq_rob_valid;
	// logic				sq_retire;

	// CDB
	CDB_ENTRY           cdb_out;
	CDB_ENTRY			rs_cdb;
	
	// Map table
	MT_RS_PACKET        mt_rs;

	// RS
	logic 				rs_entry_full;
	RS_ROB_PACKET       rs_rob;
	RS_MT_PACKET        rs_mt;
    RS_FU_PACKET        rs_fu;
	RS_REG_PACKET    	rs_reg;
	RS_LSQ_PACKET		rs_lsq;
	FU_LSQ_PACKET   [`NUM_LS-1:0]   fu_lsq;
	LSQ_RS_PACKET                   lsq_rs;
	LSQ_FU_PACKET   [`NUM_LS-1:0]   lsq_fu;

	// ROB
	logic 				rob_full;
    ROB_RS_PACKET       rob_rs;
    ROB_MT_PACKET       rob_mt;
    ROB_REG_PACKET      rob_reg;
	ROB_ID_PACKET       rob_id;
	ROB_LSQ_PACKET		rob_lsq;
	LSQ_ROB_PACKET		lsq_rob;

	REG_RS_PACKET       reg_rs;

//////////////////////////////////////////////////
//                                              //
//     ROB RS MT balabala packet def end        //
//                                              //
//////////////////////////////////////////////////

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

	logic halt;
	logic squash;

	assign pipeline_completed_insts = {3'b0, rob_reg.valid};
	assign memory_error = (proc2mem_command != BUS_NONE && mem2proc_response==4'h0);
	assign pipeline_error_status 	= 	halt			?	HALTED_ON_WFI :
										memory_error 	? 	LOAD_ACCESS_FAULT :
	                                						NO_ERROR;
	
	assign pipeline_commit_wr_idx 	= rob_reg.dest_reg_idx;
	assign pipeline_commit_wr_data 	= rob_reg.dest_value;
	assign pipeline_commit_wr_en 	= rob_reg.dest_valid;
	assign pipeline_commit_NPC 		= rob_reg.OLD_PC_p_4;
	
		//////////////////////////////////////////////////
	//                                              //
	//              ICache                          //
	//                                              //
	//////////////////////////////////////////////////

	logic [`XLEN-1:0] proc2Icache_addr;
	logic [1:0] proc2Imem_command;
    logic [63:0] Icache_data_out; // value is memory[proc2Icache_addr]
    logic Icache_valid_out;      // when this is high

	icache icache_0 (
		.clock(clock),
		.reset(reset),
	 	.Imem2proc_response(do_Ifetch ? mem2proc_response : 4'b0),
	    .Imem2proc_data(mem2proc_data),
	    .Imem2proc_tag(mem2proc_tag),

	    .proc2Icache_addr(proc2Icache_addr),

    	.proc2Imem_command(proc2Imem_command),
    	.proc2Imem_addr(proc2Imem_addr),

	    .Icache_data_out(Icache_data_out),
	    .Icache_valid_out(Icache_valid_out)
	);

	// Memory

	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;

	assign proc2Dmem_command = BUS_NONE;
	
	assign do_Ifetch = (proc2Dmem_command == BUS_NONE);

	assign proc2mem_command =
	     do_Ifetch ? proc2Imem_command : proc2Dmem_command;
	assign proc2mem_addr =
	     do_Ifetch ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size =
	     do_Ifetch ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = {32'b0, proc2Dmem_data};

	// always @* begin
	// 	$monitor("proc2mem_data", proc2mem_data);
	// end


//////////////////////////////////////////////////
//                                              //
//              Dispatch-Stage                  //
//                                              //
//////////////////////////////////////////////////

	// logic         							ex_mem_take_branch;		// taken-branch signal
	// logic					[`XLEN-1:0]		ex_mem_target_pc;		// target pc: use if take_branch is TRUE
	// assign ex_mem_take_branch				= 1'b0;
	// assign ex_mem_target_pc					= `XLEN'b0;

	logic [31:0] cycle_count;
	always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            $display("DEBUG %4d: Icache_valid_out = %d, proc2mem_command = %d, proc2Imem_command = %d, proc2mem_addr = %d", cycle_count, Icache_valid_out, proc2mem_command, proc2Imem_command, proc2mem_addr);
            cycle_count = cycle_count + 1;
        end
    end

	dispatch_stage dispatch_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		// .mem_wb_valid_inst(mem_wb_valid_inst),
		.stall(~dispatch_enable),
		// .ex_mem_take_branch(ex_mem_take_branch),
		// .ex_mem_target_pc(ex_mem_target_pc),
		.Imem2proc_data(Icache_data_out),
		.rob_id(rob_id),
		
		// Outputs
		.proc2Imem_addr(proc2Icache_addr),
		.id_packet_out(id_packet)
	);

	// always @(posedge clock) begin
	// 	$display("DEBUG pipeline I addr", proc2Imem_addr);
	// end


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
		if (reset || rob_id.squash) begin
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
										1'b0,
										1'b0, //valid
										2'b0,
										1'b0
									}; 
		end else if (dispatch_enable) begin // if (reset)
			if (id_ex_enable) begin
				id_packet_out <= `SD id_packet;
			end // if
		end // else: !if(reset)
	end // always

		
	assign dispatch_enable = (!rob_full) && (!rs_entry_full) && Icache_valid_out; // TO DO check lsq not full
	//ID TO ROB
	assign id_rob = {	
						id_packet_out.valid && ~id_packet_out.illegal,
						id_packet_out.PC,
						dispatch_enable,
						id_packet_out.dest_reg_idx,
						id_packet_out.wr_mem,
						id_packet_out.take_branch,
						id_packet_out.halt
					};
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
						id_packet_out.mult_op,	
						id_packet_out.valid,		
						id_packet_out.req_reg 	
					};                           
	//ID TO MT
	logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch; // where does this come from??
	assign rd_dispatch = id_packet_out.dest_reg_idx;


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
		.wr_data(rob_reg.dest_value),
		`ifdef DEBUG
		.reset(reset)
		`endif
	);


	//temporary input from fu
	logic FU_valid;
	logic [`ROB_IDX_LEN:0] FU_tag;
	logic [`XLEN-1:0] FU_value;

	cdb cdb_0(
        //input
        .clock(clock),
		.reset(reset), 
		.rs_cdb(rs_cdb),

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
		.lsq_rs(lsq_rs),
		.lsq_fu(lsq_fu),
		// output
		.rs_mt(rs_mt),
		.rs_cdb(rs_cdb),
		.rs_reg(rs_reg),
		//.rs_fu(rs_fu),
		.rs_rob(rs_rob),
		.rs_lsq(rs_lsq),
		.rs_entry_full(rs_entry_full),
		.fu_lsq(fu_lsq)
	);

	rob rob_0(
		// input
		.clock(clock),
		.reset(reset),

		.id_rob(id_rob),
		.rs_rob(rs_rob),
		.cdb_rob(cdb_out),
		.lsq_rob(lsq_rob),
		// .sq_rob_valid(sq_rob_valid),
		// output
		.rob_full(rob_full),
		.halt(halt),
		.squash(squash),
		.rob_id(rob_id),
		.rob_rs(rob_rs),
		.rob_mt(rob_mt),
		.rob_reg(rob_reg),
		.rob_lsq(rob_lsq)
		// .sq_retire(sq_retire)
	);

	DCACHE_LOAD_LSQ_PACKET          dc_load_lsq;
	DCACHE_STORE_LSQ_PACKET         dc_store_lsq;
	LSQ_LOAD_DCACHE_PACKET          lsq_load_dc;
	LSQ_STORE_DCACHE_PACKET         lsq_store_dc;

	lsq lsq_0 (
		.clock(clock),
		.reset(reset),
		.squash(squash),

		.rs_lsq(rs_lsq),
		.fu_lsq(fu_lsq),
		.rob_lsq(rob_lsq),
		// .sq_retire(sq_retire), // from rob
		// .store_finish, // from d-cache indicate whether the store finished write

		// .sq_rob_valid(sq_rob_valid), // to rob
		.lsq_rob(lsq_rob),
		.lsq_fu(lsq_fu),
		.lsq_rs(lsq_rs),

		.dc_load_lsq(dc_load_lsq),
		.dc_store_lsq(dc_store_lsq),
		.lsq_load_dc(lsq_load_dc),
		.lsq_store_dc(lsq_store_dc)

	);

endmodule  // module verisimple
`endif // __PIPELINE_V__
