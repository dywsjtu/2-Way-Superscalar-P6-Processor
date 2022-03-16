/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table.sv                                        //
//                                                                     //
//  Description :  map table;                                          // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __MAP_TABLE_V__
`define __MAP_TABLE_V__

`timescale 1ns/100ps


module map_table (
        //INPUT
        input logic clock,
        input logic reset,

        input logic [ROB_IDX_LEN-1:0] rob_idx, //rd tag from ROB in dispatch stage: start from 1
        input logic [$clog2(`REG_SIZE)-1:0] rd_dispatch, // dest reg idx in dispatch stage

        input logic [ROB_IDX_LEN-1:0] CDB_tag, //rd tag from CDB in complete stage

        input logic [$clog2(`REG_SIZE)-1:0] rs1_dispatch, //rs1 idx request from RS
        input logic [$clog2(`REG_SIZE)-1:0] rs2_dispatch, //rs2 idx request from RS

        input logic [$clog2(`REG_SIZE)-1:0] rd_retire, // rd idx to clear in retire stage
        input logic clear, //tag-clear signal in retire stage

        input logic squash, //for brach or exception 

        //OUTPUT
        output MT_RS_PACKET mt_rs;
    );

    //MapTable
    logic [`ROB_IDX_LEN-1:0] Tag [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0] ready_in_ROB;

    //Avoid multi drive
    logic [`ROB_IDX_LEN-1:0] Tag_next [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0] ready_in_ROB_next;

    always_comb begin
        if (squash) begin
            Tag_next = '{default:32'h0000_0000_0000_0000};
            ready_in_ROB_next = 0;
        end
        else begin
            Tag_next = Tag;
            ready_in_ROB_next = ready_in_ROB;

            //clear Tag in retire stage
            if (clear) begin
                Tag_next[rd_retire] = 0;
                ready_in_ROB_next[rd_retire] = 0;
            end

            //set ready bit in complete stage
            for (int i = 0; i < `REG_SIZE; i++)  begin
                if (Tag[i] == CDB_tag) begin
                    ready_in_ROB_next[i] = 1'b1;
                    //break; 
                end
            end
            //set rd tag in dispatch stage
            Tag_next[rd_dispatch] = rob_idx;
            end
    end

    
    //MapTable output in dispatch
    assign mt_rs.rs_infos[0].tag = Tag_next[rs1_dispatch]; 
    assign mt_rs.rs_infos[1].tag = Tag_next[rs2_dispatch];
    assign mt_rs.rs_infos[0].ready = ready_in_ROB_next[rs1_dispatch];
    assign mt_rs.rs_infos[1].ready = ready_in_ROB_next[rs2_dispatch];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | squash) begin 
            //All from reg file
            Tag <= `SD '{default:32'h0000_0000};
            ready_in_ROB <= `SD 0;
        end
        else begin
            //update Maptable
            Tag <= `SD Tag_next;
            ready_in_ROB <= `SD ready_in_ROB_next;
        end
    end

endmodule

`endif // `__MAP_TABLE_V__