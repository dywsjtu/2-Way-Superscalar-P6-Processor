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
    RS_ENTRY        [`FU_SIZE-1:0]      rs_entries;
    RS_ENTRY        [`FU_SIZE-1:0]      next_rs_entries;

    logic           [`FU_SIZE-1:0]      busy;
    logic           [`FU_SIZE-1:0]      next_busy;

    // RS_FU_PACKET    [`FU_SIZE-1:0]      rs_fu;
    FU_RS_PACKET    [`FU_SIZE-1:0]      fu_rs;
    logic           [`FU_SIZE-1:0]      fu_result_valid;

    logic           [$clog2(`FU_SIZE):0]    fu_num;
    logic           [`FU_CAT-1:0]           cat_select;

    fu_alu fu0 (
        // input
        .clock(clock),
        .reset(reset),

        // load_id_rs

        .id_fu(id_rs),

        // load_value

        .rs_fu( {   rob_rs.squash,
                    ((fu_num == 0) && fu_result_valid[0]),
                    {rs_entries[0].rs_entry_info[1].V, rs_entries[0].rs_entry_info[0].V},
                    (rs_entries[0].rs_entry_info[0].V_ready && rs_entries[0].rs_entry_info[1].V_ready)} ),
        
        // output
        .fu_rs(fu_rs[0]),
        .fu_result_valid(fu_result_valid[0])
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

    assign rs_cdb.tag           = rs_entries[fu_num].T_dest;
    assign rs_cdb.value         = fu_rs[fu_num].alu_result;
    assign rs_cdb.valid         = fu_result_valid[fu_num];
    assign rs_cdb.take_branch   = fu_rs[fu_num].take_branch;

    assign rs_rob.entry_idx[0] = mt_rs.rs_infos[0].tag;
    assign rs_rob.entry_idx[1] = mt_rs.rs_infos[1].tag;
    assign rs_mt.register_idxes = id_rs.input_reg_idx;
    assign rs_reg.register_idxes = id_rs.input_reg_idx;
    
    // assign fu_type = id_rs.wr_mem ? FU_STORE : id_rs.rd_mem ? FU_LOAD : FU_ALU;
    // assign rs_entry_full = rs_entries[fu_type].busy;

    logic   [4:0]       fu_type;
    logic   [4:0]       fu_end;

    // assign fu_type =    (id_rs.rd_mem || id_rs.wr_mem)              ?   `FU_LS   :
    //                     (id_rs.cond_branch || id_rs.uncond_branch)  ?   `FU_BEQ  :
    //                     `FU_ALU;     // TODO: FU_MULT
    // assign fu_end  =    (id_rs.rd_mem || id_rs.wr_mem)              ?   `FU_END_LS   :
    //                     (id_rs.cond_branch || id_rs.uncond_branch)  ?   `FU_END_BEQ  :
    //                     `FU_END_ALU;     // TODO: FU_END_MULT

    assign fu_type =   `FU_ALU;
    assign fu_end  =   `FU_END_ALU;

    // assign rs_entry_full =  (busy[fu_end-1:fu_type]+1 == 0);
    // assign rs_entry_full = ((busy[0] + 1'b1) == 1'b0)   ? ~(fu_result_valid[fu_num] && busy[fu_num] && ~(fu_num < fu_type) && (fu_num < fu_end))
    //                                                     : 1'b0;
    assign rs_entry_full = ((busy[0] + 1'b1) == 1'b0);

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
            for (int fu = fu_type; fu < fu_end; fu += 1) begin
                if (~busy[fu] && temp_logic) begin
                    temp_logic                  =   1'b0;
                    next_busy[fu]               =   1'b1;
                    next_rs_entries[fu].T_dest  =   rob_rs.rob_tail;
                    next_rs_entries[fu].id_rs   =   id_rs;
                    for (int i = 0; i < 2; i += 1) begin
                        if (mt_rs.rs_infos[i].tag == `ZERO_TAG) begin
                            next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs.rs_infos[i].tag,
                                                                        reg_rs.rs_values[i],
                                                                        1'b1    };
                        end else begin
                            next_rs_entries[fu].rs_entry_info[i] =  {   mt_rs.rs_infos[i].tag,
                                                                        rob_rs.value[i],
                                                                        mt_rs.rs_infos[i].ready || !id_rs.req_reg[i]    };
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