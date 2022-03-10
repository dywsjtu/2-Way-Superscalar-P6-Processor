/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob.sv                                              //
//                                                                     //
//  Description :  reorder buffer;                                     // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module rob(
    input                       clock,
    input                       reset,

    input   ID_ROB_PACKET       id_rob,
    input   RS_ROB_PACKET       rs_rob,
    input   FU_ROB_PACKET       fu_rob,

    output  logic               rob_full,

    output  ROB_RS_PACKET       rob_rs,
    output  ROB_MT_PACKET       rob_mt,
    output  ROB_REG_PACKET      rob_reg

    `ifdef DEBUG
        , output logic      [`ROB_IDX_LEN-1:0]  rob_head
        , output logic      [`ROB_IDX_LEN-1:0]  rob_tail
        , output logic      [`ROB_IDX_LEN-1:0]  rob_counter
        , output ROB_ENTRY  [`ROB_SIZE-1:0]     rob_entries
    `endif
);  
    `ifndef DEBUG
        logic               [`ROB_IDX_LEN-1:0]  rob_head;
        logic               [`ROB_IDX_LEN-1:0]  rob_tail;
        logic               [`ROB_IDX_LEN-1:0]  rob_counter;
        ROB_ENTRY           [`ROB_SIZE-1:0]     rob_entries;
    `endif

    logic       rob_empty;
    logic       retire_valid;
    logic       squash;

    assign rob_empty            = (rob_counter == `ROB_IDX_LEN'b0);
    assign rob_full             = (rob_counter == `ROB_SIZE) & (rob_head == rob_tail);
    assign retire_valid         = (rob_entries[rob_head].ready && (~rob_empty));
    assign squash               = (rob_entries[rob_head].mis_pred && retire_valid);

    assign rob_rs.rob_tail      = rob_tail;
    assign rob_rs.value1        = rob_entries[rs_rob.entry_idx1].value;
    assign rob_rs.value2        = rob_entries[rs_rob.entry_idx2].value;
    assign rob_rs.squash        = squash;

    assign rob_mt.rob_tail      = rob_tail;
    assign rob_mt.squash        = squash;
    
    assign rob_reg.dest_valid   = (retire_valid && (rob_entries[rob_head].dest_reg_idx != `ZERO_REG));
    assign rob_reg.dest_reg_idx = rob_entries[rob_head].dest_reg_idx;
    assign rob_reg.dest_value   = rob_entries[rob_head].value;

    `ifdef DEBUG
    logic cycle_count;
    always_ff @(posedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end
        else begin
            $display("DEBUG %d: rob_empty = %b, retire_valid = %b, squash = %b", cycle_count, rob_empty, retire_valid, squash);
            $display("DEBUG %d: rob_head = %d, rob_tail = %d, rob_counter = %d", cycle_count, rob_head, rob_tail, rob_counter);
            $display("DEBUG %d: rob_head = %d, rob_tail = %p, rob_counter = %d", cycle_count, rob_head, rob_tail, rob_counter);
            // TODO print only 5 for now
            for(int i = 0; i < 5; i += 1) begin
                $display("DEBUG %d: rob_entries[%02d] = %p", cycle_count, i,  rob_entries[i]);
            end
            cycle_count += 1;
        end
    end
    `endif

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_head    <=  `SD `ROB_IDX_LEN'b0;
            rob_tail    <=  `SD `ROB_IDX_LEN'b0;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
        end else if (squash) begin
            rob_head    <=  `SD rob_tail;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
        end else begin
            if (id_rob.dispatch_enable) begin
                // initalize rob entry
                rob_entries[rob_tail].PC                <=  `SD id_rob.PC;
                rob_entries[rob_tail].ready             <=  `SD 1'b0;
                rob_entries[rob_tail].dest_reg_idx      <=  `SD id_rob.dest_reg_idx;
                rob_entries[rob_tail].value             <=  `SD `XLEN'b0;
                rob_entries[rob_tail].mis_pred          <=  `SD 1'b0;
                rob_tail                                <=  `SD (rob_tail == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                            : rob_tail + 1;
            end
            if (retire_valid) begin
                rob_head                                <=  `SD (rob_head == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                            : rob_head + 1;
            end 
            if (fu_rob.completed) begin
                rob_entries[fu_rob.entry_idx].ready     <=  `SD 1'b1;
                rob_entries[fu_rob.entry_idx].value     <=  `SD fu_rob.value;
                rob_entries[fu_rob.entry_idx].mis_pred  <=  `SD fu_rob.mis_pred;
            end
            rob_counter <=  `SD id_rob.dispatch_enable  ? (retire_valid ? rob_counter
                                                                        : rob_counter + 1)
                                                        : (retire_valid ? rob_counter - 1
                                                                        : rob_counter);
        end
    end

endmodule

`endif // `__ROB_V__
