// module for rs buffer

// priority:    beq > mult > l&s > alu
// FU_CAT = 4
// NUM_ALU = 8
// NUM_LS = 12
// NUM_MULT = 16
// NUM_BEQ = 20

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
		next_count = count + 2'b01;
	end
    
    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			count <= #1 2'b00;
		else
			count <= #1 next_count;
	end
endmodule

module rps2 (
    input        [1:0] req,
    input              en,
    input              sel,

    output logic [1:0] gnt,
    output logic       req_up
);
    assign gnt[1] = en && (( sel && req[1]) || (~sel && ~req[0] &&  req[1]));
    assign gnt[0] = en && ((~sel && req[0]) || ( sel && ~req[1] &&  req[0]));
    assign req_up = req[1] || req[0];
endmodule

module rps4 (
    input        [1:0] cnt,
    input        [3:0] req,
    input              en,

    output logic [3:0] gnt,
    output logic [1:0] count
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;
    logic       req_up;

    rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
endmodule

module rps8 (
    input        [1:0] cnt,
    input        [7:0] req,
    input              en,

    output logic [7:0] gnt,
    output logic [1:0] count
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;
    logic       req_up;

    rps4 left (req[7:4], en_t[1], cnt[0], gnt[7:4], req_up_t[1]);
    rps4 right(req[3:0], en_t[0], cnt[0], gnt[3:0], req_up_t[0]);
    rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
endmodule

module fu_selector (
    input                                           clock,
    input                                           reset,

    input   FU_RS_PACKET    [`FU_SIZE-1:0]          fu_rs,

    output                  [$clog2(`FU_SIZE):0]    fu_num,
    output                  [`FU_CAT-1:0]           cat_select,
    output  FU_RS_PACKET                            fu_select
);

    logic                   [`FU_CAT-1:0]       cat_valid;
    logic                   [`FU_SIZE-1:0]      selection;

    assign fu_num           = (selection == `FU_SIZE'b0) ? 0 : $clog2(selection);
    assign fu_select        = fu_rs[fu_num];

    always_comb begin
        cat_valid           = `FU_CAT'b0;
        for (int i = 0;             i < `ALU_OFFSET;   i += 1) begin
            if (fu_rs[i].valid) begin
                cat_valid[0]    = 1'b1;
            end
        end
        for (int i = `ALU_OFFSET;   i < `LS_OFFSET;    i += 1) begin
            if (fu_rs[i].valid) begin
                cat_valid[1]    = 1'b1;
            end
        end
        for (int i = `LS_OFFSET;    i < `MULT_OFFSET;  i += 1) begin
            if (fu_rs[i].valid) begin
                cat_valid[2]    = 1'b1;
            end
        end
        for (int i = `MULT_OFFSET;  i < `BEQ_OFFSET;   i += 1) begin
            if (fu_rs[i].valid) begin
                cat_valid[3]    = 1'b1;
            end
        end

    end

    ps4 cat_selector (
        .req(cat_valid),
        .gnt(cat_select)
    );

    `ifdef SMALL_FU_OUT_TEST
        assign selection    = 1'b1;
    `elsif
        logic [1:0]     cnt

        counter cnt (
            .clock(clock),
            .reset(reset),
            .count(cnt)
        );

        rps8 alu_select (
            .cnt(cnt),
            .req({  fu_rs[ 7].valid,
                    fu_rs[ 6].valid,
                    fu_rs[ 5].valid,
                    fu_rs[ 4].valid,
                    fu_rs[ 3].valid,
                    fu_rs[ 2].valid,
                    fu_rs[ 1].valid,
                    fu_rs[ 0].valid  })
            .en(cat_select[0]),
            .gnt(selection[`ALU_OFFSET-1   :0])
        );

        rps4 ls_select (
            .cnt(cnt),
            .req({  fu_rs[11].valid,
                    fu_rs[10].valid,
                    fu_rs[ 9].valid,
                    fu_rs[ 8].valid  })
            .en(cat_select[1]),
            .gnt(selection[`LS_OFFSET-1    :`ALU_OFFSET])
        );

        rps4 mult_select (
            .cnt(cnt),
            .req({  fu_rs[15].valid,
                    fu_rs[14].valid,
                    fu_rs[13].valid,
                    fu_rs[12].valid  })
            .en(cat_select[2]),
            .gnt(selection[`MULT_OFFSET-1  :`LS_OFFSET_OFFSET])
        );

        rps4 beq_select (
            .cnt(cnt),
            .req({  fu_rs[19].valid,
                    fu_rs[18].valid,
                    fu_rs[17].valid,
                    fu_rs[16].valid  })
            .en(cat_select[3]),
            .gnt(selection[`BEQ_OFFSET-1   :`MULT_OFFSET])
        );

    `endif

endmodule