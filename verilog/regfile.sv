/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  // 
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
`ifndef SS_2

`ifndef __REGFILE_V__
`define __REGFILE_V__

`timescale 1ns/100ps

module regfile(
        input   [4:0] rda_idx, rdb_idx, wr_idx,    // read/write index
        input  [`XLEN-1:0] wr_data,            // write data
        input         wr_en, wr_clk,

        output logic [`XLEN-1:0] rda_out, rdb_out    // read data
        `ifdef DEBUG
        ,input logic reset
        `endif
          
      );
  
  logic    [31:0] [`XLEN-1:0] registers;   // 32, 64-bit Registers

  wire   [`XLEN-1:0] rda_reg = registers[rda_idx];
  wire   [`XLEN-1:0] rdb_reg = registers[rdb_idx];

  //
  // Read port A
  //
  always_comb
    if (rda_idx == `ZERO_REG)
      rda_out = 0;
    else if (wr_en && (wr_idx == rda_idx))
      rda_out = wr_data;  // internal forwarding
    else
      rda_out = rda_reg;

  //
  // Read port B
  //
  always_comb
    if (rdb_idx == `ZERO_REG)
      rdb_out = 0;
    else if (wr_en && (wr_idx == rdb_idx))
      rdb_out = wr_data;  // internal forwarding
    else
      rdb_out = rdb_reg;

  //
  // Write port
  //
  always_ff @(posedge wr_clk)
    if (wr_en) begin
      registers[wr_idx] <= `SD wr_data;
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
`endif //__REGFILE_V__
`endif