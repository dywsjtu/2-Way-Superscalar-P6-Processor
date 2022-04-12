/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_predictor.sv                                     //
//                                                                     //
//  Description :  branch predictor                                    // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __BR_PREDICTOR_HYBRID_V__
`define __BR_PREDICTOR_HYBRID_V__

`timescale 1ns/100ps

`define PHT_SIZE 32
`define BHT_SIZE 32
`define BHR_SIZE $clog2(`PHT_SIZE)

module dirp_hybrid (
    input clock,
    input reset,

    //Branch History
    input branch_result_valid,
    input branch_result, //1 for taken, 0 for not taken
    input [2*`BHR_SIZE+$clog2(`BHT_SIZE)+1:0] ex_idx, //the previous idx to update PHT

    //Branch Prediction
    input is_branch,
    input [`XLEN-1:0] targetPC_in,

    output logic branch_taken,
    output logic [2*`BHR_SIZE+$clog2(`BHT_SIZE)+1:0] dirp_tag
);
    //Local BHT
    //logic [`BHT_SIZE-1:0][`BHR_SIZE-1:0] BHT_p;
    logic [`BHT_SIZE-1:0] PHT_count;
    logic [`BHR_SIZE-1:0] BHR_g, pag_idx, gshare_idx, pag_idx_out, gshare_idx_out, count_idx;
    

    //Global PHT
    logic [`PHT_SIZE-1:0][1:0] PHT_pag, PHT_pag_next, PHT_gshare, PHT_gshare_next;
    

    assign branch_taken = (is_branch && (PHT_count[pag_idx_out] == 2'b00 || PHT_count[pag_idx_out] == 2'b01)) ? (PHT_pag[pag_idx_out] == 2'b10 || PHT_pag[pag_idx_out] == 2'b11 ):
                           is_branch ? (PHT_pag[gshare_idx_out] == 2'b10 || PHT_pag[gshare_idx_out] == 2'b11 ): 1'b0;
    //(~is_branch || PHT_pag[dirp_tag] == 2'b00 || PHT_pag[dirp_tag] == 2'b01)? 1'b0: 1'b1; 
    assign dirp_tag = {targetPC_in[$clog2(`BHT_SIZE)+1:2],gshare_idx_out,pag_idx_out,PHT_gshare[gshare_idx_out],PHT_pag[pag_idx_out]};
    assign pag_idx = ex_idx[`BHR_SIZE+1:2];
    assign gshare_idx = ex_idx[2*`BHR_SIZE+1:`BHR_SIZE+2];
    assign count_idx = ex_idx[2*`BHR_SIZE+$clog2(`BHT_SIZE)+1:2*`BHR_SIZE+2];

    assign pag_idx_out = targetPC_in[`BHR_SIZE+1:2];
    // assign gshare_idx_out = BHR_g ^ targetPC_in[`BHR_SIZE+1:2]; 
    assign gshare_idx_out =  BHR_g;

    //local 
    always_comb begin
        PHT_pag_next = PHT_pag;
        if (branch_result_valid) begin
            case(PHT_pag[pag_idx])
            2'b00: begin
                PHT_pag_next[pag_idx] = (branch_result) ? 2'b01 : 2'b00;
            end
            2'b01: begin
                PHT_pag_next[pag_idx] = (branch_result) ? 2'b10 : 2'b00;
            end
            2'b10: begin
                PHT_pag_next[pag_idx] = (branch_result) ? 2'b11 : 2'b01;
            end
            2'b11: begin
                PHT_pag_next[pag_idx] = (branch_result) ? 2'b11 : 2'b10;
            end
            endcase
        end
    end

    //Global
    always_comb begin
        PHT_gshare_next = PHT_gshare;
        if (branch_result_valid) begin
            case(PHT_pag[gshare_idx])
            2'b00: begin
                PHT_gshare_next[gshare_idx] = (branch_result) ? 2'b01 : 2'b00;
            end
            2'b01: begin
                PHT_gshare_next[gshare_idx] = (branch_result) ? 2'b10 : 2'b00;
            end
            2'b10: begin
                PHT_gshare_next[gshare_idx] = (branch_result) ? 2'b11 : 2'b01;
            end
            2'b11: begin
                PHT_gshare_next[gshare_idx] = (branch_result) ? 2'b11 : 2'b10;
            end
            endcase
        end
    end                     
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            BHR_g <= `SD 0;
            //BHT_p <= `SD '{`BHT_SIZE{4'b0000}};
            PHT_pag <= `SD '{`PHT_SIZE{2'b10}};
            PHT_gshare <= `SD '{`PHT_SIZE{2'b10}};
            PHT_count <= `SD '{`BHT_SIZE{2'b10}};
        end else begin 
            PHT_pag <= `SD PHT_pag_next;
            PHT_gshare <= `SD PHT_gshare_next;
            if (branch_result_valid) begin
                //BHT_p[targetPC_in[$clog2(`BHT_SIZE)+1:2]] <= `SD {BHT_p[targetPC_in[$clog2(`BHT_SIZE)+1:2]][`BHR_SIZE-2:0],branch_result};
                BHR_g <= `SD {BHR_g[`BHR_SIZE-2:0],branch_result};
                PHT_count[count_idx] <= `SD (branch_result == ex_idx[1] && branch_result != ex_idx[0] && PHT_count[count_idx] != 2'b11) ? PHT_count[count_idx]+1 : 
                                          (branch_result != ex_idx[1] && branch_result == ex_idx[0] && PHT_count[count_idx] != 2'b00) ? PHT_count[count_idx]-1 :
                                           PHT_count[count_idx];
            end
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
//                     $display("DEBUG %4d: PHT[%4d]=%b", cycle_count, i, PHT_pag[i]);
//                 end
//                 cycle_count += 1;
//             end  
//         end
//    `endif

endmodule

`endif
