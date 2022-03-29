// module for rs buffer

// priority:    beq > mult > l&s > alu
// FU_CAT = 4
// NUM_ALU = 8
// NUM_LS = 12
// NUM_MULT = 16
// NUM_BEQ = 20

// seperation 0: 0 2 4 6 9 11 12 14 17 19
// seperation 1: 1 3 5 7 8 10 13 15 16 18

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
    output logic [1:0] count
);
    logic [1:0] next_count;

	always_comb begin
		next_count = count + 3'b01;
	end
    
    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			count <= #1 2'b00;
		else
			count <= #1 next_count;
	end
endmodule

module in_rps2 (
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

module rps2 (
    input        [1:0] req,
    input              en,
    input              cnt,

    output logic [1:0] gnt,
);
    assign gnt[1] = en && (( cnt && req[1]) || (~cnt && ~req[0] &&  req[1]));
    assign gnt[0] = en && ((~cnt && req[0]) || ( cnt && ~req[1] &&  req[0]));
endmodule

module rps4 (
    input        [3:0] req,
    input              en,
    input        [1:0] cnt,

    output logic [3:0] gnt
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;

    in_rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    in_rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    in_rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
endmodule

module fu_selector (
    input                                           clock,
    input                                           reset,

    input                   [`FU_SIZE-1:0]          fu_result_valid,

    output logic            [4:0]                   fu_num_0,
    output logic            [4:0]                   fu_num_1,
    output logic            [`FU_CAT-1:0]           cat_select_0,
    output logic            [`FU_CAT-1:0]           cat_select_1
);

    logic                   [`FU_CAT-1:0]           cat_valid_0;
    logic                   [`FU_CAT-1:0]           cat_valid_1;
    logic                   [(`FU_SIZE/2-1):0]      selection_0;
    logic                   [(`FU_SIZE/2-1):0]      selection_1;

    always_comb begin
        casez (selection_0)
            `HALF_FU_SIZE'b0             : fu_num_0 =  0;
            `HALF_FU_SIZE'b1             : fu_num_0 =  0;
            `HALF_FU_SIZE'b10            : fu_num_0 =  2;
            `HALF_FU_SIZE'b100           : fu_num_0 =  4;
            `HALF_FU_SIZE'b1000          : fu_num_0 =  6;
            `HALF_FU_SIZE'b10000         : fu_num_0 =  9;
            `HALF_FU_SIZE'b100000        : fu_num_0 = 11;
            `HALF_FU_SIZE'b1000000       : fu_num_0 = 12;
            `HALF_FU_SIZE'b10000000      : fu_num_0 = 14;
            `HALF_FU_SIZE'b100000000     : fu_num_0 = 17;
            `HALF_FU_SIZE'b1000000000    : fu_num_0 = 19;
        endcase
    end

    always_comb begin
        casez (selection_1)
            `HALF_FU_SIZE'b0             : fu_num_1 =  1;
            `HALF_FU_SIZE'b1             : fu_num_1 =  1;
            `HALF_FU_SIZE'b10            : fu_num_1 =  3;
            `HALF_FU_SIZE'b100           : fu_num_1 =  5;
            `HALF_FU_SIZE'b1000          : fu_num_1 =  7;
            `HALF_FU_SIZE'b10000         : fu_num_1 =  8;
            `HALF_FU_SIZE'b100000        : fu_num_1 = 10;
            `HALF_FU_SIZE'b1000000       : fu_num_1 = 13;
            `HALF_FU_SIZE'b10000000      : fu_num_1 = 15;
            `HALF_FU_SIZE'b100000000     : fu_num_1 = 16;
            `HALF_FU_SIZE'b1000000000    : fu_num_1 = 18;
        endcase_1
    end

    assign cat_valid_0  = { fu_result_valid[19] == 1'b1 || fu_result_valid[17] == 1'b1,
                            fu_result_valid[14] == 1'b1 || fu_result_valid[12] == 1'b1,
                            fu_result_valid[11] == 1'b1 || fu_result_valid[ 9] == 1'b1,
                            fu_result_valid[ 6] == 1'b1 || fu_result_valid[ 4] == 1'b1 ||
                            fu_result_valid[ 2] == 1'b1 || fu_result_valid[ 0] == 1'b1  };
    assign cat_valid_1  = { fu_result_valid[18] == 1'b1 || fu_result_valid[16] == 1'b1,
                            fu_result_valid[15] == 1'b1 || fu_result_valid[13] == 1'b1,
                            fu_result_valid[10] == 1'b1 || fu_result_valid[ 8] == 1'b1,
                            fu_result_valid[ 7] == 1'b1 || fu_result_valid[ 5] == 1'b1 ||
                            fu_result_valid[ 3] == 1'b1 || fu_result_valid[ 1] == 1'b1  };

    ps4 cat_selector_0 (
        .req(cat_valid_0),
        .gnt(cat_select_0)
    );

    ps4 cat_selector_1 (
        .req(cat_valid_1),
        .gnt(cat_select_1)
    );

    logic [1:0]     cnt;

    counter counter (
        .clock(clock),
        .reset(reset),
        .count(cnt)
    );

    rps4 alu_select_0 (
        .cnt(cnt),
        .req({fu_result_valid[6], fu_result_valid[4], fu_result_valid[2], fu_result_valid[0]}),
        .en(cat_select_0[0]),
        .gnt(selection_0[(`ALU_OFFSET/2-1)  :0])
    );

    rps4 alu_select_1 (
        .cnt(cnt),
        .req({fu_result_valid[7], fu_result_valid[5], fu_result_valid[3], fu_result_valid[1]}),
        .en(cat_select_1[0]),
        .gnt(selection_1[(`ALU_OFFSET/2-1)  :0])
    );

    rps2 ls_select_0 (
        .cnt(cnt[0]),
        .req({fu_result_valid[9], fu_result_valid[11]}),
        .en(cat_select_0[1]),
        .gnt(selection_0[(`LS_OFFSET/2-1)   :`ALU_OFFSET/2])
    );

    rps2 ls_select_1 (
        .cnt(cnt[0]),
        .req({fu_result_valid[8], fu_result_valid[10]}),
        .en(cat_select_1[1]),
        .gnt(selection_1[(`LS_OFFSET/2-1)   :`ALU_OFFSET/2])
    );

    rps2 mult_select_0 (
        .cnt(cnt[0]),
        .req({fu_result_valid[12], fu_result_valid[14]}),
        .en(cat_select_0[1]),
        .gnt(selection_0[(`MULT_OFFSET/2-1) :`LS_OFFSET/2])
    );

    rps2 mult_select_1 (
        .cnt(cnt[0]),
        .req({fu_result_valid[13], fu_result_valid[15]}),
        .en(cat_select_1[1]),
        .gnt(selection_1[(`MULT_OFFSET/2-1) :`LS_OFFSET/2])
    );

    rps2 beq_select_0 (
        .cnt(cnt[0]),
        .req({fu_result_valid[17], fu_result_valid[19]}),
        .en(cat_select_0[1]),
        .gnt(selection_0[(`BEQ_OFFSET/2-1)  :`MULT_OFFSET/2])
    );

    rps2 beq_select_1 (
        .cnt(cnt[0]),
        .req({fu_result_valid[16], fu_result_valid[18]}),
        .en(cat_select_1[1]),
        .gnt(selection_1[(`BEQ_OFFSET/2-1)  :`MULT_OFFSET/2])
    );

endmodule