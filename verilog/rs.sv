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
    RS_ENTRY [`FU_SIZE-1:0] rs_entries;

    RS_FU_PACKET    [`FU_SIZE-1:0]      rs_fu;
    FU_RS_PACKET    [`FU_SIZE-1:0]      fu_rs;
    always_comb begin
        for (int i = 0; i < `FU_SIZE; i += 1) begin
            rs_fu[i]    = { rob_rs.squash,
                            id_rs.NPC,
                            id_rs.PC,
                            rs_entries[i].rs_entry_info[0].V,
                            rs_entries[i].rs_entry_info[1].V,
                            rs_entries[i].rs_entry_info[0].V_ready && rs_entries[i].rs_entry_info[1].V_ready,
                            id_rs.opa_select,
                            id_rs.opb_select,
                            id_rs.inst,
                            id_rs.dest_reg_idx,
                            id_rs.alu_func,
                            id_rs.rd_mem,
                            id_rs.wr_mem,
                            id_rs.cond_branch,
                            id_rs.uncond_branch,
                            id_rs.halt,
                            id_rs.illegal,
                            id_rs.csr_op,
                            id_rs.valid };
        end
    end

    fu_alu fu0 (
        .clock(clock),
        .reset(reset),

        .rs_fu(rs_fu[0]),

        .fu_rs(fu_rs[0])
    );

    logic           [$clog2(`FU_SIZE):0]    fu_num;
    logic           [`FU_CAT-1:0]           cat_select;
    FU_RS_PACKET                            fu_select;
    
    fu_selector fu_selector_0 (
        .clock(clock),
        .reset(reset),

        .fu_rs(fu_rs),

        .fu_num(fu_num),
        .cat_select(cat_select),
        .fu_select(fu_select)
    );

    assign rs_cdb.tag           = rs_entries[fu_num].T_dest;
    assign rs_cdb.value         = fu_select.alu_result;
    assign rs_cdb.valid         = fu_select.valid;
    assign rs_cdb.take_branch   = fu_select.take_branch;


    
    assign rs_rob.entry_idx[0] = mt_rs.rs_infos[0].tag;
    assign rs_rob.entry_idx[1] = mt_rs.rs_infos[1].tag;
    assign rs_mt.register_idxes = id_rs.input_reg_idx;
    assign rs_reg.register_idxes = id_rs.input_reg_idx;
    
    assign fu_type = id_rs.wr_mem ? FU_STORE : id_rs.rd_mem ? FU_LOAD : FU_ALU;
    assign rs_entry_full = rs_entries[fu_type].busy;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset || rob_rs.squash) begin
            rs_entries  <= `SD 0;
        end else begin
            for (int i = 0; i <`FU_SIZE; i+=1) begin
                if (rs_entries[fu_type].rs_entry_info[1].V_ready & rs_entries[fu_type].rs_entry_info[0].V_ready) begin
                    rs_entries[fu_type] <= `SD 0;
                end
            end
            if (id_rs.dispatch_enable & id_rs.valid & ~id_rs.halt & ~id_rs.illegal) begin
                rs_entries[fu_type].busy <= `SD 1;
                rs_entries[fu_type].T_dest <= `SD rob_rs.rob_tail;
                for (int idx = 0; idx < 2; idx += 1) begin
                    rs_entries[fu_type].rs_entry_info[idx].tag <= `SD mt_rs.rs_infos[idx].tag;
                    if (mt_rs.rs_infos[idx].tag == `ZERO_TAG) begin
                        // Value is in regfile
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {mt_rs.rs_infos[idx].tag, reg_rs.rs_values[idx], 1'b1};
                    end else begin
                        // Grab value from ROB and ready bit
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {mt_rs.rs_infos[idx].tag, rob_rs.value[idx], mt_rs.rs_infos[idx].ready | !id_rs.req_reg[idx]};
                    end
                end
            end
            // If CDB is not empty then update values with corresponding tag
            if (cdb_rs.valid) begin
                for (int fu = 0; fu < `FU_SIZE; fu += 1) begin
                    for (int reg_idx = 0; reg_idx < 2; reg_idx += 1) begin
                        if (rs_entries[fu].rs_entry_info[reg_idx].tag == cdb_rs.tag) begin
                            rs_entries[fu].rs_entry_info[reg_idx] <= `SD {cdb_rs.tag, cdb_rs.value, 1'b1};
                        end
                    end
                end
            end
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
                $display("DEBUG %4d: rs_entries[%d]: busy = %d, T_dest = %d, Tag0 = %d, V0 = %d, V0_ready = %d, Tag1 = %d, V1 = %d, V1_ready = %d", cycle_count, i, rs_entries[i].busy, rs_entries[i].T_dest, rs_entries[i].rs_entry_info[0].tag, rs_entries[i].rs_entry_info[0].V, rs_entries[i].rs_entry_info[0].V_ready, rs_entries[i].rs_entry_info[1].tag, rs_entries[i].rs_entry_info[1].V, rs_entries[i].rs_entry_info[1].V_ready);
            end
            cycle_count = cycle_count + 1;
        end
       
    end
    `endif

endmodule

`endif // `__RS_V__