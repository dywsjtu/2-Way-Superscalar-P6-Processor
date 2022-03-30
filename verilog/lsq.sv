/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  lsq.sv                                              //
//                                                                     //
//  Description :  load store queue;                                   // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __LSQ_V__
`define __LSQ_V__

`timescale 1ns/100ps

module load_queue (
    input   logic                       clock,
    input   logic                       reset,
    input   logic                       squash,
    input   RS_LOADQ                    rs_loadq,
    input   FU_LOADQ                    fu_loadq,

    output  logic   [`LSQ_IDX_LEN-1:0]  loadq_tail,
    output  logic                       loadq_full,
    output  LOADQ_FU                    loadq_fu
);
    
    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]      lq_entries;
    logic               [`LSQ_IDX_LEN-1:0]          lq_head;
    logic               [`LSQ_IDX_LEN-1:0]          lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          lq_counter;

    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]      next_lq_entries
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_head;
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_counter;
    
    assign storeq_tail  = lq_tail;
    assign loadq_full   = lq_head == lq_tail && lq_counter == `LOAD_QUEUE_SIZE;
    
    always_comb begin
        next_lq_entries     = lq_entries;
        next_lq_head        = lq_head;
        next_lq_tail        = lq_tail;
        next_lq_counter     = lq_counter;

        if (rs_loadq.valid) begin
            next_lq_tail    = (lq_tail == `LOAD_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : lq_tail + 1;
        end

        if (fu_loadq.valid) begin




        end
    end

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            lq_head     <= `SD `LOAD_QUEUE_SIZE'b0;
            lq_tail     <= `SD `LOAD_QUEUE_SIZE'b0;
            lq_counter  <= `SD 0;
            lq_entries  <= `SD 0;
        end else begin
            lq_head     <= `SD next_lq_head;
            lq_tail     <= `SD next_lq_tail;
            lq_counter  <= `SD next_lq_counter;
            lq_entries  <= `SD next_lq_entries;
        end
    end

endmodule


module store_queue (
    input                               clock,
    input                               reset,
    input                               squash,
    input   RS_STOREQ                   rs_storeq,
    input   FU_STOREQ                   fu_storeq,
    input                               sq_retire,

    output	        [63:0] 			    proc2Dmem_data,
    output	logic   [`XLEN-1:0] 	    proc2Dmem_addr,

    output  logic   [`LSQ_IDX_LEN-1:0]  storeq_tail,
    output  logic                       storeq_full,
    output  STOREQ_FU                   storeq_fu,
    output  logic                       sq_rob_valid
);
    STORE_QUEUE_ENTRY   [`STORE_QUEUE_SIZE-1:0]     sq_entries;
    logic               [`LSQ_IDX_LEN-1:0]          sq_head;
    logic               [`LSQ_IDX_LEN-1:0]          sq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          sq_counter;

    STORE_QUEUE_ENTRY   [`STORE_QUEUE_SIZE-1:0]     next_sq_entries;
    logic               [`LSQ_IDX_LEN-1:0]          next_sq_head;
    logic               [`LSQ_IDX_LEN-1:0]          next_sq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          next_sq_counter;

    assign storeq_tail      = sq_tail;
    assign storeq_full      = sq_counter == `STORE_QUEUE_SIZE;
    assign storeq_fu.valid  = fu_storeq.valid && ~storeq_full;

    always_comb begin
        next_sq_entries     = sq_entries;
        next_sq_head        = sq_head;
        next_sq_tail        = sq_tail;
        next_sq_counter     = sq_counter;

        if (rs_storeq.valid) begin
            next_sq_tail    = (sq_tail == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_tail + 1;
        end

        if (fu_storeq.valid) begin




        end
    end

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            sq_head         <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_tail         <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_counter      <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_entries      <=  `SD 0;
        end else begin
            sq_head         <=  `SD next_sq_head;
            sq_tail         <=  `SD next_sq_tail;
            sq_counter      <=  `SD next_sq_counter;
            sq_entries      <=  `SD next_sq_entries;
        end
    end

endmodule

`endif // __LSQ_V__