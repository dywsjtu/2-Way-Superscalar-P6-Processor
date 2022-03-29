/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table_2.sv                                      //
//                                                                     //
//  Description :  map table;                                          // 
/////////////////////////////////////////////////////////////////////////


`ifndef __MAP_TABLE_2_V__
`define __MAP_TABLE_2_V__

`timescale 1ns/100ps

module map_table (
    //INPUT
    input logic                             clock,
    input logic                             reset,

    input logic                             dispatch_enable_0, //from ID
    input logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch_0, // dest reg idx (from ID)
    input logic                             dispatch_enable_1, //from ID
    input logic [$clog2(`REG_SIZE)-1:0]     rd_dispatch_1, // dest reg idx (from ID)

    input ROB_MT_PACKET                     rob_mt_0,
    input ROB_MT_PACKET                     rob_mt_1,

    input CDB_ENTRY                         cdb_in_0,
    input CDB_ENTRY                         cdb_in_1,

    input RS_MT_PACKET                      rs_mt_0,
    input RS_MT_PACKET                      rs_mt_1,

    //OUTPUT
    output MT_RS_PACKET                     mt_rs_0,
    output MT_RS_PACKET                     mt_rs_1
);
    //6-bit tag: tag = 6'b100000 -> value in reg file
    //MapTable
    logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag ;
    logic [`REG_SIZE-1:0] ready_in_ROB;

    //Avoid multi drive
    //logic [$clog2(`ROB_SIZE+1)-1:0] Tag_next [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0][`ROB_IDX_LEN:0] Tag_next;
    logic [`REG_SIZE-1:0] ready_in_ROB_next;
    
    logic   rob_mt_0_clear_valid;
    logic   rob_mt_1_clear_valid;

    logic   mt_rs_1_1_match_rob_mt;
    logic   mt_rs_1_0_match_rob_mt;
    logic   mt_rs_0_1_match_rob_mt;
    logic   mt_rs_0_0_match_rob_mt;

    logic   mt_rs_1_1_match_cdb_in;
    logic   mt_rs_1_0_match_cdb_in;
    logic   mt_rs_0_1_match_cdb_in;
    logic   mt_rs_0_0_match_cdb_in;

    assign  rob_mt_0_clear_valid = rob_mt_0.dest_valid && Tag[rob_mt_0.dest_reg_idx] == rob_mt_0.rob_head;
    assign  rob_mt_1_clear_valid = rob_mt_1.dest_valid && Tag[rob_mt_1.dest_reg_idx] == rob_mt_1.rob_head;
    
    assign  mt_rs_1_1_match_rob_mt      =   (rob_mt_0_clear_valid && rob_mt_0.dest_reg_idx == rs_mt_1.register_idxes[1]) ||
                                            (rob_mt_1_clear_valid && rob_mt_1.dest_reg_idx == rs_mt_1.register_idxes[1]);
    assign  mt_rs_1_0_match_rob_mt      =   (rob_mt_0_clear_valid && rob_mt_0.dest_reg_idx == rs_mt_1.register_idxes[0]) ||
                                            (rob_mt_1_clear_valid && rob_mt_1.dest_reg_idx == rs_mt_1.register_idxes[0]);
    assign  mt_rs_0_1_match_rob_mt      =   (rob_mt_0_clear_valid && rob_mt_0.dest_reg_idx == rs_mt_0.register_idxes[1]) ||
                                            (rob_mt_1_clear_valid && rob_mt_1.dest_reg_idx == rs_mt_0.register_idxes[1]);
    assign  mt_rs_0_0_match_rob_mt      =   (rob_mt_0_clear_valid && rob_mt_0.dest_reg_idx == rs_mt_0.register_idxes[0]) ||
                                            (rob_mt_1_clear_valid && rob_mt_1.dest_reg_idx == rs_mt_0.register_idxes[0]);
    
    assign  mt_rs_1_1_match_cdb_in      =   (Tag[rs_mt_1.register_idxes[1]] == cdb_in_0.tag && cdb_in_0.valid) ||
                                            (Tag[rs_mt_1.register_idxes[1]] == cdb_in_1.tag && cdb_in_1.valid);
    assign  mt_rs_1_0_match_cdb_in      =   (Tag[rs_mt_1.register_idxes[0]] == cdb_in_0.tag && cdb_in_0.valid) ||
                                            (Tag[rs_mt_1.register_idxes[0]] == cdb_in_1.tag && cdb_in_1.valid);
    assign  mt_rs_0_1_match_cdb_in      =   (Tag[rs_mt_0.register_idxes[1]] == cdb_in_0.tag && cdb_in_0.valid) ||
                                            (Tag[rs_mt_0.register_idxes[1]] == cdb_in_1.tag && cdb_in_1.valid);
    assign  mt_rs_0_0_match_cdb_in      =   (Tag[rs_mt_0.register_idxes[0]] == cdb_in_0.tag && cdb_in_0.valid) ||
                                            (Tag[rs_mt_0.register_idxes[0]] == cdb_in_1.tag && cdb_in_1.valid);

    assign  mt_rs_1.rs_infos[1].tag   = mt_rs_1_1_match_rob_mt  ?   `ZERO_TAG   :
                                                                    Tag[rs_mt_1.register_idxes[1]];
    assign  mt_rs_1.rs_infos[1].ready = mt_rs_1_1_match_rob_mt  ?   1'b0        :    
                                        mt_rs_1_1_match_cdb_in  ?   1'b1        :
                                                                    ready_in_ROB[rs_mt_1.register_idxes[1]];
    assign  mt_rs_1.rs_infos[0].tag   = mt_rs_1_0_match_rob_mt  ?   `ZERO_TAG   :
                                                                    Tag[rs_mt_1.register_idxes[0]];
    assign  mt_rs_1.rs_infos[0].ready = mt_rs_1_0_match_rob_mt  ?   1'b0        :    
                                        mt_rs_1_0_match_cdb_in  ?   1'b1        :
                                                                    ready_in_ROB[rs_mt_1.register_idxes[0]];
    assign  mt_rs_0.rs_infos[1].tag   = mt_rs_0_1_match_rob_mt  ?   `ZERO_TAG   :
                                                                    Tag[rs_mt_0.register_idxes[1]];
    assign  mt_rs_0.rs_infos[1].ready = mt_rs_0_1_match_rob_mt  ?   1'b0        :    
                                        mt_rs_0_1_match_cdb_in  ?   1'b1        :
                                                                    ready_in_ROB[rs_mt_0.register_idxes[1]];
    assign  mt_rs_0.rs_infos[0].tag   = mt_rs_0_0_match_rob_mt  ?   `ZERO_TAG   :
                                                                    Tag[rs_mt_0.register_idxes[0]];
    assign  mt_rs_0.rs_infos[0].ready = mt_rs_0_0_match_rob_mt  ?   1'b0        :    
                                        mt_rs_0_0_match_cdb_in  ?   1'b1        :
                                                                    ready_in_ROB[rs_mt_0.register_idxes[0]];

    always_comb begin
        if (rob_mt_0.squash || rob_mt_1.squash) begin
            Tag_next          = '{`REG_SIZE{`ZERO_TAG}};
            ready_in_ROB_next = 0;
        end else begin
            Tag_next          = Tag;
            ready_in_ROB_next = ready_in_ROB;

            //clear Tag in retire stage
            if (rob_mt_0_clear_valid) begin
                Tag_next[rob_mt_0.dest_reg_idx]          = `ZERO_TAG;
                ready_in_ROB_next[rob_mt_0.dest_reg_idx] = 0;
            end
            if (rob_mt_1_clear_valid) begin
                Tag_next[rob_mt_1.dest_reg_idx]          = `ZERO_TAG;
                ready_in_ROB_next[rob_mt_1.dest_reg_idx] = 0;
            end

            //set ready bit in complete stage
            if (cdb_in_0.valid) begin
                for (int i = 0; i < `REG_SIZE; i += 1)  begin
                    if (Tag[i] == cdb_in_0.tag) begin
                        ready_in_ROB_next[i] = 1'b1;
                    end
                end
            end
            if (cdb_in_1.valid) begin
                for (int i = 0; i < `REG_SIZE; i += 1)  begin
                    if (Tag[i] == cdb_in_1.tag) begin
                        ready_in_ROB_next[i] = 1'b1;
                    end
                end
            end

            //set rd tag in dispatch stage
            if (dispatch_enable_0 & rd_dispatch_0 != `ZERO_REG) begin
                Tag_next[rd_dispatch_0] = rob_mt_0.rob_tail;
                ready_in_ROB_next[rd_dispatch_0] = 1'b0;
            end
            if (dispatch_enable_1 & rd_dispatch_1 != `ZERO_REG) begin
                Tag_next[rd_dispatch_1] = rob_mt_1.rob_tail;
                ready_in_ROB_next[rd_dispatch_1] = 1'b0;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | rob_mt.squash) begin 
            //All from reg file
            Tag[`REG_SIZE-1:0]  <=  `SD '{`REG_SIZE{`ZERO_TAG}};
            ready_in_ROB        <=  `SD 0;
        end else begin
            //update Maptable
            Tag                 <=  `SD Tag_next;
            ready_in_ROB        <=  `SD ready_in_ROB_next;
        end
    end

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
endmodule

`endif // `__MAP_TABLE_2_V__