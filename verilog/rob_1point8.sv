/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob.sv                                              //
//                                                                     //
//  Description :  reorder buffer;                                     // 
/////////////////////////////////////////////////////////////////////////


//`define DEBUG
`ifndef __ROB_1point8_V__
`define __ROB_1point8_V__

`timescale 1ns/100ps

module rob_1point8 (
    input                           clock,
    input                           reset,

    input   ID_ROB_PACKET           id_rob,
    input   RS_ROB_PACKET           rs_rob_0,
    input   RS_ROB_PACKET           rs_rob_1,
    input   CDB_ENTRY               cdb_rob_0,
    input   CDB_ENTRY               cdb_rob_1,
    input   LSQ_ROB_PACKET          lsq_rob,
    // input   logic                   sq_rob_valid,

    output  logic                   rob_full,
    output  logic                   halt,
    output  logic                   squash,

    output  ROB_ID_PACKET           rob_id_0,
    output  ROB_ID_PACKET           rob_id_1,
    output  ROB_RS_PACKET           rob_rs_0,
    output  ROB_RS_PACKET           rob_rs_1,
    output  ROB_MT_PACKET           rob_mt_0,
    output  ROB_MT_PACKET           rob_mt_1,
    output  ROB_REG_PACKET          rob_reg_0,
    output  ROB_REG_PACKET          rob_reg_1,
    output  ROB_LSQ_PACKET          rob_lsq,
    output  ROB_ICACHE_PACKET       rob_icache
    // output  logic                   sq_retire
);  
    logic       [`ROB_IDX_LEN-1:0]  rob_head;
    logic       [`ROB_IDX_LEN-1:0]  rob_head_plus_1;
    logic       [`ROB_IDX_LEN-1:0]  rob_tail;
    logic       [`ROB_IDX_LEN-1:0]  rob_tail_plus_1;
    logic       [`ROB_IDX_LEN:0]    rob_counter;
    ROB_ENTRY   [`ROB_SIZE-1:0]     rob_entries;

    logic       [`ROB_IDX_LEN-1:0]  next_rob_head;
    logic       [`ROB_IDX_LEN-1:0]  next_rob_tail;
    logic       [`ROB_IDX_LEN:0]    next_rob_counter;
    ROB_ENTRY   [`ROB_SIZE-1:0]     next_rob_entries;

    logic                           rob_empty;
    logic                           retire_valid_0, retire_valid_1;
    logic                           squash_0, squash_1;
    // logic                           valid_0, valid_1;

    assign rob_empty                = (rob_counter == `ROB_IDX_LEN'b0);
    assign rob_full                 = ((rob_counter == `ROB_SIZE) && (rob_head == rob_tail)) || rob_icache.early_branch_valid;
    assign valid                    = id_rob.dispatch_enable && id_rob.valid;
    assign halt                     = rob_entries[rob_head].halt;

    assign rob_head_plus_1          = (rob_head == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0 : rob_head + 1;
    assign rob_tail_plus_1          = (rob_tail == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0 : rob_tail + 1;

    assign retire_valid_0           = rob_entries[rob_head].ready && (~rob_empty) && 
                                      (~rob_entries[rob_head].store || lsq_rob.retire_valid);
    assign retire_valid_1           = retire_valid_0 && ~squash_0 && ~rob_entries[rob_head].halt &&
                                      rob_entries[rob_head_plus_1].valid && rob_entries[rob_head_plus_1].ready && 
                                      (~rob_entries[rob_head_plus_1].halt) && (~rob_entries[rob_head_plus_1].store);
    
    assign rob_lsq.sq_retire        = rob_entries[rob_head].ready && rob_entries[rob_head].store;

    assign squash_0                 = ((rob_entries[rob_head].mis_pred) || (rob_entries[rob_head].is_branch && rob_entries[rob_head].NPC_out != rob_entries[rob_head].branch_target)) && retire_valid_0;
    assign squash_1                 = ((rob_entries[rob_head_plus_1].mis_pred) || (rob_entries[rob_head_plus_1].is_branch && rob_entries[rob_head_plus_1].NPC_out != rob_entries[rob_head_plus_1].branch_target)) && retire_valid_1;
    assign squash                   = squash_0 || squash_1;

    assign rob_id_0.squash          = squash_0;
    assign rob_id_0.target_pc       = rob_entries[rob_head].branch_target;
    assign rob_id_1.squash          = squash_1;
    assign rob_id_1.target_pc       = rob_entries[rob_head_plus_1].branch_target;
`ifdef BRANCH_MODE
    assign rob_id_0.result_valid    = retire_valid_0;
    assign rob_id_0.branch_taken    = (rob_entries[rob_head].take_branch != rob_entries[rob_head].mis_pred);
    assign rob_id_0.is_branch       = rob_entries[rob_head].is_branch;
    assign rob_id_0.targetPC        = rob_entries[rob_head].branch_target;
    assign rob_id_0.PC              = rob_entries[rob_head].PC;
    assign rob_id_0.dirp_tag        = rob_entries[rob_head].dirp_tag;
    assign rob_id_1.result_valid    = retire_valid_1;
    assign rob_id_1.branch_taken    = (rob_entries[rob_head_plus_1].take_branch != rob_entries[rob_head_plus_1].mis_pred);
    assign rob_id_1.is_branch       = rob_entries[rob_head_plus_1].is_branch;
    assign rob_id_1.targetPC        = rob_entries[rob_head_plus_1].branch_target;
    assign rob_id_1.PC              = rob_entries[rob_head_plus_1].PC;
    assign rob_id_1.dirp_tag        = rob_entries[rob_head_plus_1].dirp_tag;
`endif

    assign rob_rs_0.rob_tail        = rob_tail;
    assign rob_rs_0.value[0]        = rs_rob_0.entry_idx[0] == `ZERO_TAG ? `XLEN'b0 : rob_entries[rs_rob_0.entry_idx[0]].value;
    assign rob_rs_0.value[1]        = rs_rob_0.entry_idx[1] == `ZERO_TAG ? `XLEN'b0 : rob_entries[rs_rob_0.entry_idx[1]].value;
    assign rob_rs_0.squash          = squash;
    assign rob_rs_1.rob_tail        = rob_tail_plus_1;
    assign rob_rs_1.value[0]        = rs_rob_1.entry_idx[0] == `ZERO_TAG ? `XLEN'b0 : rob_entries[rs_rob_1.entry_idx[0]].value;
    assign rob_rs_1.value[1]        = rs_rob_1.entry_idx[1] == `ZERO_TAG ? `XLEN'b0 : rob_entries[rs_rob_1.entry_idx[1]].value;
    assign rob_rs_1.squash          = squash;

    assign rob_mt_0.rob_head        = rob_head;
    assign rob_mt_0.rob_tail        = rob_tail;
    assign rob_mt_0.squash          = squash;
    assign rob_mt_0.dest_valid      = rob_reg_0.dest_valid;
    assign rob_mt_0.dest_reg_idx    = rob_reg_0.dest_reg_idx;

    assign rob_mt_1.rob_head        = rob_head_plus_1;
    assign rob_mt_1.rob_tail        = rob_tail_plus_1;
    assign rob_mt_1.squash          = squash;
    assign rob_mt_1.dest_valid      = rob_reg_1.dest_valid;
    assign rob_mt_1.dest_reg_idx    = rob_reg_1.dest_reg_idx;
    
    assign rob_reg_0.valid          = retire_valid_0 || halt;
    assign rob_reg_0.dest_valid     = rob_reg_0.valid && (rob_entries[rob_head].dest_reg_idx != `ZERO_REG);
    assign rob_reg_0.dest_reg_idx   = rob_entries[rob_head].dest_reg_idx;
    assign rob_reg_0.dest_value     = rob_entries[rob_head].value;
    assign rob_reg_0.OLD_PC_p_4     = rob_entries[rob_head].PC + 4;

    assign rob_reg_1.valid          = retire_valid_1;
    assign rob_reg_1.dest_valid     = rob_reg_1.valid && (rob_entries[rob_head_plus_1].dest_reg_idx != `ZERO_REG);
    assign rob_reg_1.dest_reg_idx   = rob_entries[rob_head_plus_1].dest_reg_idx;
    assign rob_reg_1.dest_value     = rob_entries[rob_head_plus_1].value;
    assign rob_reg_1.OLD_PC_p_4     = rob_entries[rob_head_plus_1].PC + 4;

    always_comb begin
        rob_icache.early_branch_valid = 1'b0;
        if (rob_head < rob_tail) begin
            for (int i = 0; i < `ROB_SIZE; i += 1) begin
                if (~rob_icache.early_branch_valid && i >= rob_head && i < rob_tail &&
                    rob_entries[i].ready && rob_entries[i].mis_pred) begin
                    rob_icache = {1'b1, rob_entries[i].branch_target[15:3]};
                end
            end
        end else if (~rob_empty) begin
            for (int i = 0; i < `ROB_SIZE; i += 1) begin
                if (~rob_icache.early_branch_valid && i >= rob_head &&
                    rob_entries[i].ready && rob_entries[i].mis_pred) begin
                    rob_icache = {1'b1, rob_entries[i].branch_target[15:3]};
                end
            end
            for (int i = 0; i < `ROB_SIZE; i += 1) begin
                if (~rob_icache.early_branch_valid && i < rob_tail &&
                    rob_entries[i].ready && rob_entries[i].mis_pred) begin
                    rob_icache = {1'b1, rob_entries[i].branch_target[15:3]};
                end
            end
        end
    end

    always_comb begin
        next_rob_head = rob_head;
        next_rob_tail = rob_tail;
        next_rob_counter = rob_counter;
        next_rob_entries = rob_entries;

        if (valid) begin
            next_rob_entries[rob_tail].valid            = 1'b1;
            next_rob_entries[rob_tail].NPC_out          = id_rob.NPC_out;
            next_rob_entries[rob_tail].PC               = id_rob.PC;
            next_rob_entries[rob_tail].ready            = 1'b0;
            next_rob_entries[rob_tail].dest_reg_idx     = id_rob.dest_reg_idx;
            next_rob_entries[rob_tail].value            = `XLEN'b0;
            next_rob_entries[rob_tail].store            = id_rob.store;
            next_rob_entries[rob_tail].is_branch        = id_rob.is_branch;
            next_rob_entries[rob_tail].mis_pred         = 1'b0;
            next_rob_entries[rob_tail].branch_target    = `XLEN'b0;
            next_rob_entries[rob_tail].take_branch      = id_rob.take_branch;
            next_rob_entries[rob_tail].halt             = id_rob.halt;
            next_rob_tail                               = (rob_tail == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0 : rob_tail + 1;
            `ifdef BRANCH_MODE
                next_rob_entries[rob_tail].dirp_tag     = id_rob.dirp_tag;
            `endif
            next_rob_counter                            = next_rob_counter + 1;
        end

        if (retire_valid_0) begin
            next_rob_entries[next_rob_head]             = 0;
            next_rob_head                               = (next_rob_head == (`ROB_SIZE - 1)) ? `ROB_IDX_LEN'b0 : next_rob_head + 1;
            next_rob_counter                            = next_rob_counter - 1;
        end
        if (retire_valid_1) begin
            next_rob_entries[next_rob_head]             = 0;
            next_rob_head                               = (next_rob_head == (`ROB_SIZE - 1)) ? `ROB_IDX_LEN'b0 : next_rob_head + 1;
            next_rob_counter                            = next_rob_counter - 1;
        end

        if (cdb_rob_0.valid && rob_entries[cdb_rob_0.tag].valid) begin
            next_rob_entries[cdb_rob_0.tag].ready           = 1'b1;
            next_rob_entries[cdb_rob_0.tag].value           = cdb_rob_0.value;
            next_rob_entries[cdb_rob_0.tag].mis_pred        = ~(next_rob_entries[cdb_rob_0.tag].take_branch == cdb_rob_0.take_branch);
            next_rob_entries[cdb_rob_0.tag].branch_target   = cdb_rob_0.branch_target;
        end

        if (cdb_rob_1.valid && rob_entries[cdb_rob_1.tag].valid) begin
            next_rob_entries[cdb_rob_1.tag].ready           = 1'b1;
            next_rob_entries[cdb_rob_1.tag].value           = cdb_rob_1.value;
            next_rob_entries[cdb_rob_1.tag].mis_pred        = ~(next_rob_entries[cdb_rob_1.tag].take_branch == cdb_rob_1.take_branch);
            next_rob_entries[cdb_rob_1.tag].branch_target   = cdb_rob_1.branch_target;
        end
    end
    
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || squash) begin
            rob_head    <=  `SD `ROB_IDX_LEN'b0;
            rob_tail    <=  `SD `ROB_IDX_LEN'b0;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
            rob_entries <=  `SD 0;
        end else begin
            rob_head    <=  `SD next_rob_head;
            rob_tail    <=  `SD next_rob_tail;
            rob_counter <=  `SD next_rob_counter;
            rob_entries <=  `SD next_rob_entries;
        end
    end

    `ifdef DEBUG
    logic [31:0] cycle_count;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            $display("DEBUG %4d: rob_empty = %b, retire_valid = %b, squash = %b", cycle_count, rob_empty, retire_valid, squash);
            $display("DEBUG %4d: rob_head = %d, rob_tail = %d, rob_counter = %d", cycle_count, rob_head, rob_tail, rob_counter);
            $display("DEBUG %4d: rob_reg = %p", cycle_count, rob_reg);
            $display("DEBUG %4d: rob_full = %d", cycle_count, rob_full);
            // print only 8 for now
            for(int i = 0; i < 8; i += 1) begin
                // For some reason pretty printing doesn't work if I index directly
                ROB_ENTRY rob_entry;
                rob_entry = rob_entries[i];
                $display("DEBUG %4d: rob_entries[%2d] = %p", cycle_count, i,  rob_entry);
            end
            cycle_count += 1;
        end
    end
    `endif
    
endmodule

`endif // `__ROB_1point8_V__
