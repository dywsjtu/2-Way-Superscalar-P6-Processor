/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs.sv                                               //
//                                                                     //
//  Description :  reservation station;                                // 
/////////////////////////////////////////////////////////////////////////


//`define DEBUG
`ifndef __RS_2_V__
`define __RS_2_V__

`timescale 1ns/100ps

module rs_2 (
    input                                   clock,
    input                                   reset,

    input   ID_RS_PACKET                    id_rs_0,
    input   ID_RS_PACKET                    id_rs_1,
    input   MT_RS_PACKET                    mt_rs_0,
    input   MT_RS_PACKET                    mt_rs_1,
    input   REG_RS_PACKET                   reg_rs_0,
    input   REG_RS_PACKET                   reg_rs_1,
    input   CDB_ENTRY                       cdb_rs_0,
    input   CDB_ENTRY                       cdb_rs_1,
    input   ROB_RS_PACKET                   rob_rs_0,
    input   ROB_RS_PACKET                   rob_rs_1,
    input   LSQ_RS_PACKET                   lsq_rs,
    input   LSQ_FU_PACKET   [`NUM_LS-1:0]   lsq_fu,

    output  FU_ID_PACKET                    fu_id_0,
    output  FU_ID_PACKET                    fu_id_1,    
    output  RS_MT_PACKET                    rs_mt_0,
    output  RS_MT_PACKET                    rs_mt_1,
    output  CDB_ENTRY                       rs_cdb_0,
    output  CDB_ENTRY                       rs_cdb_1,
    output  RS_REG_PACKET                   rs_reg_0,
    output  RS_REG_PACKET                   rs_reg_1,
    output  RS_ROB_PACKET                   rs_rob_0,
    output  RS_ROB_PACKET                   rs_rob_1,
    output  logic                           rs_entry_full_0,
    output  logic                           rs_entry_full_1,
    output  RS_LSQ_PACKET                   rs_lsq,
    output  FU_LSQ_PACKET   [`NUM_LS-1:0]   fu_lsq
);  

    RS_ENTRY        [`FU_SIZE-1:0]          rs_entries;
    RS_ENTRY        [`FU_SIZE-1:0]          next_rs_entries;

    logic           [`FU_SIZE-1:0]          busy;
    logic           [`FU_SIZE-1:0]          next_busy;

    RS_FU_PACKET    [`FU_SIZE-1:0]          rs_fu;
    FU_RS_PACKET    [`FU_SIZE-1:0]          fu_rs;
    logic           [`FU_SIZE-1:0]          fu_result_valid;

    logic           [4:0]                   fu_num_0;
    logic           [4:0]                   fu_num_1;
    logic           [`FU_CAT-1:0]           cat_select_0;
    logic           [`FU_CAT-1:0]           cat_select_1;

    logic           [`FU_SIZE-1:0]          fu_valid;

    
    logic           [4:0]                   fu_type_0, fu_type_1;
    logic           [4:0]                   fu_end_0, fu_end_1;
    logic                                   id_valid_0, id_valid_1;

    logic           [4:0]                   out_fu_0, out_fu_1;
    logic           [4:0]                   to_fu_0, to_fu_1;

    assign rs_cdb_0.tag             = rs_entries[fu_num_0].T_dest;
    assign rs_cdb_0.value           = fu_rs[fu_num_0].take_branch ? fu_rs[fu_num_0].NPC : fu_rs[fu_num_0].alu_result;
    assign rs_cdb_0.valid           = fu_result_valid[fu_num_0];
    assign rs_cdb_0.take_branch     = fu_rs[fu_num_0].take_branch;
    assign rs_cdb_0.branch_target   = fu_rs[fu_num_0].take_branch ? fu_rs[fu_num_0].alu_result : fu_rs[fu_num_0].NPC;

    assign rs_cdb_1.tag             = rs_entries[fu_num_1].T_dest;
    assign rs_cdb_1.value           = fu_rs[fu_num_1].take_branch ? fu_rs[fu_num_1].NPC : fu_rs[fu_num_1].alu_result;
    assign rs_cdb_1.valid           = fu_result_valid[fu_num_1];
    assign rs_cdb_1.take_branch     = fu_rs[fu_num_1].take_branch;
    assign rs_cdb_1.branch_target   = fu_rs[fu_num_1].take_branch ? fu_rs[fu_num_1].alu_result : fu_rs[fu_num_1].NPC;


    assign fu_id_0.is_branch        = fu_rs[fu_num_0].is_branch;
    assign fu_id_0.is_valid         = fu_result_valid[fu_num_0];
    assign fu_id_0.PC               = fu_rs[fu_num_0].PC;
    assign fu_id_0.targetPC         = fu_rs[fu_num_0].alu_result;

    assign fu_id_1.is_branch        = fu_rs[fu_num_1].is_branch;
    assign fu_id_1.is_valid         = fu_result_valid[fu_num_1];
    assign fu_id_1.PC               = fu_rs[fu_num_1].PC;
    assign fu_id_1.targetPC         = fu_rs[fu_num_1].alu_result;


    assign rs_rob_0.entry_idx[0]    = mt_rs_0.rs_infos[0].tag;
    assign rs_rob_0.entry_idx[1]    = mt_rs_0.rs_infos[1].tag;
    assign rs_rob_1.entry_idx[0]    = mt_rs_1.rs_infos[0].tag;
    assign rs_rob_1.entry_idx[1]    = mt_rs_1.rs_infos[1].tag;

    assign rs_mt_0.register_idxes   = id_rs_0.input_reg_idx;
    assign rs_mt_1.register_idxes   = id_rs_1.input_reg_idx;

    assign rs_reg_0.register_idxes  = id_rs_0.input_reg_idx;
    assign rs_reg_1.register_idxes  = id_rs_1.input_reg_idx;

    assign rs_lsq.idx               = fu_type_0 == `FU_LS ? (to_fu_0 - 8)  : (to_fu_1 - 8);
    assign rs_lsq.load              = fu_type_0 == `FU_LS ? id_rs_0.rd_mem : id_rs_1.rd_mem;
    assign rs_lsq.store             = fu_type_0 == `FU_LS ? id_rs_0.wr_mem : id_rs_1.wr_mem;
    assign rs_lsq.valid             = fu_type_0 == `FU_LS ? (id_rs_0.dispatch_enable && id_valid_0) : (id_rs_1.dispatch_enable && id_valid_1);

    assign id_valid_0               = id_rs_0.valid && ~id_rs_0.halt && ~id_rs_0.illegal;
    assign id_valid_1               = id_rs_1.valid && ~id_rs_1.halt && ~id_rs_1.illegal && ~(fu_type_0 == `FU_LS && fu_type_1 == `FU_LS);


    assign fu_type_0 =  (id_rs_0.cond_branch || id_rs_0.uncond_branch)  ?   `FU_BEQ  :
                        (id_rs_0.mult_op)                               ?   `FU_MULT :
                        (id_rs_0.rd_mem || id_rs_0.wr_mem)              ?   `FU_LS   :
                                                                            `FU_ALU;
    assign fu_type_1 =  (id_rs_1.cond_branch || id_rs_1.uncond_branch)  ?   `FU_BEQ  :
                        (id_rs_1.mult_op)                               ?   `FU_MULT :
                        (id_rs_1.rd_mem || id_rs_1.wr_mem)              ?   `FU_LS   :
                                                                            `FU_ALU;
    // assign fu_type =   `FU_ALU;

    always_comb begin
        casez (fu_type_0)
            `FU_ALU     : fu_end_0  = `FU_END_ALU;
            `FU_LS      : fu_end_0  = `FU_END_LS;
            `FU_MULT    : fu_end_0  = `FU_END_MULT;
            `FU_BEQ     : fu_end_0  = `FU_END_BEQ;
        endcase
    end
    always_comb begin
        casez (fu_type_1)
            `FU_ALU     : fu_end_1  = `FU_END_ALU;
            `FU_LS      : fu_end_1  = `FU_END_LS;
            `FU_MULT    : fu_end_1  = `FU_END_MULT;
            `FU_BEQ     : fu_end_1  = `FU_END_BEQ;
        endcase
    end
    assign rs_entry_full_0 = (out_fu_0 == 5'b11111) || (id_rs_0.wr_mem && lsq_rs.storeq_full);
    assign rs_entry_full_1 = rs_entry_full_0 || (out_fu_1 == 5'b11111) || (fu_type_0 == `FU_LS && fu_type_1 == `FU_LS) || (id_rs_1.wr_mem && lsq_rs.storeq_full);

    logic               temp_valid;

    always_comb begin
        next_rs_entries                 = rs_entries;
        next_busy                       = busy;
        out_fu_0                        = 5'b11111;
        out_fu_1                        = 5'b11111;
        to_fu_0                         = 5'b11111;
        to_fu_1                         = 5'b11111;
        
        // excute the selected line
        if (fu_result_valid[fu_num_0] && busy[fu_num_0]) begin
            next_rs_entries[fu_num_0]   = 0;
            next_busy[fu_num_0]         = 1'b0;
        end
        if (fu_result_valid[fu_num_1] && busy[fu_num_1]) begin
            next_rs_entries[fu_num_1]   = 0;
            next_busy[fu_num_1]         = 1'b0;
        end

        // check the correctness of the coming instruction
        temp_valid                      = 1'b0;
        for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
            if (~temp_valid && ~(fu < fu_type_0) && (fu < fu_end_0) && ~next_busy[fu]) begin
                temp_valid                  = 1'b1;
                out_fu_0                    = fu;
                if (id_valid_0 && id_rs_0.dispatch_enable) begin
                    to_fu_0                     = fu;
                    next_busy[fu]               = 1'b1;
                    next_rs_entries[fu].T_dest  = rob_rs_0.rob_tail;
                    for (int i = 0; i < 2; i += 1) begin
                        if (id_rs_0.req_reg[i]) begin
                            if (mt_rs_0.rs_infos[i].tag == `ZERO_TAG) begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs_0.rs_infos[i].tag,
                                                                            reg_rs_0.rs_values[i],
                                                                            1'b1    };
                            end else begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs_0.rs_infos[i].tag,
                                                                            rob_rs_0.value[i],
                                                                            mt_rs_0.rs_infos[i].ready   };
                            end
                        end else begin
                            next_rs_entries[fu].rs_entry_info[i]     = {    5'b0,
                                                                            `XLEN'b0,
                                                                            1'b1    };
                        end
                    end
                end
            end
        end

        temp_valid                      = 1'b0;
        for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
            if (~temp_valid && ~(fu < fu_type_1) && (fu < fu_end_1) && ~next_busy[fu]) begin
                temp_valid                  = 1'b1;
                out_fu_1                    = fu;
                if (id_valid_1 && id_rs_1.dispatch_enable) begin
                    to_fu_1                     = fu;
                    next_busy[fu]               = 1'b1;
                    next_rs_entries[fu].T_dest  = rob_rs_1.rob_tail;
                    for (int i = 0; i < 2; i += 1) begin
                        if (id_rs_1.req_reg[i]) begin
                            if (mt_rs_1.rs_infos[i].tag == `ZERO_TAG) begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs_1.rs_infos[i].tag,
                                                                            reg_rs_1.rs_values[i],
                                                                            1'b1    };
                            end else begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs_1.rs_infos[i].tag,
                                                                            rob_rs_1.value[i],
                                                                            mt_rs_1.rs_infos[i].ready };
                            end
                        end else begin
                            next_rs_entries[fu].rs_entry_info[i]     = {    5'b0,
                                                                            `XLEN'b0,
                                                                            1'b1    };
                        end
                    end
                end
            end
        end


        if (cdb_rs_0.valid) begin
            for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
                for (int i = 0; i < 2; i += 1) begin
                    if (next_rs_entries[fu].rs_entry_info[i].tag == cdb_rs_0.tag && ~next_rs_entries[fu].rs_entry_info[i].V_ready && next_busy[fu]) begin
                        next_rs_entries[fu].rs_entry_info[i]     =  {   cdb_rs_0.tag,
                                                                        cdb_rs_0.value,
                                                                        1'b1    };
                    end
                end
            end
        end
        if (cdb_rs_1.valid) begin
            for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
                for (int i = 0; i < 2; i += 1) begin
                    if (next_rs_entries[fu].rs_entry_info[i].tag == cdb_rs_1.tag && ~next_rs_entries[fu].rs_entry_info[i].V_ready && next_busy[fu]) begin
                        next_rs_entries[fu].rs_entry_info[i]     =  {   cdb_rs_1.tag,
                                                                        cdb_rs_1.value,
                                                                        1'b1    };
                    end
                end
            end
        end
  
        for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
            fu_valid[fu]                = ~busy[fu] || rs_fu[fu].selected;
            rs_fu[fu].squash            = rob_rs_0.squash;
            rs_fu[fu].selected          = ((fu_num_0 == fu) || (fu_num_1 == fu)) && fu_result_valid[fu];

            rs_fu[fu].rs_value[1]       = next_rs_entries[fu].rs_entry_info[1].V;
            rs_fu[fu].rs_value[0]       = next_rs_entries[fu].rs_entry_info[0].V;
            rs_fu[fu].rs_value_valid    = next_rs_entries[fu].rs_entry_info[1].V_ready &&
                                            next_rs_entries[fu].rs_entry_info[0].V_ready;
        end
    end

    fu_selector_2 fu_selector_0 (
        // input
        .clock(clock),
        .reset(reset),
        .fu_result_valid(fu_result_valid),
        // output
        .fu_num_0(fu_num_0),
        .fu_num_1(fu_num_1),
        .cat_select_0(cat_select_0),
        .cat_select_1(cat_select_1)
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset || rob_rs_0.squash) begin
            rs_entries      <=  `SD 0;
            busy            <=  `SD `FU_SIZE'b0;
        end else begin
            rs_entries      <=  `SD next_rs_entries;
            busy            <=  `SD next_busy;
        end
    end


    fu_alu fu0 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 0 || to_fu_1 == 0),
        .id_fu(to_fu_0 == 0 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[0]),

        .fu_rs(fu_rs[0]),
        .fu_result_valid(fu_result_valid[0])
    );

    fu_alu fu1 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 1 || to_fu_1 == 1),
        .id_fu(to_fu_0 == 1 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[1]),

        .fu_rs(fu_rs[1]),
        .fu_result_valid(fu_result_valid[1])
    );

    fu_alu fu2 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 2 || to_fu_1 == 2),
        .id_fu(to_fu_0 == 2 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[2]),

        .fu_rs(fu_rs[2]),
        .fu_result_valid(fu_result_valid[2])
    );

    fu_alu fu3 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 3 || to_fu_1 == 3),
        .id_fu(to_fu_0 == 3 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[3]),

        .fu_rs(fu_rs[3]),
        .fu_result_valid(fu_result_valid[3])
    );
    
    fu_alu fu4 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 4 || to_fu_1 == 4),
        .id_fu(to_fu_0 == 4 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[4]),

        .fu_rs(fu_rs[4]),
        .fu_result_valid(fu_result_valid[4])
    );
    
    fu_alu fu5 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 5 || to_fu_1 == 5),
        .id_fu(to_fu_0 == 5 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[5]),

        .fu_rs(fu_rs[5]),
        .fu_result_valid(fu_result_valid[5])
    );
    
    fu_alu fu6 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 6 || to_fu_1 == 6),
        .id_fu(to_fu_0 == 6 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[6]),

        .fu_rs(fu_rs[6]),
        .fu_result_valid(fu_result_valid[6])
    );
    
    fu_alu fu7 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 7 || to_fu_1 == 7),
        .id_fu(to_fu_0 == 7 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[7]),

        .fu_rs(fu_rs[7]),
        .fu_result_valid(fu_result_valid[7])
    );

    fu_ls fu8 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 8 || to_fu_1 == 8),
        .id_fu(to_fu_0 == 8 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[8]),
        .storeq_pos(to_fu_0 == 8 ? (id_rs_0.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)
                                 : (id_rs_1.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)),
        .lsq_fu(lsq_fu[0]),

        .fu_rs(fu_rs[8]),
        .fu_result_valid(fu_result_valid[8]),
        .fu_lsq(fu_lsq[0])
    );

    fu_ls fu9 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 9 || to_fu_1 == 9),
        .id_fu(to_fu_0 == 9 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[9]),
        .storeq_pos(to_fu_0 == 9 ? (id_rs_0.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)
                                 : (id_rs_1.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)),
        .lsq_fu(lsq_fu[1]),

        .fu_rs(fu_rs[9]),
        .fu_result_valid(fu_result_valid[9]),
        .fu_lsq(fu_lsq[1])
    );

    fu_ls fu10 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 10 || to_fu_1 == 10),
        .id_fu(to_fu_0 == 10 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[10]),
        .storeq_pos(to_fu_0 == 10 ? (id_rs_0.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)
                                  : (id_rs_1.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)),
        .lsq_fu(lsq_fu[2]),

        .fu_rs(fu_rs[10]),
        .fu_result_valid(fu_result_valid[10]),
        .fu_lsq(fu_lsq[2])
    );

    fu_ls fu11 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 11 || to_fu_1 == 11),
        .id_fu(to_fu_0 == 11 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[11]),
        .storeq_pos(to_fu_0 == 11 ? (id_rs_0.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)
                                  : (id_rs_1.wr_mem ? lsq_rs.sq_tail : lsq_rs.storeq_tail)),
        .lsq_fu(lsq_fu[3]),

        .fu_rs(fu_rs[11]),
        .fu_result_valid(fu_result_valid[11]),
        .fu_lsq(fu_lsq[3])
    );

    fu_mult fu12 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 12 || to_fu_1 == 12),
        .id_fu(to_fu_0 == 12 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[12]),

        .fu_rs(fu_rs[12]),
        .fu_result_valid(fu_result_valid[12])
    );

    fu_mult fu13 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 13 || to_fu_1 == 13),
        .id_fu(to_fu_0 == 13 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[13]),

        .fu_rs(fu_rs[13]),
        .fu_result_valid(fu_result_valid[13])
    );

    fu_mult fu14 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 14 || to_fu_1 == 14),
        .id_fu(to_fu_0 == 14 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[14]),

        .fu_rs(fu_rs[14]),
        .fu_result_valid(fu_result_valid[14])
    );

    fu_mult fu15 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 15 || to_fu_1 == 15),
        .id_fu(to_fu_0 == 15 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[15]),

        .fu_rs(fu_rs[15]),
        .fu_result_valid(fu_result_valid[15])
    );

    fu_beq fu16 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 16 || to_fu_1 == 16),
        .id_fu(to_fu_0 == 16 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[16]),

        .fu_rs(fu_rs[16]),
        .fu_result_valid(fu_result_valid[16])
    );

    fu_beq fu17 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 17 || to_fu_1 == 17),
        .id_fu(to_fu_0 == 17 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[17]),

        .fu_rs(fu_rs[17]),
        .fu_result_valid(fu_result_valid[17])
    );

    fu_beq fu18 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 18 || to_fu_1 == 18),
        .id_fu(to_fu_0 == 18 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[18]),

        .fu_rs(fu_rs[18]),
        .fu_result_valid(fu_result_valid[18])
    );

    fu_beq fu19 (
        .clock(clock),
        .reset(reset),
        .valid(to_fu_0 == 19 || to_fu_1 == 19),
        .id_fu(to_fu_0 == 19 ? id_rs_0 : id_rs_1),
        .rs_fu(rs_fu[19]),

        .fu_rs(fu_rs[19]),
        .fu_result_valid(fu_result_valid[19])
    );


    `ifdef DEBUG
    logic [31:0] cycle_count;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `FU_SIZE; i += 1) begin
                $display("DEBUG %4d: rs_entries[%2d]: busy = %d, T_dest = %d, Tag0 = %d, V0 = %d, V0_ready = %d, Tag1 = %d, V1 = %d, V1_ready = %d", cycle_count, i, busy[i], rs_entries[i].T_dest, rs_entries[i].rs_entry_info[0].tag, rs_entries[i].rs_entry_info[0].V, rs_entries[i].rs_entry_info[0].V_ready, rs_entries[i].rs_entry_info[1].tag, rs_entries[i].rs_entry_info[1].V, rs_entries[i].rs_entry_info[1].V_ready);
            end
            $display("DEBUG %4d: rs_full = %d", cycle_count, rs_entry_full);
            $display("DEBUG %4d: dispatch_enable = %d", cycle_count, id_rs.dispatch_enable);
            cycle_count = cycle_count + 1;
        end
    end
    `endif

endmodule
`endif // `__RS_2_V__
