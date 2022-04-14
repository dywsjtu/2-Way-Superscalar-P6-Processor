/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  // 
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __REGFILE_2_V__
`define __REGFILE_2_V__

`timescale 1ns/100ps

module regfile_2 (
	input                           	clock,

	input         	[4:0]             	rda_idx_0, rdb_idx_0,           // read index
	input         	[4:0]             	rda_idx_1, rdb_idx_1,           // read index

	input			[4:0]				wr_idx_0, wr_idx_1, 
	input								wr_en_0, wr_en_1,
	input         	[`XLEN-1:0]       	wr_data_0, wr_data_1,			// write index / data

	output logic  	[`XLEN-1:0]       	rda_out_0, rdb_out_0,           // read data
	output logic  	[`XLEN-1:0]       	rda_out_1, rdb_out_1            // read data

	`ifdef DEBUG
	,input logic reset
	`endif 
);

	logic	[31:0] [`XLEN-1:0] registers;   // 32, 64-bit Registers

	wire	[`XLEN-1:0] rda_reg_0 = registers[rda_idx_0];
	wire	[`XLEN-1:0] rdb_reg_0 = registers[rdb_idx_0];
	wire	[`XLEN-1:0] rda_reg_1 = registers[rda_idx_1];
	wire	[`XLEN-1:0] rdb_reg_1 = registers[rdb_idx_1];

	//
	// Read port A
	//
	always_comb begin
		if (rda_idx_0 == `ZERO_REG)
			rda_out_0 = 0;
		else if (wr_en_1 && (wr_idx_1 == rda_idx_0))
			rda_out_0 = wr_data_1;  // internal forwarding
		else if (wr_en_0 && (wr_idx_0 == rda_idx_0))
			rda_out_0 = wr_data_0;  // internal forwarding
		else
			rda_out_0 = rda_reg_0;
	end

	always_comb begin
		if (rda_idx_1 == `ZERO_REG)
			rda_out_1 = 0;
		else if (wr_en_1 && (wr_idx_1 == rda_idx_1))
			rda_out_1 = wr_data_1;  // internal forwarding
		else if (wr_en_0 && (wr_idx_0 == rda_idx_1))
			rda_out_1 = wr_data_0;  // internal forwarding
		else
			rda_out_1 = rda_reg_1;
	end

	//
	// Read port B
	//
	always_comb begin
		if (rdb_idx_0 == `ZERO_REG)
			rdb_out_0 = 0;
		else if (wr_en_1 && (wr_idx_1 == rdb_idx_0))
			rdb_out_0 = wr_data_1;  // internal forwarding
		else if (wr_en_0 && (wr_idx_0 == rdb_idx_0))
			rdb_out_0 = wr_data_0;  // internal forwarding
		else
			rdb_out_0 = rdb_reg_0;
	end

	always_comb begin
		if (rdb_idx_1 == `ZERO_REG)
			rdb_out_1 = 0;
		else if (wr_en_1 && (wr_idx_1 == rdb_idx_1))
			rdb_out_1 = wr_data_1;  // internal forwarding
		else if (wr_en_0 && (wr_idx_0 == rdb_idx_1))
			rdb_out_1 = wr_data_0;  // internal forwarding
		else
			rdb_out_1 = rdb_reg_1;
	end

	//
	// Write port
	//
	always_ff @(posedge clock) begin
		if (wr_en_0 && wr_en_1 && wr_idx_0 == wr_idx_1) begin
			registers[wr_idx_1]		<= `SD wr_data_1;
		end else begin
			if (wr_en_1) begin
				registers[wr_idx_1] <= `SD wr_data_1;
			end
			if (wr_en_0) begin
				registers[wr_idx_0] <= `SD wr_data_0;
			end
		end
	end


	`ifdef DEBUG
	logic [31:0] cycle_count;
	// synopsys sync_set_reset "reset"
	always_ff @(negedge wr_clk) begin
	if(reset) begin
			cycle_count = 0;
		end else begin
			for(int i = 0; i < 32; i += 4) begin
				$display("DEBUG %4d: registers[%2d] = %x, registers[%2d] = %x, registers[%2d] = %x, registers[%2d] = %x, ", cycle_count, i,  registers[i], i+1,  registers[i+1], i+2,  registers[i+2], i+3,  registers[i+3]);
				//$display("@@@@ registers[%2d] = %x, registers[%2d] = %x, registers[%2d] = %x, registers[%2d] = %x, ", i,  registers[i], i+1,  registers[i+1], i+2,  registers[i+2], i+3,  registers[i+3]);
			end
			cycle_count = cycle_count + 1;
		end
	end
	`endif

endmodule // regfile
`endif //__REGFILE_2_V__
