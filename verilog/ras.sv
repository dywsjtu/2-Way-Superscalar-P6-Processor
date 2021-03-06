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

`define RAS_SIZE 8

module ras (
    input clock,
    input reset,
    input squash,
    input is_jump,
    input is_return,
    input [`XLEN-1:0] NPC,

    output logic [`XLEN-1:0] PC_return,
    //output logic ras_full,
    output logic ras_valid
);
    logic [`RAS_SIZE-1:0][13:0] ras_stack;
    logic [13:0]                reg_empty;
    logic [3:0]                 ras_counter;
    logic [2:0]                 tosp, tosp_n;
    logic [13:0]                last_query_pc;
    logic [13:0]                last_out_pc;

    assign ras_valid = is_return && (ras_counter != 0 || reg_empty != 32'b0);
    //assign ras_full = (ras_counter == 3'b100);
    assign PC_return = (is_return && ras_counter != 0)  ? {16'b0, ((last_query_pc == NPC[15:2]) ? last_out_pc : ras_stack[tosp]), 2'b0} :  
                        is_return                       ? {16'b0, reg_empty, 2'b0}  : 
                                                          32'b0;

    //assign reg_empty = ras_stack[tosp];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            ras_stack           <= `SD 0;
            ras_counter         <= `SD 0;
            tosp                <= `SD 0;
            tosp_n              <= `SD 0;
            reg_empty           <= `SD reset ? 32'b0 : reg_empty;
            last_query_pc       <= `SD 0;
            last_out_pc         <= `SD 0;
        end else begin
            last_query_pc       <= `SD NPC[15:2];
            if (last_query_pc != NPC[15:2]) begin
                if (is_jump) begin
                    ras_counter         <= `SD (ras_counter != 4'b1000) ? (ras_counter + 1) : 4'b1000;
                    ras_stack[tosp_n]   <= `SD NPC[15:2];
                    tosp                <= `SD tosp_n;
                    tosp_n              <= `SD tosp_n + 1;
                    reg_empty           <= `SD NPC[15:2];
                end else if (is_return && ras_counter != 4'b0000) begin
                    ras_counter         <= `SD ras_counter - 1;
                    tosp_n              <= `SD tosp;
                    tosp                <= `SD tosp - 1;
                    last_out_pc         <= `SD ras_stack[tosp];
                end
            end
        end
    end

endmodule
`endif