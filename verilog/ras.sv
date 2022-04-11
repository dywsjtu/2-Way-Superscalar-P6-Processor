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
    logic [2:0] ras_counter;
    logic [1:0] tosp, tosp_n;

    assign ras_valid = is_return && ras_counter != 3'b000;
    assign ras_full = (ras_counter == 3'b100);
    assign PC_return = (is_return) ? ras_stack[tosp] : 32'b0;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            ras_stack           <= `SD 0;
            ras_counter         <= `SD 3'b000;
            tosp                <= `SD 2'b00;
            tosp_n              <= `SD 2'b00;
        end else begin
            if (is_jump) begin
                if (ras_counter != 3'b100) begin
                    ras_counter         <= `SD ras_counter + 1;
                    ras_stack[tosp_n]   <= `SD NPC;
                    tosp                <= `SD tosp_n;
                    tosp_n              <= `SD tosp + 1;
                end else begin
                    ras_counter         <= `SD 3'b100;
                    ras_stack           <= `SD {ras_stack[`RAS_SIZE-1:1], NPC};
                    tosp                <= `SD 2'b11;
                    tosp_n              <= `SD 2'b11;
                end
            end else if (is_return && ras_counter != 3'b000) begin
                ras_counter         <= `SD ras_counter - 1;
                tosp_n              <= `SD tosp;
                tosp                <= `SD (tosp == 2'b00) ? 2'b00 : (tosp - 1);
            end
        end
    end

endmodule
`endif