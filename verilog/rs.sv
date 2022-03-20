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
    // output  RS_FU_PACKET        rs_fu,
    output  RS_REG_PACKET       rs_reg, // TODO
    output  RS_ROB_PACKET       rs_rob,
    output  logic               rs_entry_full
);  
    // RS_FU_PACKET                    std_rs_fu;
    // assign std_rs_fu.squash         = rob_rs.squash;
    // assign std_rs_fu.NPC            = id_rs.NPC;
    // assign std_rs_fu.PC             = id_rs.PC;
    // assign std_rs_fu.rs_value[0]    = `XLEN'b0;
    // assign std_rs_fu.rs_value[1]    = `XLEN'b0;
    // assign std_rs_fu.opa_select     = id_rs.opa_select;
    // assign std_rs_fu.opb_select     = id_rs.opb_select;
    // assign std_rs_fu.inst           = id_rs.inst;
    // assign std_rs_fu.dest_reg_idx   = id_rs.dest_reg_idx;
    // assign std_rs_fu.alu_func       = id_rs.alu_func;
    // assign std_rs_fu.rd_mem         = id_rs.rd_mem;
    // assign std_rs_fu.wr_mem         = id_rs.wr_mem;
    // assign std_rs_fu.cond_branch    = id_rs.cond_branch;
    // assign std_rs_fu.uncond_branch  = id_rs.uncond_branch;
    // assign std_rs_fu.halt           = id_rs.halt;
    // assign std_rs_fu.illegal        = id_rs.illegal;
    // assign std_rs_fu.csr_op         = id_rs.csr_op;
    // assign std_rs_fu.valid          = id_rs.valid;

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

    // TODO add debug outputs for below data
    RS_ENTRY [FU_COUNT-1:0] rs_entries;

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
            if (id_rs.dispatch_enable) begin
                rs_entries[fu_type].busy <= `SD 1;
                rs_entries[fu_type].T_dest <= `SD rob_rs.rob_tail;
                for (int idx = 0; idx < 2; idx += 1) begin
                    rs_entries[fu_type].rs_entry_info[idx].tag <= `SD mt_rs.rs_infos[idx].tag;
                    if (mt_rs.rs_infos[idx].tag == `ZERO_TAG) begin
                        // Value is in regfile
                        // rs_entries[fu_type].rs_entry_info[idx] <= `SD {id_rs.rs_value[idx], 1};
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {reg_rs.rs_values[idx], 1'b1};
                    end
                    if (mt_rs.rs_infos[idx].tag != `ZERO_TAG) begin
                        // Grab value from ROB and ready bit
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {rob_rs.value[idx], mt_rs.rs_infos[idx].ready | !id_rs.req_reg[idx]};
                    end
                end
            end
            // If CDB is not empty then update values with corresponding tag
            if (cdb_rs.valid) begin
                for (int fu = 0; fu < FU_COUNT; fu += 1) begin
                    for (int reg_idx = 0; reg_idx < 2; reg_idx += 1) begin
                        if (rs_entries[fu].rs_entry_info[reg_idx].tag == cdb_rs.tag) begin
                            rs_entries[fu].rs_entry_info[reg_idx] <= `SD {cdb_rs.value, 1'b1};
                        end
                    end
                end
            end
        end
    end

endmodule

`endif // `__RS_V__