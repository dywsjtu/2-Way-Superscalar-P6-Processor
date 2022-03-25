/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  btb.sv                                              //
//                                                                     //
//  Description :  branch target buffer;                               // 
/////////////////////////////////////////////////////////////////////////

`define DEBUG
`ifndef __BTB_V__
`define __BTB_V__

`timescale 1ns/100ps


module btb (
    //INPUT
    input logic                     clock,
    input logic                     reset,

    //Read from BTB
    input logic                     read_en,
    input logic [31:0]              branchPC,

    //Write into BTB
    input logic                     write_en,       
    input logic [31:0]              data_in,
    input logic [31:0]              PC_in,

    //OUTPUT
    output logic [31:0]             targetPC,
    output logic                    hit //if the targetPC is valid
);

    //Inside BTB 2-way associative
    BTB_ENTRY [1:0][`BTB_SIZE-1:0] btb_entries;
    BTB_ENTRY [1:0][`BTB_SIZE-1:0] btb_entries_next;
    
    logic [`BTB_IDX_LEN-1:0] read_idx;
    logic [`BTB_IDX_LEN-1:0] write_idx;
    logic hit_b0, hit_b1;

    //Read from BTB
    assign read_idx = branchPC[`BTB_IDX_LEN+2:3];
    assign hit_b0 =  (btb_entries[0][read_idx].valid && branchPC[31:`BTB_IDX_LEN+3]== btb_entries[0][read_idx].tag);
    assign hit_b1 =  (btb_entries[1][read_idx].valid && branchPC[31:`BTB_IDX_LEN+3]== btb_entries[1][read_idx].tag);

    // assign targetPC = (read_en && hit_b0) ? {branchPC[31:14],btb_entries[0][read_idx].data,2'b0}: 
    //                   (read_en && hit_b1) ? {branchPC[31:14],btb_entries[1][read_idx].data,2'b0}:
    //                   32'b0; 
    assign targetPC = (read_en && hit_b0) ? btb_entries[0][read_idx].data: 
                      (read_en && hit_b1) ? btb_entries[1][read_idx].data:
                      32'b0; 
    assign hit = read_en && (hit_b0 || hit_b1);
              
    assign write_idx = PC_in[`BTB_IDX_LEN+2:3];
    always_comb begin
        //Write new target address into BTB
        btb_entries_next[0] = btb_entries[0];
        btb_entries_next[1] = btb_entries[1];
        if (write_en && 
            ~(PC_in[31:`BTB_IDX_LEN+3]== btb_entries[0][write_idx].tag && data_in == btb_entries[0][write_idx].data) &&
            ~(PC_in[31:`BTB_IDX_LEN+3]== btb_entries[1][write_idx].tag && data_in == btb_entries[1][write_idx].data))
            begin
            if (~btb_entries[0][write_idx].valid) begin //block 0 is empty;
                btb_entries_next[0][write_idx].valid = 1'b1;
                btb_entries_next[0][write_idx].tag = PC_in[31:`BTB_IDX_LEN+3];
                btb_entries_next[0][write_idx].data = data_in;
            end else begin //block 1 is empty or overwrite block 1
                btb_entries_next[1][write_idx].valid = 1'b1;
                btb_entries_next[1][write_idx].tag = PC_in[31:`BTB_IDX_LEN+3];
                btb_entries_next[1][write_idx].data = data_in;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            btb_entries[0] <= `SD 0;
            btb_entries[1] <= `SD 0;
        end
        else begin
            btb_entries[0] <= `SD btb_entries_next[0];
            btb_entries[1] <= `SD btb_entries_next[1];
        end
    end

    `ifdef DEBUG
    logic [31:0] cycle_count;
    always_ff @(negedge clock) begin
        if (reset) begin
            cycle_count = 0;
        end else begin
            for (int i = 0; i < `BTB_SIZE; i+= 1) begin
                $display("DEBUG %4d: b0_tag[%2d] = %x, b0_data[%2d] = %x, b1_tag[%2d] = %x, b1_data[%2d] = %x, ", cycle_count, i,btb_entries[0][i].tag, i, btb_entries[0][i].data,
                                                                                                i, btb_entries[1][i].tag, i, btb_entries[1][i].data);
            end
            $display("DEBUG %4d: hit = %d, hit_b0 = %d, hit_b1 = %d", cycle_count,hit,hit_b0,hit_b1);
            //$display("DEBUG %4d: read_idx = %d", cycle_count, read_idx);
            //$display("DEBUG %4d: branchPC = 0x%x", cycle_count, branchPC);
            cycle_count += 1;
        end
    end
    `endif

endmodule
`endif