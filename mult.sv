`ifndef __MULT_SV__
`define __MULT_SV__

module mult #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
				input clock, reset,
				input start,
				input [1:0] sign,
				input [XLEN1:0] mcand, mplier,
				
				output [(2*XLEN)1:0] product,
				output done
			);
	logic [(2*XLEN)1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [NUM_STAGE:0][2*XLEN1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGE:0][2*XLEN1:0] internal_products;
	logic [NUM_STAGE:0] internal_dones;

	assign mcand_in  = sign[0] ? {{XLEN{mcand[XLEN1]}}, mcand}   : {{XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{XLEN{mplier[XLEN1]}}, mplier} : {{XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 'h0;
	assign internal_dones[0]    = start;

	assign done    = internal_dones[NUM_STAGE];
	assign product = internal_products[NUM_STAGE];

	genvar i;
	for (i = 0; i < NUM_STAGE; ++i) begin : mstage
		mult_stage #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) ms (
			.clock(clock),
			.reset(reset),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end
endmodule

module mult_stage #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
					input clock, reset, start,
					input [(2*XLEN)1:0] mplier_in, mcand_in,
					input [(2*XLEN)1:0] product_in,

					output logic done,
					output logic [(2*XLEN)1:0] mplier_out, mcand_out,
					output logic [(2*XLEN)1:0] product_out
				);

	parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*XLEN)1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*XLEN)1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(NUM_BITS1):0] * mcand_in;

	assign next_mplier = {{(NUM_BITS){1'b0}},mplier_in[2*XLEN1:(NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*XLEN1NUM_BITS):0],{(NUM_BITS){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= product_in;
		partial_prod     <= next_partial_product;
		mplier_out       <= next_mplier;
		mcand_out        <= next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done     <= 1'b0;
		end else begin
			done     <= start;
		end
	end

endmodule
`endif //__MULT_SV__
