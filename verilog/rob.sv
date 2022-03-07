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
    input                               clock,
    input                               reset,
    input [`XLEN-1:0]                   PC,
    input                               dispatch_enable,            // whether is ready to dispatch
    input                               complete_enable,            // whether value is ready && cdb is not full
    input [`ROB_IDX_LEN:0]              complete_rob_entry,         // which entry is ready
    input [4:0]                         dest_reg_idx,
    input [`XLEN-1:0]                   value,                      // value to cdb and rob entry
    input                               wrong_pred,                 
    input [`ROB_IDX_LEN:0]              reqire_entry_idx,           // query rob entry from reservation station
    
    output logic                        rob_full,
    output logic                        squash_at_head,             // head is branch instruction and mis predicted
    output logic                        dest_valid,                 
    output logic [4:0]                  dest_reg,                   // store value in the dest_reg
    output logic [`ROB_IDX_LEN:0]       dest_value,                 // value to store in the dest_reg
    output logic [`ROB_IDX_LEN:0]       required_value              // query value from reservation station

    `ifdef DEBUG
        , output logic      [`ROB_IDX_LEN:0]    rob_head
        , output logic      [`ROB_IDX_LEN:0]    rob_tail
        , output logic      [`ROB_IDX_LEN:0]    rob_counter;
        , output logic                          rob_empty
        , output logic                          retire_valid;
        , output ROB_ENTRY  [`ROB_SIZE-1:0]     rob_entries
    `endif

);
    `ifndef DEBUG
        logic       [`ROB_IDX_LEN:0]    rob_head;
        logic       [`ROB_IDX_LEN:0]    rob_tail;
        logic       [`ROB_IDX_LEN:0]    rob_counter;
        logic                           rob_empty;
        logic                           retire_valid;
        ROB_ENTRY   [`ROB_SIZE-1:0]     rob_entries;
    `endif

    assign rob_empty        = (rob_counter == `ROB_IDX_LEN'b0);
    assign rob_full         = (rob_counter == `ROB_ENTRY) & (rob_head == rob_tail);
    assign retire_valid     = (rob_entries[rob_head].ready && (~rob_empty));
    assign squash_at_head   = (rob_entries[rob_head].mis_pred && retire_valid);
    assign required_value   = rob_entries[require_entry_idx].value;
    assign dest_reg         = rob_entries[rob_head].dest_reg_idx;
    assign dest_valid       = (retire_valid && (dest_reg != `ZERO_REG));
    assign dest_value       = rob_entries[rob_head].value;

    always_ff (@posedge clock) begin
        if (reset) begin
            rob_head    <=  `SD `ROB_IDX_LEN'b0;
            rob_tail    <=  `SD `ROB_IDX_LEN'b0;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
        end else if (squash_at_head) begin
            rob_head    <=  `SD rob_tail;
            rob_counter <=  `SD `ROB_IDX_LEN'b0;
        end else begin
            if (dispatch_enable) begin
                // initalize rob entry
                rob_entries[rob_tail].PC            <=  `SD PC;
                rob_entries[rob_tail].ready         <=  `SD 1'b0;
                rob_entries[rob_tail].dest_reg_idx  <=  `SD dest_reg_idx;
                rob_entries[rob_tail].value         <=  `SD `XLEN'b0;
                rob_entries[rob_tail].mis_pred      <=  `SD 1'b0;
                rob_tail                            <=  `SD (rob_tail == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                        : rob_tail + 1;
            end
            if (retire_valid) begin
                rob_head                            <=  `SD (rob_head == `ROB_SIZE - 1) ? `ROB_IDX_LEN'b0
                                                                                        : rob_head + 1;
            end
            if (complete_enable) begin
                rob_entries[complete_rob_entry].ready       <=  `SD 1'b1;
                rob_entries[complete_rob_entry].value       <=  `SD value;
                rob_entries[complete_rob_entry].mis_pred    <=  `SD wrong_pred;
            end
            rob_counter <=  `SD dispatch_enable ? (retire_valid ? rob_counter
                                                                : rob_counter + 1)
                                                : (retire_valid ? rob_counter - 1
                                                                : rob_counter);
        end
    end

endmodule

`endif // `__ROB_V__