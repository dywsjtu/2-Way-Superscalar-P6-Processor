/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  btb.sv                                              //
//                                                                     //
//  Description :  branch target buffer;                               // 
/////////////////////////////////////////////////////////////////////////
`ifndef SS_2
//`define DEBUG
`ifndef __BTB_1POINT2_V__
`define __BTB_1POINT2_V__

`timescale 1ns/100ps


module btb_1point2 (
    //INPUT
    input logic                     clock,
    input logic                     reset,

    //Read from BTB
    input logic                          read_en,
    input logic [`XLEN-1:0]              PC_in_r,


    //Write into BTB
    input logic                     write_en_0,       
    input logic [31:0]              targetPC_in_0,
    input logic [31:0]              PC_in_w_0,
    input logic                     write_en_1,       
    input logic [31:0]              targetPC_in_1,
    input logic [31:0]              PC_in_w_1,

    //OUTPUT
    output logic [31:0]             targetPC_out,
    output logic                    hit
);
    //Directed mapped
   logic [`BTB_SIZE-1:0][`XLEN-1:0]             btb_addr;
   logic [`BTB_SIZE-1:0]                        btb_valid;
   logic [`BTB_SIZE-1:0][13-`BTB_IDX_LEN:0]     btb_tags;

   logic [13-`BTB_IDX_LEN:0]     current_tag_r, current_tag_w_0, current_tag_w_1;
   logic [`BTB_IDX_LEN-1:0]      current_idx_r, current_idx_w_0, current_idx_w_1;   

   
   assign {current_tag_r,current_idx_r} = PC_in_r[15:2];
   assign {current_tag_w_0,current_idx_w_0} = PC_in_w_0[15:2];
   assign {current_tag_w_1,current_idx_w_1} = PC_in_w_1[15:2];

   assign targetPC_out = (read_en && btb_valid[current_idx_r] && btb_tags[current_idx_r]==current_tag_r) ? 
                            btb_addr[current_idx_r] : 32'b0;
   assign hit = read_en && btb_valid[current_idx_r] && btb_tags[current_idx_r]==current_tag_r;
   


   // synopsys sync_set_reset "reset"
   always_ff @(posedge clock) begin
       if (reset) begin
           btb_addr     <= `SD 0;
           btb_valid    <= `SD 0;
           btb_tags     <= `SD 0;
       end else begin
           if (write_en_0) begin
               btb_addr[current_idx_w_0]      <= `SD targetPC_in_0;
               btb_valid[current_idx_w_0]     <= `SD 1'b1;
               btb_tags[current_idx_w_0]      <= `SD current_tag_w_0;
           end
           if (write_en_1 && current_idx_w_1 != current_idx_w_0) begin
               btb_addr[current_idx_w_1]      <= `SD targetPC_in_1;
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
`endif