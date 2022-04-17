/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  btb.sv                                              //
//                                                                     //
//  Description :  branch target buffer;                               // 
/////////////////////////////////////////////////////////////////////////

//`define DEBUG
`ifndef __BTB_2_V__
`define __BTB_2_V__

`timescale 1ns/100ps


module btb_2 (
    //INPUT
    input logic                     clock,
    input logic                     reset,

    //Read from BTB
    input logic                          read_en_0,
    input logic [`XLEN-1:0]              PC_in_r_0,
    input logic                          read_en_1,
    input logic [`XLEN-1:0]              PC_in_r_1,

    //Write into BTB
    input logic                     write_en_0,       
    input logic [31:0]              targetPC_in_0,
    input logic [31:0]              PC_in_w_0,
    input logic                     write_en_1,       
    input logic [31:0]              targetPC_in_1,
    input logic [31:0]              PC_in_w_1,

    //OUTPUT
    output logic [31:0]             targetPC_out_0,
    output logic                    hit_0, //if the targetPC is valid
    output logic [31:0]             targetPC_out_1,
    output logic                    hit_1 //if the targetPC is valid
);
    //Directed mapped
   logic [`BTB_SIZE-1:0][13:0]                  btb_addr;
   logic [`BTB_SIZE-1:0]                        btb_valid;
   logic [`BTB_SIZE-1:0][13-`BTB_IDX_LEN:0]     btb_tags;

   logic [13-`BTB_IDX_LEN:0]     current_tag_r_0, current_tag_w_0;
   logic [`BTB_IDX_LEN-1:0]      current_idx_r_0, current_idx_w_0;   
   logic [13-`BTB_IDX_LEN:0]     current_tag_r_1, current_tag_w_1;
   logic [`BTB_IDX_LEN-1:0]      current_idx_r_1, current_idx_w_1;   
   
   assign {current_tag_r_0,current_idx_r_0} = PC_in_r_0[15:2];
   assign {current_tag_w_0,current_idx_w_0} = PC_in_w_0[15:2];
   assign {current_tag_r_1,current_idx_r_1} = PC_in_r_1[15:2];
   assign {current_tag_w_1,current_idx_w_1} = PC_in_w_1[15:2];

   assign targetPC_out_0 = (read_en_0 && btb_valid[current_idx_r_0] && btb_tags[current_idx_r_0]==current_tag_r_0) ? 
                            {16'b0, btb_addr[current_idx_r_0], 2'b0} : 32'b0;
   assign hit_0 = read_en_0 && btb_valid[current_idx_r_0] && btb_tags[current_idx_r_0]==current_tag_r_0;
   assign targetPC_out_1 = (read_en_1 && btb_valid[current_idx_r_1] && btb_tags[current_idx_r_1]==current_tag_r_1) ? 
                            {16'b0, btb_addr[current_idx_r_1], 2'b0} : 32'b0;
   assign hit_1 = read_en_1 && btb_valid[current_idx_r_1] && btb_tags[current_idx_r_1]==current_tag_r_1;


   // synopsys sync_set_reset "reset"
   always_ff @(posedge clock) begin
       if (reset) begin
           btb_addr     <= `SD 0;
           btb_valid    <= `SD 0;
           btb_tags     <= `SD 0;
       end else begin
           if (write_en_0) begin
               btb_addr[current_idx_w_0]      <= `SD targetPC_in_0[15:2];
               btb_valid[current_idx_w_0]     <= `SD 1'b1;
               btb_tags[current_idx_w_0]      <= `SD current_tag_w_0;
           end
           if (write_en_1 && current_idx_w_1 != current_idx_w_0) begin
               btb_addr[current_idx_w_1]      <= `SD targetPC_in_1[15:2];
               btb_valid[current_idx_w_1]     <= `SD 1'b1;
               btb_tags[current_idx_w_1]      <= `SD current_tag_w_1;
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
                $display("DEBUG %4d: write_en = %b", cycle_count, write_en);
                $display("DEBUG %4d: read_en = %b, PC_in=0x%x, tag = %4d, index = %4d", cycle_count, read_en, PC_in_r, current_tag_r, current_idx_r);
                for (int i = 0; i < `BTB_SIZE; i += 1) begin
                    $display("DEBUG %4d: BTB_tag[%4d]=%d, BTB_addr[%4d]=0x%x, BTB_valid[%4d]=%b", cycle_count, i, btb_tags[i], i, btb_addr[i], i, btb_valid[i]);
                end
                cycle_count += 1;
            end  
        end
   `endif

endmodule
`endif