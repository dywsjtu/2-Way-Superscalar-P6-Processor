/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_predictor.sv                                     //
//                                                                     //
//  Description :  branch predictor                                    // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __BR_PREDICTOR_LOCAL_V__
`define __BR_PREDICTOR_LOCAL_V__

`timescale 1ns/100ps


`define BHT_SIZE 32


module dirp_local (
    input clock,
    input reset,

    //Branch History
    input branch_result_valid,
    input branch_result, //1 for taken, 0 for not taken
    input [$clog2(`BHT_SIZE)-1:0] ex_idx, //the previous idx to update PHT

    //Branch Prediction
    input is_branch,
    input [`XLEN-1:0] targetPC_in,

    output logic branch_taken,
    output logic [$clog2(`BHT_SIZE)-1:0] dirp_tag
);
    // //Local BHT
    // logic [`BHT_SIZE-1:0][`BHR_SIZE-1:0] BHT_p;
    

    //Global PHT
    logic [`BHT_SIZE-1:0][1:0] PHT, PHT_next;
    

    assign branch_taken = (~is_branch || PHT[dirp_tag] == 2'b00 || PHT[dirp_tag] == 2'b01)? 1'b0: 1'b1; 
    assign dirp_tag = targetPC_in[$clog2(`BHT_SIZE)+1:2];

    always_comb begin
        PHT_next = PHT;
        if (branch_result_valid) begin
            case(PHT[ex_idx])
            2'b00: begin
                PHT_next[ex_idx] = (branch_result) ? 2'b01 : 2'b00;
            end
            2'b01: begin
                PHT_next[ex_idx] = (branch_result) ? 2'b10 : 2'b00;
            end
            2'b10: begin
                PHT_next[ex_idx] = (branch_result) ? 2'b11 : 2'b01;
            end
            2'b11: begin
                PHT_next[ex_idx] = (branch_result) ? 2'b11 : 2'b10;
            end
            endcase
        end

    end                    
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            //BHT_p <= `SD '{`BHT_SIZE{4'b0000}};
            PHT <= `SD '{`BHT_SIZE{2'b01}};
        end else begin
            PHT <= `SD PHT_next;
        end
    end

//     `ifdef DEBUG
//         logic [31:0] cycle_count;
//         // synopsys sync_set_reset "reset"
//         always_ff @(negedge clock) begin
//             if (reset) begin
//                 cycle_count = 0;
//             end else begin
//                 $display("DEBUG %4d: BHR_g = %b", cycle_count, BHR_g);
//                 $display("DEBUG %4d: dirp_tag = %b", cycle_count, dirp_tag);
//                 for (int i = 0; i < `PHT_SIZE; i += 1) begin
//                     $display("DEBUG %4d: PHT[%4d]=%b", cycle_count, i, PHT[i]);
//                 end
//                 cycle_count += 1;
//             end  
//         end
//    `endif

endmodule

`endif
