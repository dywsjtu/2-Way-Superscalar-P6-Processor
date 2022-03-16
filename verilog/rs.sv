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
    input   CDB_RS_PACKET       cdb_rs,
    input   ROB_RS_PACKET       rob_rs,

    output  RS_MT_PACKET        rs_mt,
    output  RS_FU_PACKET        rs_fu,
    // output  RS_REG_PACKET       rs_reg,
    output  RS_ROB_PACKET       rs_rob
);  
    // TODO add debug outputs for below data
    RS_ENTRY rs_entries[FU_COUNT-1:0];
    FU_TAG fu_type;

    assign rs_rob.entry_idx[0] = mt_rs.rs_infos[0].tag;
    assign rs_rob.entry_idx[1] = mt_rs.rs_infos[1].tag;
    assign rs_mt.register_idxes = id_rs.input_reg_idx;
    

    always_ff @(posedge clock) begin
        if(reset || rob_rs.squash) begin
            rs_entries  <= `SD 0;
            fu_type     <= `SD 0;
        end
        else begin
            if (id_rs.dispatch_enable) begin
                fu_type <= `SD id_rs.wr_mem ? FU_STORE : id_rs.rd_mem ? FU_LOAD : FU_ALU;
                rs_entries[fu_type].busy <= `SD 1;
                rs_entries[fu_type].T_dest <= `SD rob_rs.rob_tail;
                for (int idx = 0; idx < 2; idx += 1) begin
                    rs_entries[fu_type].reg_infos[idx].T <= `SD mt_rs.rs_infos[idx].tag;
                    if(mt_rs.rs_infos[idx].tag == `ROB_SIZE) begin
                        // Value is in regfile
                        rs_entries[fu_type].reg_infos[idx] <= `SD {.V = id_rs.rs_value[idx], .V_ready = 1};
                    end
                    else begin
                        // Grab value from ROB and ready bit
                        rs_entries[fu_type].reg_infos[idx] <= `SD {.V = rob_rs.value[idx], .V_ready = mt_rs.rs_infos[idx].ready};
                    end
                end
            end
            // If CDB is not empty then update value
            if(cdb_rs.ready) begin
                rs_entries[cdb_rs.fu_type].V <= `SD cdb_rs.V;
                rs_entries[cdb_rs.fu_type].V_ready <= `SD 1;
            end
            // TODO clear entry when FU finishes executing
        end
    end

endmodule

`endif // `__RS_V__