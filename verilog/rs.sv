/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs.sv                                               //
//                                                                     //
//  Description :  reservation station;                                // 
/////////////////////////////////////////////////////////////////////////


`define DEBUG
`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module rs (
    input                       clock,
    input                       reset,

    input   ID_RS_PACKET        id_rs,
    input   MT_RS_PACKET        mt_rs,
    input   REG_RS_PACKET       reg_rs,
    input   CDB_ENTRY           cdb_rs,
    input   ROB_RS_PACKET       rob_rs,

    output  RS_MT_PACKET        rs_mt,
    output  CDB_ENTRY           rs_cdb,
    output  RS_REG_PACKET       rs_reg, // TODO
    output  RS_ROB_PACKET       rs_rob,
    output  logic               rs_entry_full
);  
    // TODO add debug outputs for below data
    RS_ENTRY        [`FU_SIZE-1:0]          rs_entries;
    RS_ENTRY        [`FU_SIZE-1:0]          next_rs_entries;

    logic           [`FU_SIZE-1:0]          busy;
    logic           [`FU_SIZE-1:0]          next_busy;

    RS_FU_PACKET    [`FU_SIZE-1:0]          rs_fu;
    FU_RS_PACKET    [`FU_SIZE-1:0]          fu_rs;
    logic           [`FU_SIZE-1:0]          fu_result_valid;

    logic           [4:0]                   fu_num;
    logic           [`FU_CAT-1:0]           cat_select;

    logic           [`FU_SIZE-1:0]          fu_valid;

    
    logic           [4:0]                   fu_type;
    logic           [4:0]                   fu_end;
    logic                                   rs_entry_full_indicator;


    always_comb begin
        for (int i = 0; i < `FU_SIZE; i += 1) begin
            rs_fu[i].squash         =   rob_rs.squash;
            rs_fu[i].selected       =   (fu_num == i) && fu_result_valid[i];
            fu_valid[i]             =   ~busy[i] || rs_fu[i].selected;
            rs_fu[i].rs_value[1]    =   ~fu_valid[i]                            ? ( (~rs_entries[i].rs_entry_info[1].V_ready && cdb_rs.valid &&
                                                                                    rs_entries[i].rs_entry_info[1].tag == cdb_rs.tag) 
                                                                                    ? cdb_rs.value 
                                                                                    : rs_entries[i].rs_entry_info[1].V) :
                                        ~id_rs.req_reg[1]                       ? `XLEN'b0                              :
                                        mt_rs.rs_infos[1].tag == `ZERO_TAG      ? reg_rs.rs_values[1]                   :
                                        (cdb_rs.valid && 
                                        mt_rs.rs_infos[1].tag == cdb_rs.tag)   ? cdb_rs.value                          :
                                                                                rob_rs.value[1];
            rs_fu[i].rs_value[0]    =   ~fu_valid[i]                            ? ( (~rs_entries[i].rs_entry_info[0].V_ready && cdb_rs.valid &&
                                                                                    rs_entries[i].rs_entry_info[0].tag == cdb_rs.tag) 
                                                                                    ? cdb_rs.value 
                                                                                    : rs_entries[i].rs_entry_info[0].V) :
                                        ~id_rs.req_reg[0]                       ? `XLEN'b0                              :
                                        mt_rs.rs_infos[0].tag == `ZERO_TAG      ? reg_rs.rs_values[0]                   :
                                        (cdb_rs.valid && 
                                        mt_rs.rs_infos[0].tag == cdb_rs.tag)   ? cdb_rs.value                          :
                                                                                rob_rs.value[0];
            rs_fu[i].rs_value_valid =   ~fu_valid[i]                            ? ((rs_entries[i].rs_entry_info[1].V_ready || 
                                                                                    (cdb_rs.valid && rs_entries[i].rs_entry_info[1].tag == cdb_rs.tag)) && 
                                                                                (rs_entries[i].rs_entry_info[0].V_ready || 
                                                                                    (cdb_rs.valid && rs_entries[i].rs_entry_info[0].tag == cdb_rs.tag)))
                                                                                : ((~id_rs.req_reg[1]       || mt_rs.rs_infos[1].tag == `ZERO_TAG || 
                                                                                    mt_rs.rs_infos[1].ready || (cdb_rs.valid && mt_rs.rs_infos[1].tag == cdb_rs.tag)) &&
                                                                                (~id_rs.req_reg[0]       || mt_rs.rs_infos[0].tag == `ZERO_TAG || 
                                                                                    mt_rs.rs_infos[0].ready || (cdb_rs.valid && mt_rs.rs_infos[0].tag == cdb_rs.tag)));
        end
    end


    fu_alu fu0 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && fu_valid[0]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[0]),

        .fu_rs(fu_rs[0]),
        .fu_result_valid(fu_result_valid[0])
    );

    fu_alu fu1 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && fu_valid[1]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[1]),

        .fu_rs(fu_rs[1]),
        .fu_result_valid(fu_result_valid[1])
    );

    fu_alu fu2 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && fu_valid[2]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[2]),

        .fu_rs(fu_rs[2]),
        .fu_result_valid(fu_result_valid[2])
    );

    fu_alu fu3 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && ~fu_valid[2] && fu_valid[3]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[3]),

        .fu_rs(fu_rs[3]),
        .fu_result_valid(fu_result_valid[3])
    );
    
    fu_alu fu4 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && ~fu_valid[2] && ~fu_valid[3] && fu_valid[4]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[4]),

        .fu_rs(fu_rs[4]),
        .fu_result_valid(fu_result_valid[4])
    );
    
    fu_alu fu5 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && ~fu_valid[2] && ~fu_valid[3] && ~fu_valid[4] && fu_valid[5]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[5]),

        .fu_rs(fu_rs[5]),
        .fu_result_valid(fu_result_valid[5])
    );
    
    fu_alu fu6 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && ~fu_valid[2] && ~fu_valid[3] && ~fu_valid[4] && ~fu_valid[5] && fu_valid[6]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[6]),

        .fu_rs(fu_rs[6]),
        .fu_result_valid(fu_result_valid[6])
    );
    
    fu_alu fu7 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_ALU && ~fu_valid[0] && ~fu_valid[1] && ~fu_valid[2] && ~fu_valid[3] && ~fu_valid[4] && ~fu_valid[5] && ~fu_valid[6] && fu_valid[7]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[7]),

        .fu_rs(fu_rs[7]),
        .fu_result_valid(fu_result_valid[7])
    );

    fu_ls fu8 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_LS && fu_valid[8]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[8]),

        .fu_rs(fu_rs[8]),
        .fu_result_valid(fu_result_valid[8])
    );

    fu_ls fu9 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_LS && ~fu_valid[8] && fu_valid[9]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[9]),

        .fu_rs(fu_rs[9]),
        .fu_result_valid(fu_result_valid[9])
    );

    fu_ls fu10 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_LS && ~fu_valid[8] && ~fu_valid[9] && fu_valid[10]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[10]),

        .fu_rs(fu_rs[10]),
        .fu_result_valid(fu_result_valid[10])
    );

    fu_ls fu11 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_LS && ~fu_valid[8] && ~fu_valid[9] && ~fu_valid[10] && fu_valid[11]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[11]),

        .fu_rs(fu_rs[11]),
        .fu_result_valid(fu_result_valid[11])
    );

    fu_mult fu12 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_MULT && fu_valid[12]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[12]),

        .fu_rs(fu_rs[12]),
        .fu_result_valid(fu_result_valid[12])
    );

    fu_mult fu13 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_MULT && ~fu_valid[12] && fu_valid[13]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[13]),

        .fu_rs(fu_rs[13]),
        .fu_result_valid(fu_result_valid[13])
    );

    fu_mult fu14 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_MULT && ~fu_valid[12] && ~fu_valid[13] && fu_valid[14]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[14]),

        .fu_rs(fu_rs[14]),
        .fu_result_valid(fu_result_valid[14])
    );

    fu_mult fu15 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_MULT && ~fu_valid[12] && ~fu_valid[13] && ~fu_valid[14] && fu_valid[15]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[15]),

        .fu_rs(fu_rs[15]),
        .fu_result_valid(fu_result_valid[15])
    );

    fu_beq fu16 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_BEQ && fu_valid[16]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[16]),

        .fu_rs(fu_rs[16]),
        .fu_result_valid(fu_result_valid[16])
    );

    fu_beq fu17 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_BEQ && ~fu_valid[16] && fu_valid[17]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[17]),

        .fu_rs(fu_rs[17]),
        .fu_result_valid(fu_result_valid[17])
    );

    fu_beq fu18 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_BEQ && ~fu_valid[16] && ~fu_valid[17] && fu_valid[18]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[18]),

        .fu_rs(fu_rs[18]),
        .fu_result_valid(fu_result_valid[18])
    );

    fu_beq fu19 (
        .clock(clock),
        .reset(reset),
        .valid(fu_type == `FU_BEQ && ~fu_valid[16] && ~fu_valid[17] && ~fu_valid[18] && fu_valid[19]),
        .id_fu((id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) ? id_rs : 0),
        .rs_fu(rs_fu[19]),

        .fu_rs(fu_rs[19]),
        .fu_result_valid(fu_result_valid[19])
    );

    fu_selector fu_selector_0 (
        // input
        .clock(clock),
        .reset(reset),
        .fu_result_valid(fu_result_valid),
        // output
        .fu_num(fu_num),
        .cat_select(cat_select)
    );

    assign rs_cdb.tag               = rs_entries[fu_num].T_dest;
    assign rs_cdb.value             = fu_rs[fu_num].alu_result;
    assign rs_cdb.valid             = fu_result_valid[fu_num];
    assign rs_cdb.take_branch       = fu_rs[fu_num].take_branch;

    assign rs_rob.entry_idx[0]      = mt_rs.rs_infos[0].tag;
    assign rs_rob.entry_idx[1]      = mt_rs.rs_infos[1].tag;
    assign rs_mt.register_idxes     = id_rs.input_reg_idx;
    assign rs_reg.register_idxes    = id_rs.input_reg_idx;
    
    // assign fu_type = id_rs.wr_mem ? FU_STORE : id_rs.rd_mem ? FU_LOAD : FU_ALU;
    // assign rs_entry_full = rs_entries[fu_type].busy;


    assign fu_type =    (id_rs.cond_branch || id_rs.uncond_branch)  ?   `FU_BEQ  :
                        id_rs.mult_op                               ?   `FU_MULT :
                        (id_rs.rd_mem || id_rs.wr_mem)              ?   `FU_LS   :
                                                                        `FU_ALU;
    // assign fu_type =   `FU_ALU;

    always_comb begin
        casez (fu_type)
            `FU_ALU     : begin
                fu_end                      = `FU_END_ALU;
                rs_entry_full_indicator     = (busy[`FU_END_ALU-1:`FU_ALU]      == {`NUM_ALU{1'b1}});
            end
            `ifdef FULL_FU_OUT_TEST
                `FU_LS      : begin
                    fu_end                  = `FU_END_LS;
                    rs_entry_full_indicator = (busy[`FU_END_LS-1:`FU_LS]        == {`NUM_LS{1'b1}});
                end
                `FU_MULT    : begin
                    fu_end                  = `FU_END_MULT;
                    rs_entry_full_indicator = (busy[`FU_END_MULT-1:`FU_MULT]    == {`NUM_MULT{1'b1}});
                end
                `FU_BEQ     : begin
                    fu_end                  = `FU_END_BEQ;
                    rs_entry_full_indicator = (busy[`FU_END_BEQ-1:`FU_BEQ]      == {`NUM_BEQ{1'b1}});
                end
            `endif
        endcase
    end

    assign rs_entry_full = rs_entry_full_indicator  ? ~busy[fu_num] || ~fu_result_valid[fu_num] || 
                                                      (fu_num < fu_type) || ~(fu_num < fu_end)
                                                    : 1'b0;
    // assign rs_entry_full =  (busy[fu_end-1:fu_type]+1 == 0);
    // assign rs_entry_full = ((busy[3:0] + {{(3){1'b0}},1'b1}) == {(4){1'b0}}) ? ~(fu_result_valid[fu_num] && busy[fu_num] && ~(fu_num < fu_type) && (fu_num < fu_end))
    //                                                                          : 1'b0;
    // assign rs_entry_full = ((busy[0] + 1'b1) == 1'b0);

    logic               temp_logic;

    always_comb begin
        next_rs_entries             =   rs_entries;
        next_busy                   =   busy;
        
        // excute the selected line
        if (fu_result_valid[fu_num] && busy[fu_num]) begin
            next_rs_entries[fu_num] = 0;
            next_busy[fu_num]       = 1'b0;
        end

        // check the correctness of the coming instruction
        temp_logic                  =   1'b1;
        if (id_rs.dispatch_enable && id_rs.valid && ~id_rs.halt && ~id_rs.illegal) begin
            for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
                if (~(fu < fu_type) && (fu < fu_end) && ~next_busy[fu] && temp_logic) begin
                    temp_logic                  =   1'b0;
                    next_busy[fu]               =   1'b1;
                    next_rs_entries[fu].T_dest  =   rob_rs.rob_tail;
                    for (int i = 0; i < 2; i += 1) begin
                        if (id_rs.req_reg[i]) begin
                            if (mt_rs.rs_infos[i].tag == `ZERO_TAG) begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs.rs_infos[i].tag,
                                                                            reg_rs.rs_values[i],
                                                                            1'b1    };
                            end else begin
                                next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs.rs_infos[i].tag,
                                                                            rob_rs.value[i],
                                                                            mt_rs.rs_infos[i].ready };
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

        if (cdb_rs.valid) begin
            for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
                for (int i = 0; i < 2; i += 1) begin
                    if (next_rs_entries[fu].rs_entry_info[i].tag == cdb_rs.tag && next_busy[fu]) begin
                        next_rs_entries[fu].rs_entry_info[i]     =  {   cdb_rs.tag, 
                                                                        cdb_rs.value, 
                                                                        1'b1    };
                    end
                end
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset || rob_rs.squash) begin
            rs_entries      <=  `SD 0;
            busy            <=  `SD `FU_SIZE'b0;
        end else begin
            rs_entries      <=  `SD next_rs_entries;
            busy            <=  `SD next_busy;
        end
    end


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

`endif // `__RS_V__