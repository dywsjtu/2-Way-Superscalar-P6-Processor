/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table.sv                                        //
//                                                                     //
//  Description :  map table;                                          // 
/////////////////////////////////////////////////////////////////////////
`ifndef SS_2

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
    input ROB_MT_PACKET                     rob_mt,
    input CDB_ENTRY                         cdb_in,
    input RS_MT_PACKET                      rs_mt,

    //OUTPUT
    output MT_RS_PACKET                     mt_rs
);

    //6-bit tag: tag = 6'b100000 -> value in reg file
    //MapTable
    logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag ;
    logic [`REG_SIZE-1:0] ready_in_ROB;

    //Avoid multi drive
    //logic [$clog2(`ROB_SIZE+1)-1:0] Tag_next [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag_next;
    logic [`REG_SIZE-1:0] ready_in_ROB_next;
    
    `ifdef DEBUG
    logic [31:0] cycle_count;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `REG_SIZE; i += 2) begin
                $display("DEBUG %4d: mt_tag[%2d] = %d, tag_ready[%2d] = %d, mt_tag[%2d] = %d, tag_ready[%2d] = %d, ", cycle_count, i,  Tag[i], i, ready_in_ROB[i], i+1,  Tag[i+1], i+1, ready_in_ROB[i+1]);
            end
            cycle_count = cycle_count + 1;
        end
       
    end
    `endif

    always_comb begin
        if (rob_mt.squash) begin
            Tag_next = '{`REG_SIZE{`ZERO_TAG}};
            ready_in_ROB_next = 0;
        end
        else begin
            Tag_next = Tag;
            ready_in_ROB_next = ready_in_ROB;

            //clear Tag in retire stage
            if (rob_mt.dest_valid && Tag[rob_mt.dest_reg_idx] == rob_mt.rob_head) begin
                Tag_next[rob_mt.dest_reg_idx] = `ZERO_TAG;
                ready_in_ROB_next[rob_mt.dest_reg_idx] = 0;
            end

            //set ready bit in complete stage
            if (cdb_in.valid) begin
                for (int i = 0; i < `REG_SIZE; i++)  begin
                    if (Tag[i] == cdb_in.tag ) begin
                        ready_in_ROB_next[i] = 1'b1;
                        //break; 
                    end
                end
            end
            //set rd tag in dispatch stage
            if (dispatch_enable & rd_dispatch != `ZERO_REG) begin
                Tag_next[rd_dispatch] = rob_mt.rob_tail;
                ready_in_ROB_next[rd_dispatch] = 1'b0;
            end
        end
    end


    assign mt_rs.rs_infos[1].tag    =   (rob_mt.dest_valid && Tag[rob_mt.dest_reg_idx] == rob_mt.rob_head && rob_mt.dest_reg_idx == rs_mt.register_idxes[1]) ? `ZERO_TAG : 
                                        Tag[rs_mt.register_idxes[1]];
    assign mt_rs.rs_infos[0].tag    =   (rob_mt.dest_valid && Tag[rob_mt.dest_reg_idx] == rob_mt.rob_head && rob_mt.dest_reg_idx == rs_mt.register_idxes[0]) ? `ZERO_TAG : 
                                        Tag[rs_mt.register_idxes[0]];
    assign mt_rs.rs_infos[1].ready  =   (rob_mt.dest_valid && Tag[rob_mt.dest_reg_idx] == rob_mt.rob_head && rob_mt.dest_reg_idx == rs_mt.register_idxes[1]) ? 1'b0 :
                                        (ready_in_ROB[rs_mt.register_idxes[1]]);
    assign mt_rs.rs_infos[0].ready  =   (rob_mt.dest_valid && Tag[rob_mt.dest_reg_idx] == rob_mt.rob_head && rob_mt.dest_reg_idx == rs_mt.register_idxes[0]) ? 1'b0 :
                                        (ready_in_ROB[rs_mt.register_idxes[0]]);                              
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | rob_mt.squash) begin 
            //All from reg file
            Tag[`REG_SIZE-1:0] <= `SD '{`REG_SIZE{`ZERO_TAG}};
            ready_in_ROB <= `SD 0;
        end else begin
            //update Maptable
            Tag <= `SD Tag_next;
            ready_in_ROB <= `SD ready_in_ROB_next;
        end
    end

endmodule

`endif // `__MAP_TABLE_V__
`endif