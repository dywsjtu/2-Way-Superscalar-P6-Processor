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

module rs(
    input                       clock,
    input                       reset,

    input   ID_RS_PACKET        id_rs,
    input   MT_RS_PACKET        mt_rs,
    input   REG_RS_PACKET       reg_rs,
    input   CDB_ENTRY           cdb_rs,
    input   ROB_RS_PACKET       rob_rs,

    output  RS_MT_PACKET        rs_mt,
    output  RS_FU_PACKET        rs_fu,
    output  RS_REG_PACKET       rs_reg, // TODO
    output  RS_ROB_PACKET       rs_rob,
    output  logic               rs_entry_full,
);  
    // TODO add debug outputs for below data
    RS_ENTRY [FU_COUNT-1:0] rs_entries;

    assign rs_rob.entry_idx[0] = mt_rs.rs_infos[0].tag;
    assign rs_rob.entry_idx[1] = mt_rs.rs_infos[1].tag;
    //assign rs_mt.register_idxes = id_rs.input_reg_idx;
    
    assign fu_type = id_rs.wr_mem ? FU_STORE : id_rs.rd_mem ? FU_LOAD : FU_ALU;
    assign rs_entry_full = rs_entries[fu_type].busy;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset || rob_rs.squash) begin
            rs_entries  <= `SD 0;
        end
        else begin
            if (id_rs.dispatch_enable) begin
                rs_entries[fu_type].busy <= `SD 1;
                rs_entries[fu_type].T_dest <= `SD rob_rs.rob_tail;
                for (int idx = 0; idx < 2; idx += 1) begin
                    rs_entries[fu_type].rs_entry_info[idx].T <= `SD mt_rs.rs_infos[idx].tag;
                    if(mt_rs.rs_infos[idx].tag == `ROB_SIZE) begin
                        // Value is in regfile
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {.V = id_rs.rs_value[idx], .V_ready = 1};
                    end
                    else begin
                        // Grab value from ROB and ready bit
                        rs_entries[fu_type].rs_entry_info[idx] <= `SD {.V = rob_rs.value[idx], .V_ready = mt_rs.rs_infos[idx].ready};
                    end
                end
            end
            // If CDB is not empty then update values with corresponding tag
            if(cdb_rs.ready) begin
                for(int fu = 0; fu < FU_COUNT; fu += 1) begin
                    for(int reg_idx = 0; reg_idx < 2; reg_idx += 1) begin
                        if(rs_entries[i].rs_entry_info[reg_idx].tag == cdb_rs.tag) begin
                            rs_entries[i].rs_entry_info[reg_idx] <= `SD {.V = cdb_rs.V, .V_ready = 1};
                        end
                    end
                end
            end
            for(int fu = 0; fu < FU_COUNT; fu += 1) begin
                for(int reg_idx = 0; reg_idx < 2; reg_idx += 1) begin
                    rs_entries[i].rs_entry_info[reg_idx].V_ready == need_value;
                end
                rs_entries[i].ready_execute = ??;
            end
            ALU(rs_entries[FU_ALU].rs_entry_info[0].V, .. .ready(rs_entries[FU_ALU].ready_execute));
            // TODO clear entry when we send it to FU for execution
        end
    end

endmodule

`endif // `__RS_V__