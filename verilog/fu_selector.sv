// module for rs buffer

// priority:    beq > mult > l&s > alu
// FU_CAT = 4
// NUM_ALU = 8
// NUM_LS = 12
// NUM_MULT = 16
// NUM_BEQ = 20

module ps2 (
    input        [1:0] req,
    input              en,
    input              cnt,

    output logic [1:0] gnt
);
    assign gnt[1] =  req[1];
    assign gnt[0] = ~req[1] && req[0];
endmodule

module ps4(
    input        [3:0] req,
    output logic [3:0] gnt
);
    assign gnt[3] =  req[3];
    assign gnt[2] = ~req[3] &&  req[2];
    assign gnt[1] = ~req[3] && ~req[2] &&  req[1];
    assign gnt[0] = ~req[3] && ~req[2] && ~req[1] &&  req[0];
endmodule

module counter(
    input              clock,
    input              reset,
    output logic [2:0] count
);
    logic [2:0] next_count;

	always_comb begin
		next_count = count + 3'b01;
	end
    
    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			count <= #1 3'b00;
		else
			count <= #1 next_count;
	end
endmodule

module rps2 (
    input        [1:0] req,
    input              en,
    input              cnt,

    output logic [1:0] gnt,
    output logic       req_up
);
    assign gnt[1] = en && (( cnt && req[1]) || (~cnt && ~req[0] &&  req[1]));
    assign gnt[0] = en && ((~cnt && req[0]) || ( cnt && ~req[1] &&  req[0]));
    assign req_up = req[1] || req[0];
endmodule

module in_rps4 (
    input        [3:0] req,
    input              en,
    input        [1:0] cnt,

    output logic [3:0] gnt,
    output logic       req_up
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;

    rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
endmodule

module rps4 (
    input        [3:0] req,
    input              en,
    input        [1:0] cnt,

    output logic [3:0] gnt
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;

    rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
endmodule

module rps8 (
    input        [7:0] req,
    input              en,
    input        [2:0] cnt,

    output logic [7:0] gnt
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;

    in_rps4 left (req[7:4], en_t[1], cnt[1:0], gnt[7:4], req_up_t[1]);
    in_rps4 right(req[3:0], en_t[0], cnt[1:0], gnt[3:0], req_up_t[0]);
    rps2    top  (req_up_t, en,      cnt[2],   en_t,     req_up);
endmodule

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

        counter counter (
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

        counter counter (
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