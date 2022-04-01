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
    input   logic                           clock,
    input   logic                           reset,
    input   logic                           squash,

    input   RS_LSQ_PACKET                   rs_lsq,
    input   FU_LSQ_PACKET   [`NUM_LS-1:0]   fu_lsq,

    input                                   sq_retire, // from rob

    output  logic                           sq_rob_valid, // to rob
    output  LSQ_FU_PACKET   [`NUM_LS-1:0]   lsq_fu,
    output  LSQ_RS_PACKET                   lsq_rs,

    // connet to memory (dcache)    
    input                                   store_finish, // from d-cache indicate whether the store finished write
    input	logic   [`XLEN-1:0] 		    Dmem2proc_data,
    output	logic   [`XLEN-1:0] 	        Dmem2proc_addr,
    output	logic   [`XLEN-1:0] 		    proc2Dmem_data,
    output	logic   [`XLEN-1:0] 	        proc2Dmem_addr
);  
    // load queue
     
    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]              lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]              lq_retire_valid;
    logic               [`LOAD_QUEUE_SIZE-1:0][`XLEN-1:0]   lq_value;
    logic               [`LSQ_IDX_LEN-1:0]                  lq_head;
    logic               [`LSQ_IDX_LEN-1:0]                  lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]                  lq_counter;

    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]              next_lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]              next_lq_retire_valid;
    logic               [`LOAD_QUEUE_SIZE-1:0][`XLEN-1:0]   next_lq_value;
    logic               [`LSQ_IDX_LEN-1:0]                  next_lq_head;
    logic               [`LSQ_IDX_LEN-1:0]                  next_lq_tail;
    logic               [`LSQ_IDX_LEN-1:0]                  next_lq_counter;


    logic [`LOAD_QUEUE_SIZE-1:0]    lq_selection;

    ps4 lq_selector (
        .req({  lq_entries[3].addr[`LSQ_IDX_LEN-1] && ~lq_retire_valid[3]
                lq_entries[2].addr[`LSQ_IDX_LEN-1] && ~lq_retire_valid[2]
                lq_entries[1].addr[`LSQ_IDX_LEN-1] && ~lq_retire_valid[1]
                lq_entries[0].addr[`LSQ_IDX_LEN-1] && ~lq_retire_valid[0]   }),
        .gnt(lq_selection)
    );


    logic   temp_flag;
    
    always_comb begin
        next_lq_entries         = lq_entries;
        next_lq_retire_valid    = lq_retire_valid;
        next_lq_value           = lq_value;
        next_lq_head            = lq_head;
        next_lq_tail            = lq_tail;
        next_lq_counter         = lq_counter;

        if (rs_lsq.valid && rs_lsq.load) begin
            next_lq_tail    = (lq_tail == `LOAD_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : lq_tail + 1;
            next_lq_counter += 1;
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (fu_lsq[i].valid && fu_lsq[i].load && ~lq_entries[fu_lsq[i].lq_pos].filled) begin
                next_lq_entries[fu_lsq[i].lq_pos] = {fu_lsq[i].addr, 1'b0, 1'b1, fu_lsq[i].sq_pos};
            end
        end

        if (sq_retire) begin
            for (int i = 0; i < `NUM_LS; i += 1) begin
                if (lq_entries[i].sq_pos == sq_head) begin
                    next_lq_entries[i].sq_pos = `NO_SQ_POS;
                end
            end
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (lq_entries[i].filled && ~lq_retire_valid[i] && 
                lq_entries[i].valid && ~(lq_entries[i].sq_pos == `NO_SQ_POS)) begin
                    if (lq_entries[i].sq_pos > sq_head) begin
                        temp_flag = 1'b1;
                        for (int j = `STORE_QUEUE_SIZE - 1; j >= 0; j -= 1) begin
                            if (j < lq_entries[i].sq_pos && j >= sq_head && temp_flag) begin
                                if (~sq_entries[j].valid) begin
                                    temp_flag = 1'b0;
                                end else if (sq_entries[j].addr == lq_entries[i].addr) begin
                                    temp_flag               = 1'b0;
                                    next_lq_retire_valid[i] = 1'b1;
                                    next_lq_value[i]        = sq_value[j];
                                end
                            end
                        end
                        if (temp_flag) begin
                            next_lq_entries[i].sq_pos = `NO_SQ_POS;
                        end
                    end else begin
                        temp_flag = 1'b1;
                        for (int j = `STORE_QUEUE_SIZE - 1; j >= 0; j -= 1) begin
                            if (j < lq_entries[i].sq_pos && temp_flag) begin
                                if (~sq_entries[j].valid) begin
                                    temp_flag = 1'b0;
                                end else if (sq_entries[j].addr == lq_entries[i].addr) begin
                                    temp_flag               = 1'b0;
                                    next_lq_retire_valid[i] = 1'b1;
                                    next_lq_value[i]        = sq_value[j];
                                end
                            end
                        end
                        for (int j = `STORE_QUEUE_SIZE - 1; j >= 0; j -= 1) begin
                            if (j >= sq_head && temp_flag) begin
                                if (~sq_entries[j].valid) begin
                                    temp_flag = 1'b0;
                                end else if (sq_entries[j].addr == lq_entries[i].addr) begin
                                    temp_flag               = 1'b0;
                                    next_lq_retire_valid[i] = 1'b1;
                                    next_lq_value[i]        = sq_value[j];
                                end
                            end
                        end
                        if (temp_flag) begin
                            next_lq_entries[i].sq_pos = `NO_SQ_POS;
                        end
                    end
                end
            end
        end





    end

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            lq_head             <= `SD `LSQ_IDX_LEN'b0;
            lq_tail             <= `SD `LSQ_IDX_LEN'b0;
            lq_retire_valid     <= `SD `LOAD_QUEUE_SIZE'b0;
            lq_value            <= `SD 0;
            lq_counter          <= `SD 0;
            lq_entries          <= `SD 0;
        end else begin
            lq_head             <= `SD next_lq_head;
            lq_tail             <= `SD next_lq_tail;
            lq_retire_valid     <= `SD next_lq_retire_valid;
            lq_value            <= `SD next_lq_value;
            lq_counter          <= `SD next_lq_counter;
            lq_entries          <= `SD next_lq_entries;
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

    assign storeq_fu.valid  = fu_storeq.valid && ~storeq_full;
    assign sq_rob_valid     = sq_retire; // mem_delay_counter; // tell rob sq finish write header to memory

    always_comb begin
        next_sq_entries         = sq_entries;
        next_sq_valid           = sq_valid;
        next_sq_value           = sq_value;
        next_sq_head            = sq_head;
        next_sq_tail            = sq_tail;
        next_sq_counter         = sq_counter;
        
        if (rs_lsq.valid && rs_lsq.store) begin
            next_sq_tail    = (sq_tail == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_tail + 1;
            next_sq_counter += 1;
        end

        if (sq_retire) begin
            proc2Dmem_data              = sq_value[sq_head];
            proc2Dmem_addr              = sq_entries[sq_head].addr;
            next_sq_entries[sq_head]    = 0;
            next_sq_head                = (sq_head == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_head + 1;
            next_sq_counter             -= 1;
            next_sq_valid[sq_head]      = 1'b0;
            next_sq_value[sq_head]      = `XLEN'b0;
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (fu_lsq[i].valid && fu_lsq[i].store && ~sq_entries[fu_lsq[i].sq_pos].filled) begin
                next_sq_entries[fu_lsq[i].sq_pos]   = {fu_lsq[i].addr, 1'b1};
                next_sq_valid[fu_lsq[i].sq_pos]     = 1'b1;
                next_sq_value[fu_lsq[i].sq_pos]     = fu_lsq[i].value;
            end
        end
        

    end

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            sq_head             <=  `SD `LSQ_IDX_LEN'b0;
            sq_tail             <=  `SD `LSQ_IDX_LEN'b0;
            sq_counter          <=  `SD `LSQ_IDX_LEN'b0;
            sq_valid            <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_value            <=  `SD 0;
            sq_entries          <=  `SD 0;
        end else begin
            sq_head             <=  `SD next_sq_head;
            sq_tail             <=  `SD next_sq_tail;
            sq_counter          <=  `SD next_sq_counter;
            sq_valid            <=  `SD next_sq_valid;
            sq_value            <=  `SD next_sq_value;
            sq_entries          <=  `SD next_sq_entries;
        end
    end

    assign lsq_rs.loadq_tail    =   lq_tail;
    assign lsq_rs.loadq_full    =   lq_head == lq_tail && lq_counter == `LOAD_QUEUE_SIZE;
    assign lsq_rs.storeq_tail   =   sq_tail;
    assign lsq_rs.storeq_full   =   sq_counter == `STORE_QUEUE_SIZE && sq_tail == sq_head;


endmodule

`endif // __LSQ_V__