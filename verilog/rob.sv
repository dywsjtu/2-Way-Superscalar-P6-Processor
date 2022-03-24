/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob.sv                                              //
//                                                                     //
//  Description :  reorder buffer;                                     // 
/////////////////////////////////////////////////////////////////////////


//`define DEBUG
`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module rob(
    input                       clock,
    input                       reset,

    input   ID_ROB_PACKET       id_rob,
    input   RS_ROB_PACKET       rs_rob,
    input   CDB_ENTRY           cdb_rob,

    output  logic               rob_full,
    output  logic               halt,

    output  ROB_ID_PACKET       rob_id,
    output  ROB_RS_PACKET       rob_rs,
    output  ROB_MT_PACKET       rob_mt,
    output  ROB_REG_PACKET      rob_reg
    
    // `ifdef DEBUG
    //     , output logic      [`ROB_IDX_LEN-1:0]  rob_head
    //     , output logic      [`ROB_IDX_LEN-1:0]  rob_tail
    //     , output logic      [`ROB_IDX_LEN:0]    rob_counter
    //     , output ROB_ENTRY  [`ROB_SIZE-1:0]     rob_entries
    // `endif
);  
    logic               [`ROB_IDX_LEN-1:0]  rob_head;
    logic               [`ROB_IDX_LEN-1:0]  rob_tail;
    logic               [`ROB_IDX_LEN:0]    rob_counter;
    ROB_ENTRY           [`ROB_SIZE-1:0]     rob_entries;

    logic       rob_empty;
    logic       retire_valid;
    logic       squash;
    logic       valid;

    assign halt                 = rob_entries[rob_head].halt;

    assign rob_empty            = (rob_counter == `ROB_IDX_LEN'b0);
    assign rob_full             = (rob_counter == `ROB_SIZE) && (rob_head == rob_tail);
    assign retire_valid         = (rob_entries[rob_head].ready && (~rob_empty)) || rob_entries[rob_head].halt;
    assign squash               = (rob_entries[rob_head].mis_pred && retire_valid);
    assign valid                = id_rob.dispatch_enable && id_rob.valid;

    assign rob_id.squash        = squash;
    // rob_entries[rob_head].take_branch stores whether the dispatch use the unusual target pc.
    // i.e. when take_branch is true, dispatch didn't use PC+4
    // rob_id.target_pc store the correct PC if the branch prediction is wrong
    assign rob_id.target_pc     = rob_entries[rob_head].take_branch ? (rob_entries[rob_head].PC + 4)
                                                                    : rob_entries[rob_head].value;    

    assign rob_rs.rob_tail      = rob_tail;
    assign rob_rs.value[0]      = rs_rob.entry_idx[0] == `ZERO_TAG  ? `XLEN'b0 
                                                                    : rob_entries[rs_rob.entry_idx[0]].value;
    assign rob_rs.value[1]      = rs_rob.entry_idx[1] == `ZERO_TAG  ? `XLEN'b0 
                                                                    : rob_entries[rs_rob.entry_idx[1]].value;
    assign rob_rs.squash        = squash;

    assign rob_mt.rob_head      = rob_head;
    assign rob_mt.rob_tail      = rob_tail;
    assign rob_mt.squash        = squash;
    assign rob_mt.dest_valid    = rob_reg.dest_valid;
    assign rob_mt.dest_reg_idx  = rob_reg.dest_reg_idx;
    
    assign rob_reg.valid        = retire_valid;
    assign rob_reg.dest_valid   = (retire_valid && (rob_entries[rob_head].dest_reg_idx != `ZERO_REG));
    assign rob_reg.dest_reg_idx = rob_entries[rob_head].dest_reg_idx;
    assign rob_reg.dest_value   = rob_entries[rob_head].value;
    assign rob_reg.OLD_PC_p_4   = rob_entries[rob_head].PC + 4;
    

    `ifdef DEBUG
    logic [31:0] cycle_count;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end
        else begin
            $display("DEBUG %4d: rob_empty = %b, retire_valid = %b, squash = %b", cycle_count, rob_empty, retire_valid, squash);
            $display("DEBUG %4d: rob_head = %d, rob_tail = %d, rob_counter = %d", cycle_count, rob_head, rob_tail, rob_counter);
            $display("DEBUG %4d: rob_reg = %p", cycle_count, rob_reg);
            $display("DEBUG %4d: rob_full = %d", cycle_count, rob_full);
            // TODO print only 8 for now
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
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || squash) begin
            rob_head    <=  `SD `ROB_IDX_LEN'b0;
            rob_tail    <=  `SD `ROB_IDX_LEN'b0;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
            rob_entries <=  `SD 0;
        // end else if (squash) begin
        //     rob_head    <=  `SD rob_tail;
        //     rob_counter <=  `SD `ROB_IDX_LEN'b0;
        end else begin
            if (valid) begin
                // initalize rob entry
                rob_entries[rob_tail].valid             <=  `SD 1'b1;
                rob_entries[rob_tail].PC                <=  `SD id_rob.PC;
                rob_entries[rob_tail].ready             <=  `SD 1'b0;
                rob_entries[rob_tail].dest_reg_idx      <=  `SD id_rob.dest_reg_idx;
                rob_entries[rob_tail].value             <=  `SD `XLEN'b0;
                rob_entries[rob_tail].mis_pred          <=  `SD 1'b0;
                rob_entries[rob_tail].take_branch       <=  `SD id_rob.take_branch;
                rob_entries[rob_tail].halt              <=  `SD id_rob.halt;
                rob_tail                                <=  `SD (rob_tail == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                            : rob_tail + 1;
                // rob_tail                                <=  `SD rob_tail + 1;
            end
            if (retire_valid) begin
                rob_entries[rob_head]                   <=  `SD 0;
                rob_head                                <=  `SD (rob_head == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                            : rob_head + 1;
                // rob_head                                <=  `SD rob_head + 1;
            end 
            // if (fu_rob.completed && rob_entries[fu_rob.entry_idx].valid) begin
            //     rob_entries[fu_rob.entry_idx].ready     <=  `SD 1'b1;
            //     rob_entries[fu_rob.entry_idx].value     <=  `SD fu_rob.value;
            //     rob_entries[fu_rob.entry_idx].mis_pred  <=  `SD fu_rob.mis_pred;
            // end
            if (cdb_rob.valid && rob_entries[cdb_rob.tag].valid) begin
                rob_entries[cdb_rob.tag].ready          <=  `SD 1'b1;
                rob_entries[cdb_rob.tag].value          <=  `SD cdb_rob.value;
                rob_entries[cdb_rob.tag].mis_pred       <=  `SD ~(rob_entries[cdb_rob.tag].take_branch == cdb_rob.take_branch);
            end
            rob_counter <=  `SD valid   ? (retire_valid ?  rob_counter
                                                        : (rob_counter + 1))
                                        : (retire_valid ? (rob_counter - 1)
                                                        :  rob_counter);
        end
    end

endmodule

`endif // `__ROB_V__
