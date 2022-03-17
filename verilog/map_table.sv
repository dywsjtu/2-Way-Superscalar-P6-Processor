/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table.sv                                        //
//                                                                     //
//  Description :  map table;                                          // 
/////////////////////////////////////////////////////////////////////////


//`define DEBUG
`ifndef __MAP_TABLE_V__
`define __MAP_TABLE_V__

`timescale 1ns/100ps


module map_table (
        //INPUT
        input logic                             clock,
        input logic                             reset,
        input logic                             dispatch_enable, //from ID
        input logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch, // dest reg idx (from ID)
        //input ID_MT_PACKET                      id_mt, 
        input ROB_MT_PACKET                     rob_mt,
        

        //input logic [`ROB_IDX_LEN:0]            CDB_tag, //rd tag from CDB in complete stage
        input CDB_ENTRY                         cdb_in,
        input RS_MT_PACKET                      rs_mt,

        //input logic [$clog2(`REG_SIZE)-1:0]     rd_retire, // rd idx to clear in retire stage
        //input logic                             clear, //tag-clear signal in retire stage (should sent from ROB?)

         

        //OUTPUT
        output MT_RS_PACKET                     mt_rs
    );

    //6-bit tag: tag = 6'b100000 -> value in reg file
    //MapTable
    logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag ;
    logic [`REG_SIZE-1:0] ready_in_ROB;

    //Avoid multi drive
    //logic [$clog2(`ROB_SIZE+1)-1:0] Tag_next [`REG_SIZE-1:0];
    //logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag_next;
    //logic [`REG_SIZE-1:0] ready_in_ROB_next;
    
    `ifdef DEBUG_1
    always_ff @(negedge clock)
            for(int i = 0; i < `REG_SIZE; i += 1) begin
                // For some reason pretty printing doesn't work if I index directly
                $display("mt_tag[%d] = %d, ", i,  Tag[i]);
            end
    `endif

    // always_comb begin
    //     if (rob_mt.squash) begin
    //         Tag_next = '{`REG_SIZE{`ZERO_TAG}};
    //         ready_in_ROB_next = 0;
    //     end
    //     else begin
    //         Tag_next = Tag;
    //         ready_in_ROB_next = ready_in_ROB;

    //         //clear Tag in retire stage
    //         if (rob_mt.dest_valid) begin
    //             Tag_next[rob_mt.dest_reg_idx] = `ZERO_TAG;
    //             ready_in_ROB_next[rob_mt.dest_reg_idx] = 0;
    //         end

    //         //set ready bit in complete stage
    //         if (cdb_in.valid) begin
    //             for (int i = 0; i < `REG_SIZE; i++)  begin
    //                 if (Tag[i] == CDB_tag) begin
    //                     ready_in_ROB_next[i] = 1'b1;
    //                     //break; 
    //                 end
    //             end
    //         end
    //         //set rd tag in dispatch stage
    //         if (dispatch_enable & rd_dispatch != `ZERO_REG)
    //             begin
    //                 Tag_next[rd_dispatch] = rob_mt.rob_tail;
    //             end
    //         end
    // end

    
    //MapTable output in dispatch
    // assign mt_rs.rs1_tag = Tag_next[rs_mt.rs1_dispatch]; 
    // assign mt_rs.rs2_tag = Tag_next[rs_mt.rs2_dispatch];
    // assign mt_rs.rs1_ready = ready_in_ROB_next[rs_mt.rs1_dispatch];
    // assign mt_rs.rs2_ready = ready_in_ROB_next[rs_mt.rs2_dispatch];

    
    // assign mt_rs.rs_infos[1].tag = Tag_next[rs_mt.register_idxes[1]]; 
    // assign mt_rs.rs_infos[0].tag = Tag_next[rs_mt.register_idxes[0]]; 
    // assign mt_rs.rs_infos[1].ready = ready_in_ROB_next[rs_mt.register_idxes[1]];
    // assign mt_rs.rs_infos[0].ready = ready_in_ROB_next[rs_mt.register_idxes[0]];

    assign mt_rs.rs_infos[1].tag = (rob_mt.dest_valid & rob_mt.dest_reg_idx == rs_mt.register_idxes[1]) ? `ZERO_TAG : 
                                                                                                          Tag[rs_mt.register_idxes[1]];
    assign mt_rs.rs_infos[0].tag = (rob_mt.dest_valid & rob_mt.dest_reg_idx == rs_mt.register_idxes[0]) ? `ZERO_TAG : 
                                                                                                          Tag[rs_mt.register_idxes[0]]
    assign mt_rs.rs_infos[1].ready = (rob_mt.dest_valid & rob_mt.dest_reg_idx == rs_mt.register_idxes[1]) ? 1'b0 :
                                     ((Tag[rs_mt.register_idxes[1]] == cdb_in.tag) & ready_in_ROB[rs_mt.register_idxes[1]]);
    assign mt_rs.rs_infos[0].ready = (rob_mt.dest_valid & rob_mt.dest_reg_idx == rs_mt.register_idxes[0]) ? 1'b0 :
                                     ((Tag[rs_mt.register_idxes[1]] == cdb_in.tag) & ready_in_ROB[rs_mt.register_idxes[0]]);                              
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | rob_mt.squash) begin 
            //All from reg file
            Tag[`REG_SIZE-1:0] <= `SD '{`REG_SIZE{`ZERO_TAG}};
            ready_in_ROB <= `SD 0;
        end
        else begin
            //update Maptable
            // Tag <= `SD Tag_next;
            // ready_in_ROB <= `SD ready_in_ROB_next;
            if (rob_mt.dest_valid) begin
                Tag[rob_mt.dest_reg_idx] = `ZERO_TAG;
                ready_in_ROB[rob_mt.dest_reg_idx] = 0;
            end

            //set ready bit in complete stage
            if (cdb_in.valid) begin
                for (int i = 0; i < `REG_SIZE; i++)  begin
                    if (Tag[i] == CDB_tag) begin
                        ready_in_ROB[i] = 1'b1;
                        //break; 
                    end
                end
            end
            //set rd tag in dispatch stage
            if (dispatch_enable & rd_dispatch != `ZERO_REG)
                begin
                    Tag[rd_dispatch] = rob_mt.rob_tail;
                end
            end
        end
    end

endmodule

`endif // `__MAP_TABLE_V__