/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_predictor.sv                                     //
//                                                                     //
//  Description :  branch predictor                                    // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __BR_PREDICTOR_V__
`define __BR_PREDICTOR_V__

`timescale 1ns/100ps

`define PHT_SIZE 256
`define BHR_SIZE $clog2(`PHT_SIZE)

module dirp (
    input clock,
    input reset,

    //Branch History
    input branch_result_valid,
    input branch_result, //1 for taken, 0 for not taken
    input [`BHR_SIZE-1:0] ex_idx, //the previous idx to update PHT

    //Branch Prediction
    input is_branch,
    input [`XLEN-1:0] targetPC_in,

    output logic branch_taken,
    output logic [`DIRP_IDX_LEN-1:0] dirp_tag
);
    //Global BHR
    logic [`BHR_SIZE-1:0] BHR_g;

    //Global PHT
    logic [`PHT_SIZE-1:0][1:0] PHT_g, PHT_g_next;
    logic [`BHR_SIZE-1:0] idx;

    assign branch_taken = (~is_branch || PHT_g[dirp_tag] == 2'b00 || PHT_g[dirp_tag] == 2'b01)? 1'b0: 1'b1; 
    assign dirp_tag = (is_branch) ? BHR_g ^ targetPC_in[`BHR_SIZE+1:2] : 5'b0;

    always_comb begin
        PHT_g_next = PHT_g;
        if (branch_result_valid) begin
            case(PHT_g[ex_idx])
            2'b00: begin
                PHT_g_next[ex_idx] = (branch_result) ? 2'b01 : 2'b00;
            end
            2'b01: begin
                PHT_g_next[ex_idx] = (branch_result) ? 2'b10 : 2'b00;
            end
            2'b10: begin
                PHT_g_next[ex_idx] = (branch_result) ? 2'b11 : 2'b01;
            end
            2'b11: begin
                PHT_g_next[ex_idx] = (branch_result) ? 2'b11 : 2'b10;
            end
            endcase
        end

    end                    
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            BHR_g <= `SD 0;
            PHT_g <= `SD '{`PHT_SIZE{2'b01}};
        end else begin
            PHT_g <= `SD PHT_g_next;
            if (branch_result_valid) begin
                BHR_g <= `SD {BHR_g[`BHR_SIZE-2:0],branch_result};
            end
        end
    end

    `ifdef DEBUG
        logic [31:0] cycle_count;
        // synopsys sync_set_reset "reset"
        always_ff @(negedge clock) begin
            if (reset) begin
                cycle_count = 0;
            end else begin
                $display("DEBUG %4d: BHR_g = %b", cycle_count, BHR_g);
                $display("DEBUG %4d: dirp_tag = %b", cycle_count, dirp_tag);
                for (int i = 0; i < `PHT_SIZE; i += 1) begin
                    $display("DEBUG %4d: PHT[%4d]=%b", cycle_count, i, PHT_g[i]);
                end
                cycle_count += 1;
            end  
        end
   `endif

endmodule

`endif
