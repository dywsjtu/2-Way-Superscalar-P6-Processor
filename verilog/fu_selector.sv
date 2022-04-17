// module for rs buffer
`ifndef SS_2
// priority:    beq > mult > l&s > alu
// FU_CAT = 4
// NUM_ALU = 8
// NUM_LS = 12
// NUM_MULT = 16
// NUM_BEQ = 20
`timescale 1ns/100ps
module fu_selector (
    input                                           clock,
    input                                           reset,

    input                   [`FU_SIZE-1:0]          fu_result_valid,

    output logic            [4:0]                   fu_num,
    output logic            [`FU_CAT-1:0]           cat_select
);

    logic                   [`FU_CAT-1:0]       cat_valid;
    logic                   [`FU_SIZE-1:0]      selection;

    //assign fu_num           = (selection == `FU_SIZE'b0) ? 0 : $clog2(selection);
    always_comb begin
        casez (selection)
            `FU_SIZE'b0                         : fu_num = 0;
            `FU_SIZE'b1                         : fu_num = 0;
            `ifdef MEDIUM_FU_OUT_TEST
                `FU_SIZE'b10                    : fu_num = 1;
                `FU_SIZE'b100                   : fu_num = 2;
                `FU_SIZE'b1000                  : fu_num = 3;
            `endif
            `ifdef FULL_FU_OUT_TEST
                `FU_SIZE'b10                    : fu_num = 1;
                `FU_SIZE'b100                   : fu_num = 2;
                `FU_SIZE'b1000                  : fu_num = 3;
                `FU_SIZE'b10000                 : fu_num = 4;
                `FU_SIZE'b100000                : fu_num = 5;
                `FU_SIZE'b1000000               : fu_num = 6;
                `FU_SIZE'b10000000              : fu_num = 7;
                `FU_SIZE'b100000000             : fu_num = 8;
                `FU_SIZE'b1000000000            : fu_num = 9;
                `FU_SIZE'b10000000000           : fu_num = 10;
                `FU_SIZE'b100000000000          : fu_num = 11;
                `FU_SIZE'b1000000000000         : fu_num = 12;
                `FU_SIZE'b10000000000000        : fu_num = 13;
                `FU_SIZE'b100000000000000       : fu_num = 14;
                `FU_SIZE'b1000000000000000      : fu_num = 15;
                `FU_SIZE'b10000000000000000     : fu_num = 16;
                `FU_SIZE'b100000000000000000    : fu_num = 17;
                `FU_SIZE'b1000000000000000000   : fu_num = 18;
                `FU_SIZE'b10000000000000000000  : fu_num = 19;
            `endif
        endcase
    end

    assign  cat_valid[0]    = (fu_result_valid[`ALU_OFFSET-1    :0]             != `NUM_ALU'b0);
    `ifdef SMALL_FU_OUT_TEST
        assign  cat_valid[1]    = 1'b0;
        assign  cat_valid[2]    = 1'b0;
        assign  cat_valid[3]    = 1'b0;
    `else 
        `ifdef MEDIUM_FU_OUT_TEST
            assign  cat_valid[1]    = 1'b0;
            assign  cat_valid[2]    = 1'b0;
            assign  cat_valid[3]    = 1'b0;
        `else 
            assign  cat_valid[1]    = (fu_result_valid[`LS_OFFSET-1     :`ALU_OFFSET]   != `NUM_LS'b0);
            assign  cat_valid[2]    = (fu_result_valid[`MULT_OFFSET-1   :`LS_OFFSET]    != `NUM_MULT'b0);
            assign  cat_valid[3]    = (fu_result_valid[`BEQ_OFFSET-1    :`MULT_OFFSET]  != `NUM_BEQ'b0);
        `endif
    `endif

    ps4 cat_selector (
        .req(cat_valid),
        .gnt(cat_select)
    );

    `ifdef SMALL_FU_OUT_TEST
        assign selection    = 1'b1;
    `endif
    `ifdef MEDIUM_FU_OUT_TEST
        logic [2:0]     cnt;

        counter3 counter (
            .clock(clock),
            .reset(reset),
            .count(cnt)
        );

        rps4 alu_select (
            .cnt(cnt[1:0]),
            .req(fu_result_valid[`ALU_OFFSET-1  :0]),
            .en(cat_select[0]),
            .gnt(selection[`ALU_OFFSET-1  :0])
        );
    `endif
    `ifdef FULL_FU_OUT_TEST
        logic [2:0]     cnt;

        counter3 counter (
            .clock(clock),
            .reset(reset),
            .count(cnt)
        );

        rps8 alu_select (
            .cnt(cnt),
            .req(fu_result_valid[`ALU_OFFSET-1  :0]),
            .en(cat_select[0]),
            .gnt(selection[`ALU_OFFSET-1   :0])
        );

        rps4 ls_select (
            .cnt(cnt[1:0]),
            .req(fu_result_valid[`LS_OFFSET-1   :`ALU_OFFSET]),
            .en(cat_select[1]),
            .gnt(selection[`LS_OFFSET-1    :`ALU_OFFSET])
        );

        rps4 mult_select (
            .cnt(cnt[1:0]),
            .req(fu_result_valid[`MULT_OFFSET-1 :`LS_OFFSET]),
            .en(cat_select[2]),
            .gnt(selection[`MULT_OFFSET-1  :`LS_OFFSET])
        );

        rps4 beq_select (
            .cnt(cnt[1:0]),
            .req(fu_result_valid[`BEQ_OFFSET-1  :`MULT_OFFSET]),
            .en(cat_select[3]),
            .gnt(selection[`BEQ_OFFSET-1   :`MULT_OFFSET])
        );
    `endif

endmodule
`endif