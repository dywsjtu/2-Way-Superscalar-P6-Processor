/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_predictor.sv                                     //
//                                                                     //
//  Description :  branch predictor                                    // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __RAS_V__
`define __RAS_V__

`timescale 1ns/100ps

`define RAS_SIZE 4

module ras (
    input clock,
    input reset,
    input is_jump,
    input is_return,
    input [`XLEN-1:0] NPC,

    output logic [`XLEN-1:0] PC_return,
    output logic ras_full,
    output logic ras_valid
);
    logic [`RAS_SIZE-1:0][`XLEN-1:0] ras_stack;
    logic [`XLEN-1:0]                  reg_used_in_empty;
    logic [2:0] ras_counter;
    logic [1:0] tosp, tosp_n;

    assign ras_valid = is_return && ras_counter != 3'b000;
    assign ras_full = (ras_counter == 3'b100);
    assign PC_return = (is_return) ? ras_stack[tosp] : 32'b0;
    //assign PC_return = (~is_return) ? 32'b0 :
    //                     (ras_counter != 3'b000) ? ras[tosp] : reg_used_in_empty;

 

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            reg_used_in_empty   <= `SD 0;
            ras_stack           <= `SD 0;
            ras_counter         <= `SD 3'b000;
            tosp                <= `SD 2'b00;
        end else begin
            if (is_jump) begin
                ras_stack[tosp_n]   <= `SD NPC;
                ras_counter         <= `SD (ras_counter == 3'b100) ? 3'b100: ras_counter + 1;
                tosp                <= `SD tosp_n;
                tosp_n              <= `SD tosp_n + 1;
            end else if (is_return && ras_counter != 3'b000) begin
                reg_used_in_empty   <= `SD ras_stack[tosp];
                tosp_n              <= `SD tosp;
                tosp                <= `SD tosp-1;
                ras_counter         <= `SD ras_counter - 1;
            end
        end
    end

endmodule
`endif