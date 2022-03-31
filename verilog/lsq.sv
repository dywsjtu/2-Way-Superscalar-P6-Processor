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

module lsq (
    input   logic                       clock,
    input   logic                       reset,
    input   logic                       squash,
    
    input   RS_LSQ                      rs_lsq,
    input   FU_LSQ  [`NUM_LS-1:0]       fu_lsq,

    input                               sq_retire, // from rob
    input                               store_finish, // from d-cache indicate whether the store finished write

    output  logic   [`LSQ_IDX_LEN-1:0]  loadq_tail,
    output  logic                       loadq_full,
    output  logic   [`LSQ_IDX_LEN-1:0]  storeq_tail,
    output  logic                       storeq_full,
    output  logic                       sq_rob_valid, // to rob

    output  LSQ_FU                      lsq_fu_3,
    output  LSQ_FU                      lsq_fu_2,
    output  LSQ_FU                      lsq_fu_1,
    output  LSQ_FU                      lsq_fu_0,

    // connet to memory (dcache)
    input	logic   [63:0] 			    Dmem2proc_data,
    output	logic   [`XLEN-1:0] 	    Dmem2proc_addr,
    output	logic   [63:0] 			    proc2Dmem_data,
    output	logic   [`XLEN-1:0] 	    proc2Dmem_addr
);
    // load queue
     
    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]      lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]      lq_valid;
    logic               [`LSQ_IDX_LEN-1:0]          lq_head;
    logic               [`LSQ_IDX_LEN-1:0]          lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          lq_counter;

    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]      next_lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]      next_lq_valid;
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_head;
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]          next_lq_counter;
    
    assign loadq_tail  = lq_tail;
    assign loadq_full   = lq_head == lq_tail && lq_counter == `LOAD_QUEUE_SIZE;
    
    always_comb begin
        next_lq_entries     = lq_entries;
        next_lq_valid       = lq_valid;
        next_lq_head        = lq_head;
        next_lq_tail        = lq_tail;
        next_lq_counter     = lq_counter;

        if (rs_lsq.valid && rs_lsq.load) begin
            next_lq_tail    = (lq_tail == `LOAD_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : lq_tail + 1;
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (fu_lsq[i].valid && fu_lsq[i].load && ~lq_entries[fu_lsq[i].lq_pos].filled) begin
                next_lq_entries[fu_lsq[i].lq_pos] = {fu_lsq[i].addr, 1'b1, fu_lsq[i].sq_pos};
            end
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



    // store queue
    STORE_QUEUE_ENTRY   [`STORE_QUEUE_SIZE-1:0]             sq_entries;
    logic               [`STORE_QUEUE_SIZE-1:0]             sq_valid;
    logic               [`STORE_QUEUE_SIZE-1:0][`XLEN-1:0]  sq_value;
    logic               [`LSQ_IDX_LEN-1:0]                  sq_head;
    logic               [`LSQ_IDX_LEN-1:0]                  sq_tail;
    logic               [`LSQ_IDX_LEN-1:0]                  sq_counter;

    STORE_QUEUE_ENTRY   [`STORE_QUEUE_SIZE-1:0]             next_sq_entries;
    logic               [`STORE_QUEUE_SIZE-1:0]             next_sq_valid;
    logic               [`STORE_QUEUE_SIZE-1:0][`XLEN-1:0]  next_sq_value;
    logic               [`LSQ_IDX_LEN-1:0]                  next_sq_head;
    logic               [`LSQ_IDX_LEN-1:0]                  next_sq_tail;
    logic               [`LSQ_IDX_LEN-1:0]                  next_sq_counter;

    assign storeq_tail      = sq_tail;
    assign storeq_full      = sq_counter == `STORE_QUEUE_SIZE;
    assign storeq_fu.valid  = fu_storeq.valid && ~storeq_full;
    assign sq_rob_valid     = mem_delay_counter;

    always_comb begin
        next_sq_entries         = sq_entries;
        next_sq_valid           = sq_valid;
        next_sq_value           = sq_value;
        next_sq_head            = sq_head;
        next_sq_tail            = sq_tail;
        next_sq_counter         = sq_counter;
        
        if (rs_lsq.valid && rs_lsq.store) begin
            next_sq_tail    = (sq_tail == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_tail + 1;
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (fu_lsq[i].valid && fu_lsq[i].store && ~sq_entries[fu_lsq[i].sq_pos].filled) begin
                next_sq_entries[fu_lsq[i].sq_pos] = {fu_lsq[i].addr, 1'b1};
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            sq_head             <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_tail             <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_counter          <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_entries          <=  `SD 0;
        end else begin
            sq_head             <=  `SD next_sq_head;
            sq_tail             <=  `SD next_sq_tail;
            sq_counter          <=  `SD next_sq_counter;
            sq_entries          <=  `SD next_sq_entries;
        end
    end







endmodule

`endif // __LSQ_V__