/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  lsq.sv                                              //
//                                                                     //
//  Description :  load store queue;                                   // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __LSQ_V__
`define __LSQ_V__

`timescale 1ns/100ps

module lsq (
    input   logic                           clock,
    input   logic                           reset,
    input   logic                           squash,

    input   RS_LSQ_PACKET                   rs_lsq,
    input   FU_LSQ_PACKET   [`NUM_LS-1:0]   fu_lsq,
    input   ROB_LSQ_PACKET                  rob_lsq,
    // input                                   sq_retire, // from rob

    // output  logic                           sq_rob_valid, // to rob
    output  LSQ_ROB_PACKET                  lsq_rob,
    output  LSQ_FU_PACKET   [`NUM_LS-1:0]   lsq_fu,
    output  LSQ_RS_PACKET                   lsq_rs,

    // connet to memory (dcache)    
    // input                                   store_finish, // from d-cache indicate whether the store finished write
    // input	logic   [`XLEN-1:0] 		    Dmem2proc_data,
    // output	logic   [`XLEN-1:0] 	        Dmem2proc_addr,
    // output	logic   [`XLEN-1:0] 		    proc2Dmem_data,
    // output	logic   [`XLEN-1:0] 	        proc2Dmem_addr
    input   DCACHE_LOAD_LSQ_PACKET          dc_load_lsq,
    input   DCACHE_STORE_LSQ_PACKET         dc_store_lsq,
    output  LSQ_LOAD_DCACHE_PACKET          lsq_load_dc,
    output  LSQ_STORE_DCACHE_PACKET         lsq_store_dc

);  

     
    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]              lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]              lq_retire_valid;
    logic               [`LOAD_QUEUE_SIZE-1:0][`XLEN-1:0]   lq_value;
    // logic               [`LSQ_IDX_LEN-1:0]                  lq_head;
    // logic               [`LSQ_IDX_LEN-1:0]                  lq_tail;
    // logic               [`LSQ_IDX_LEN-1:0]                  lq_counter;

    LOAD_QUEUE_ENTRY    [`LOAD_QUEUE_SIZE-1:0]              next_lq_entries;
    logic               [`LOAD_QUEUE_SIZE-1:0]              next_lq_retire_valid;
    logic               [`LOAD_QUEUE_SIZE-1:0][`XLEN-1:0]   next_lq_value;
    // logic               [`LSQ_IDX_LEN-1:0]                  next_lq_head;
    // logic               [`LSQ_IDX_LEN-1:0]                  next_lq_tail;
    // logic               [`LSQ_IDX_LEN-1:0]                  next_lq_counter;

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

    // LSQ_LOAD_DCACHE_PACKET                                  next_lsq_load_dc;
    // LSQ_STORE_DCACHE_PACKET                                 next_lsq_store_dc;
    LSQ_FU_PACKET       [`NUM_LS-1:0]                       next_lsq_fu;
    logic                                                   next_sq_rob_valid;

    logic                                                   sq_rob_valid;
    assign  lsq_rob.retire_valid    = sq_rob_valid;
    
    // load queue

    logic [1:0]    lq_selection;
    logic [1:0]    next_lq_selection;

    // logic [1:0]     cnt;

    // counter2 counter (
    //     .clock(clock),
    //     .reset(reset),
    //     .count(cnt)
    // );

    // rps4_num lq_selector (
    //     .cnt(cnt),
    //     .req({  lq_entries[3].sq_pos[`LSQ_IDX_LEN-1] && lq_entries[3].valid && ~lq_retire_valid[3],
    //             lq_entries[2].sq_pos[`LSQ_IDX_LEN-1] && lq_entries[2].valid && ~lq_retire_valid[2],
    //             lq_entries[1].sq_pos[`LSQ_IDX_LEN-1] && lq_entries[1].valid && ~lq_retire_valid[1],
    //             lq_entries[0].sq_pos[`LSQ_IDX_LEN-1] && lq_entries[0].valid && ~lq_retire_valid[0]   }),
    //     .en(1'b1),
    //     .num(next_lq_selection)
    // );

    logic   update_selection;
    logic   temp_flag;
    
    always_comb begin
        next_lq_entries         = lq_entries;
        next_lq_retire_valid    = lq_retire_valid;
        next_lq_value           = lq_value;
        // next_lq_head            = lq_head;
        // next_lq_tail            = lq_tail;
        // next_lq_counter         = lq_counter;
        next_lsq_fu             = 0;
        update_selection        = 1'b0;
        next_lq_selection       = lq_selection;

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (rs_lsq.valid && rs_lsq.load && i == rs_lsq.idx) begin
                next_lq_entries[i]          = {`XLEN'b0, 2'b00, 1'b1, 1'b0, (sq_counter == `LSQ_IDX_LEN'b0) ? `NO_SQ_POS : sq_tail};
                next_lq_retire_valid[i]     = 1'b0;
            end else begin
                if (fu_lsq[i].valid && fu_lsq[i].load && lq_entries[i].valid && ~lq_entries[i].filled) begin
                    next_lq_entries[i]      = {fu_lsq[i].addr, fu_lsq[i].mem_size, 1'b1, 1'b1, lq_entries[i].sq_pos};
                    next_lq_retire_valid[i] = 1'b0;
                end
            end
        end

        if (rob_lsq.sq_retire) begin
            for (int i = 0; i < `NUM_LS; i += 1) begin
                if (next_lq_entries[i].sq_pos == sq_head) begin
                    next_lq_entries[i].sq_pos = `NO_SQ_POS;
                end
            end
        end

        temp_flag = 1'b1;
        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (next_lq_entries[i].filled && ~next_lq_retire_valid[i] && 
                next_lq_entries[i].valid && ~(next_lq_entries[i].sq_pos == `NO_SQ_POS)) begin
                if (next_lq_entries[i].sq_pos > sq_head) begin
                    temp_flag = 1'b1;
                    for (int j = `STORE_QUEUE_SIZE - 1; j >= 0; j -= 1) begin
                        if (j < next_lq_entries[i].sq_pos && j >= sq_head && temp_flag) begin
                            if (~sq_valid[j]) begin
                                temp_flag = 1'b0;
                            end else if (sq_entries[j].addr == next_lq_entries[i].addr && sq_entries[j].mem_size == next_lq_entries[i].mem_size) begin
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
                        if (j < next_lq_entries[i].sq_pos && temp_flag) begin
                            if (~sq_valid[j]) begin
                                temp_flag = 1'b0;
                            end else if (sq_entries[j].addr == next_lq_entries[i].addr && sq_entries[j].mem_size == next_lq_entries[i].mem_size) begin
                                temp_flag               = 1'b0;
                                next_lq_retire_valid[i] = 1'b1;
                                next_lq_value[i]        = sq_value[j];
                            end
                        end
                    end
                    for (int j = `STORE_QUEUE_SIZE - 1; j >= 0; j -= 1) begin
                        if (j >= sq_head && temp_flag) begin
                            if (~sq_valid[j]) begin
                                temp_flag = 1'b0;
                            end else if (sq_entries[j].addr == next_lq_entries[i].addr && sq_entries[j].mem_size == next_lq_entries[i].mem_size) begin
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

        if (dc_load_lsq.valid) begin
            next_lq_retire_valid[lq_selection]  = 1'b1;
            next_lq_value[lq_selection]         = dc_load_lsq.value;
            update_selection                    = 1'b1;
        end else if (~(next_lq_entries[lq_selection].sq_pos[`LSQ_IDX_LEN-1] && next_lq_entries[lq_selection].valid && next_lq_entries[lq_selection].filled && ~next_lq_retire_valid[lq_selection])) begin
            update_selection                    = 1'b1;
        end

        if (update_selection) begin
            if          (next_lq_entries[3].sq_pos[`LSQ_IDX_LEN-1] && next_lq_entries[3].valid && next_lq_entries[3].filled && ~next_lq_retire_valid[3]) begin
                next_lq_selection = 2'b11;
            end else if (next_lq_entries[2].sq_pos[`LSQ_IDX_LEN-1] && next_lq_entries[2].valid && next_lq_entries[2].filled && ~next_lq_retire_valid[2]) begin
                next_lq_selection = 2'b10;
            end else if (next_lq_entries[1].sq_pos[`LSQ_IDX_LEN-1] && next_lq_entries[1].valid && next_lq_entries[1].filled && ~next_lq_retire_valid[1]) begin
                next_lq_selection = 2'b01;
            end else if (next_lq_entries[0].sq_pos[`LSQ_IDX_LEN-1] && next_lq_entries[0].valid && next_lq_entries[0].filled && ~next_lq_retire_valid[0]) begin
                next_lq_selection = 2'b00;
            end
        end

        for (int i = 0; i < `LOAD_QUEUE_SIZE; i += 1) begin
            next_lsq_fu[i]  = { next_lq_retire_valid[i],
                                next_lq_value[i]    };
        end
    end

    // always_ff @(posedge clock) begin
    //     if (reset || squash) begin
    //         lq_selection        <=  `SD 0;
    //     end
    //     if (update_selection) begin
    //         lq_selection        <=  `SD next_lq_selection;
    //     end
    // end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || squash) begin
            // lq_head             <= `SD `LSQ_IDX_LEN'b0;
            // lq_tail             <= `SD `LSQ_IDX_LEN'b0;
            lq_selection        <= `SD 2'b00;
            lq_retire_valid     <= `SD `LOAD_QUEUE_SIZE'b0;
            lq_value            <= `SD 0;
            // lq_counter          <= `SD 0;
            lq_entries          <= `SD 0;
            lsq_fu              <= `SD 0;
        end else begin
            // lq_head             <= `SD next_lq_head;
            // lq_tail             <= `SD next_lq_tail;
            lq_selection        <= `SD next_lq_selection;
            lq_retire_valid     <= `SD next_lq_retire_valid;
            lq_value            <= `SD next_lq_value;
            // lq_counter          <= `SD next_lq_counter;
            lq_entries          <= `SD next_lq_entries;
            lsq_fu              <= `SD next_lsq_fu;
        end
    end


    // store queue

    always_comb begin
        next_sq_entries         = sq_entries;
        next_sq_valid           = sq_valid;
        next_sq_value           = sq_value;
        next_sq_head            = sq_head;
        next_sq_tail            = sq_tail;
        next_sq_counter         = sq_counter;
        next_sq_rob_valid       = 1'b0;
        
        if (rs_lsq.valid && rs_lsq.store) begin
            next_sq_tail        = (sq_tail == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_tail + 1;
            next_sq_counter     += 1;
        end

        if (dc_store_lsq.valid) begin
            next_sq_entries[sq_head]    = 0;
            next_sq_head                = (sq_head == `STORE_QUEUE_SIZE - 1) ? `LSQ_IDX_LEN'b0 : sq_head + 1;
            next_sq_counter             -= 1;
            next_sq_valid[sq_head]      = 1'b0;
            next_sq_value[sq_head]      = `XLEN'b0;
            next_sq_rob_valid           = 1'b1;
        end

        for (int i = 0; i < `NUM_LS; i += 1) begin
            if (fu_lsq[i].valid && fu_lsq[i].store && ~sq_entries[fu_lsq[i].sq_pos].filled) begin
                next_sq_entries[fu_lsq[i].sq_pos]   = {fu_lsq[i].addr, fu_lsq[i].mem_size, 1'b1};
                next_sq_valid[fu_lsq[i].sq_pos]     = 1'b1;
                next_sq_value[fu_lsq[i].sq_pos]     = fu_lsq[i].value;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || squash) begin
            sq_head             <=  `SD `LSQ_IDX_LEN'b0;
            sq_tail             <=  `SD `LSQ_IDX_LEN'b0;
            sq_counter          <=  `SD `LSQ_IDX_LEN'b0;
            sq_valid            <=  `SD `STORE_QUEUE_SIZE'b0;
            sq_value            <=  `SD 0;
            sq_entries          <=  `SD 0;
            sq_rob_valid        <=  `SD 1'b0;
        end else begin
            sq_head             <=  `SD next_sq_head;
            sq_tail             <=  `SD next_sq_tail;
            sq_counter          <=  `SD next_sq_counter;
            sq_valid            <=  `SD next_sq_valid;
            sq_value            <=  `SD next_sq_value;
            sq_entries          <=  `SD next_sq_entries;
            sq_rob_valid        <=  `SD next_sq_rob_valid;
        end
    end

    // assign lsq_rs.loadq_tail    =   lq_tail;
    // assign lsq_rs.loadq_full    =   lq_head == lq_tail && lq_counter == `LOAD_QUEUE_SIZE;
    assign lsq_rs.storeq_tail   =   (sq_counter == `LSQ_IDX_LEN'b0) ? `NO_SQ_POS : sq_tail;
    assign lsq_rs.sq_tail       =   sq_tail;
    assign lsq_rs.storeq_full   =   sq_counter == (`STORE_QUEUE_SIZE - 1);

    assign lsq_load_dc  = { lq_entries[lq_selection].sq_pos[`LSQ_IDX_LEN-1] && lq_entries[lq_selection].valid && lq_entries[lq_selection].filled && ~lq_retire_valid[lq_selection],
                            lq_entries[lq_selection].addr,
                            lq_entries[lq_selection].mem_size   };
    assign lsq_store_dc = { sq_valid[sq_head] && rob_lsq.sq_retire && ~lsq_rob.retire_valid,
                            sq_entries[sq_head].addr,
                            sq_entries[sq_head].mem_size,
                            sq_value[sq_head],
                            1'b0 };

    // // synopsys sync_set_reset "reset"
    // always_ff @(posedge clock) begin
    //     if (reset || squash) begin
    //         lsq_load_dc         <=  `SD 0;
    //         lsq_store_dc        <=  `SD 0;
    //     end else begin
    //         lsq_load_dc         <=  `SD next_lsq_load_dc;
    //         lsq_store_dc        <=  `SD next_lsq_store_dc;
    //     end
    // end

endmodule

`endif // __LSQ_V__
