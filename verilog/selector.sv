`timescale 1ns/100ps
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

module inv_ps4_num (
    input        [3:0] req,
    output logic [1:0] num
);
    logic [3:0] gnt;
    assign gnt[0] =  req[0];
    assign gnt[1] = ~req[0] &&  req[1];
    assign gnt[2] = ~req[0] && ~req[1] &&  req[2];
    assign gnt[3] = ~req[0] && ~req[1] && ~req[2] &&  req[3];
    assign num[1] = ~req[0] && ~req[1];
    assign num[0] = ~req[0] && ((~req[2] && req[3]) || req[1]);
endmodule

module inv_ps6_num (
    input        [5:0] req,
    output logic [2:0] num
);
    logic [5:0] gnt;
    assign gnt[0] =  req[0];
    assign gnt[1] = ~req[0] &&  req[1];
    assign gnt[2] = ~req[0] && ~req[1] &&  req[2];
    assign gnt[3] = ~req[0] && ~req[1] && ~req[2] &&  req[3];
    assign gnt[4] = ~req[0] && ~req[1] && ~req[2] && ~req[3] &&  req[4];
    assign gnt[5] = ~req[0] && ~req[1] && ~req[2] && ~req[3] && ~req[4] &&  req[5];
    assign num[2] = gnt[5] || gnt[4];
    assign num[1] = gnt[3] || gnt[2];
    assign num[0] = gnt[5] || gnt[3] || gnt[1];
endmodule

module inv_ps7_num (
    input        [6:0] req,
    output logic [2:0] num
);
    logic [6:0] gnt;
    assign gnt[0] =  req[0];
    assign gnt[1] = ~req[0] &&  req[1];
    assign gnt[2] = ~req[0] && ~req[1] &&  req[2];
    assign gnt[3] = ~req[0] && ~req[1] && ~req[2] &&  req[3];
    assign gnt[4] = ~req[0] && ~req[1] && ~req[2] && ~req[3] &&  req[4];
    assign gnt[5] = ~req[0] && ~req[1] && ~req[2] && ~req[3] && ~req[4] &&  req[5];
    assign gnt[6] = ~req[0] && ~req[1] && ~req[2] && ~req[3] && ~req[4] && ~req[5] &&  req[6];
    assign num[2] = gnt[6] || gnt[5] || gnt[4];
    assign num[1] = gnt[6] || gnt[3] || gnt[2];
    assign num[0] = gnt[5] || gnt[3] || gnt[1];
endmodule

module counter2(
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

module counter3(
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

    output logic [1:0] gnt
);
    assign gnt[1] = en && (( cnt && req[1]) || (~cnt && ~req[0] &&  req[1]));
    assign gnt[0] = en && ((~cnt && req[0]) || ( cnt && ~req[1] &&  req[0]));
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

    in_rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    in_rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    in_rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
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

module rps4_num (
    input        [3:0] req,
    input              en,
    input        [1:0] cnt,

    output logic [1:0] num
);
    logic [1:0] req_up_t;
    logic [1:0] en_t;
    logic [3:0] gnt;

    in_rps2 left (req[3:2], en_t[1], cnt[0], gnt[3:2], req_up_t[1]);
    in_rps2 right(req[1:0], en_t[0], cnt[0], gnt[1:0], req_up_t[0]);
    in_rps2 top  (req_up_t, en,      cnt[1], en_t,     req_up);
    assign num[1] = gnt[3] || gnt[2];
    assign num[0] = gnt[3] || gnt[1];
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
    in_rps2 top  (req_up_t, en,      cnt[2],   en_t,     req_up);
endmodule
