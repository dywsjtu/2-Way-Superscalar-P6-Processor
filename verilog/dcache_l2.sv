/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_L2_V__
`define __DCACHE_L2_V__

`define DCACHE_LINES_L2         16
`define DCACHE_LINE_BITS_L2     $clog2(`DCACHE_LINES_L2)
`define DCACHE_LINE_SIZE_L2     2
`define DCACHE_FETCH_SIZE_L2    4

`define VICTIM_CACHE_LINES_L2   2
`define MISS_LINES_L2           8

`timescale 1ns/100ps


module dcache_l2 (
    input                                   clock,
    input                                   reset,
    // From Pipeline
    input                                   chosen2Mem,

    // From Dmem
    input                                   Dmem2proc_valid,
    input [3:0]                             Dmem2proc_response,
    input [63:0]                            Dmem2proc_data,
    input [3:0]                             Dmem2proc_tag,

    // To Dmem
    output logic                            proc2Dmem_valid,
    output logic [63:0]                     proc2Dmem_data,
    output logic [1:0]                      proc2Dmem_command,
    output logic [`XLEN-1:0]                proc2Dmem_addr,

    // From LSQ
    input LSQ_LOAD_DCACHE_PACKET            lsq_load_dc,
    input LSQ_STORE_DCACHE_PACKET           lsq_store_dc,

    // To LSQ
    output DCACHE_LOAD_LSQ_PACKET           dc_load_lsq,
    output DCACHE_STORE_LSQ_PACKET          dc_store_lsq
);

    // cache data
    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0] [63:0]                        data;
    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0] [12-`DCACHE_LINE_BITS_L2:0]   tags;
    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0]                               valids;
    logic   [`VICTIM_CACHE_LINES_L2-1:0] [63:0]                                             victim_data;
    logic   [`VICTIM_CACHE_LINES_L2-1:0] [12:0]                                             victim_addr;
    logic   [`VICTIM_CACHE_LINES_L2-1:0]                                                    victim_valid;
    logic                                                                                   victim_head;

    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0] [63:0]                        next_data;
    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0] [12-`DCACHE_LINE_BITS_L2:0]   next_tags;
    logic   [`DCACHE_LINES_L2-1:0] [`DCACHE_LINE_SIZE_L2-1:0]                               next_valids;
    logic   [`VICTIM_CACHE_LINES_L2-1:0] [63:0]                                             next_victim_data;
    logic   [`VICTIM_CACHE_LINES_L2-1:0] [12:0]                                             next_victim_addr;
    logic   [`VICTIM_CACHE_LINES_L2-1:0]                                                    next_victim_valid;
    logic                                                                                   next_victim_head;

    MISS_ENTRY      [`MISS_LINES-1:0]           miss_entries;
    MISS_ENTRY      [`MISS_LINES-1:0]           next_miss_entries;

    logic                                       temp_valid;
    EXAMPLE_CACHE_BLOCK                         temp_value;
    logic           [13:0]                      temp_addr;
    logic           [1:0]                       temp_op;
    logic           [12-`DCACHE_LINE_BITS_L2:0] temp_tag;
    logic           [`DCACHE_LINE_BITS_L2-1:0]  temp_idx;

    always_comb begin
        dc_load_lsq.valid       = 1'b0;
        dc_load_lsq.value       = `XLEN'b0;
        dc_store_lsq.valid      = 1'b0;
        next_miss_entries       = miss_entries;
        next_data               = data;
        next_tags               = tags;
        next_valids             = valids;
        next_victim_data        = victim_data;
        next_victim_addr        = victim_addr;
        next_victim_valid       = victim_valid;
        next_victim_head        = victim_head;

        temp_valid  = 1'b0;
        temp_addr   = 14'b0;
        temp_value  = 64'b0;
        temp_op     = 1'b0;
        temp_tag    = 0;
        temp_idx    = 0;

        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (miss_entries[i].valid && miss_entries[i].sent && miss_entries[i].op) begin
                next_miss_entries[i] = 0;
            end
        end

        if (Dmem2proc_valid) begin
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                if (~temp_valid && next_miss_entries[i].valid && next_miss_entries[i].sent && next_miss_entries[i].tag == Dmem2proc_tag) begin
                    temp_valid  = 1'b1;
                    temp_value  = Dmem2proc_data;
                    temp_addr   = {1'b1, next_miss_entries[i].addr[15:3]};
                    temp_op     = next_miss_entries[i].op;
                    temp_tag    = next_miss_entries[i].addr[15:`DCACHE_LINE_BITS_L2+3];
                    temp_idx    = next_miss_entries[i].addr[`DCACHE_LINE_BITS_L2+2:3];
                    next_miss_entries[i].valid  = 1'b0;
                end
            end
            if (temp_valid && ~temp_op) begin
                if (~next_valids[temp_idx][0]) begin
                    next_data[temp_idx][0]      = temp_value;
                    next_tags[temp_idx][0]      = temp_tag;
                    next_valids[temp_idx][0]    = 1'b1;
                end else begin
                    if (next_valids[temp_idx][1]) begin
                        next_victim_data[next_victim_head]      = next_data[temp_idx][1];
                        next_victim_addr[next_victim_head]      = {next_tags[temp_idx][1], temp_idx};
                        next_victim_valid[next_victim_head]     = 1'b1;
                        next_victim_head                        = next_victim_head + 1;
                    end
                    next_data[temp_idx]         = {next_data[temp_idx][0], temp_value};
                    next_tags[temp_idx]         = {next_tags[temp_idx][0], temp_tag};
                    next_valids[temp_idx]       = {next_valids[temp_idx][0], 1'b1};
                end
            end
        end

        if (lsq_load_dc.valid) begin
            temp_valid  = 1'b0;
            temp_tag    = lsq_load_dc.addr[15:`DCACHE_LINE_BITS_L2+3];
            temp_idx    = lsq_load_dc.addr[`DCACHE_LINE_BITS_L2+2:3];
            if (next_valids[temp_idx][0] && next_tags[temp_idx][0] == temp_tag) begin
                temp_valid = 1'b1;
                temp_value = next_data[temp_idx][0];
            end else if (next_valids[temp_idx][1] && next_tags[temp_idx][1] == temp_tag) begin
                temp_valid                  = 1'b1;
                temp_value                  = next_data[temp_idx][1];
                next_data[temp_idx]         = {next_data[temp_idx][0], temp_value};
                next_tags[temp_idx]         = {next_tags[temp_idx][0], temp_tag};
                next_valids[temp_idx]       = {next_valids[temp_idx][0], 1'b1};
            end else begin
                for (int i = 0; i < `VICTIM_CACHE_LINES_L2; i += 1) begin
                    if (~temp_valid && next_victim_valid[i] && next_victim_addr[i] == lsq_load_dc.addr[15:3]) begin
                        temp_valid              = 1'b1;
                        temp_value              = next_victim_data[i];
                        next_victim_data[i]     = next_data[temp_idx][1];
                        next_victim_addr[i]     = {next_tags[temp_idx][1], temp_idx};
                        next_victim_valid[i]    = next_valids[temp_idx][1];
                        next_victim_head        = next_valids[temp_idx][1] ? (i+1) : i;
                        next_data[temp_idx]     = {next_data[temp_idx][0], temp_value};
                        next_tags[temp_idx]     = {next_tags[temp_idx][0], temp_tag};
                        next_valids[temp_idx]   = {next_valids[temp_idx][0], 1'b1};
                    end
                end
            end

            if (temp_valid) begin
                dc_load_lsq.valid   = 1'b1;
                casez (lsq_load_dc.mem_size)
                    BYTE: dc_load_lsq.value = {24'b0, temp_value.byte_level[lsq_load_dc.addr[2:0]]};
                    HALF: dc_load_lsq.value = {16'b0, temp_value.half_level[lsq_load_dc.addr[2:1]]};
                    WORD: dc_load_lsq.value =         temp_value.word_level[lsq_load_dc.addr[2]];
                endcase
            end else begin
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (next_miss_entries[i].valid && next_miss_entries[i].addr[15:3] == lsq_load_dc.addr[15:3] && ~next_miss_entries[i].op) begin
                        temp_valid      = 1'b1;
                    end
                end
                if (~temp_valid) begin
                    for (int i = 0; i < `MISS_LINES; i += 1) begin
                        if (~temp_valid && next_miss_entries[i].valid == 1'b0) begin
                            temp_valid  = 1'b1;
                            next_miss_entries[i] = {    1'b1,
                                                        1'b0,
                                                        4'b0000,
                                                        lsq_load_dc.addr[15:0],
                                                        64'b0,
                                                        lsq_load_dc.mem_size,
                                                        1'b0   };
                        end
                    end
                end
            end
        end
        
        dc_store_lsq.valid = 1'b0;
        if (lsq_store_dc.valid && (~temp_addr[13] || (lsq_store_dc.addr[15:3] != temp_addr[12:0]))) begin
            temp_valid  = 1'b0;
            temp_tag    = lsq_store_dc.addr[15:`DCACHE_LINE_BITS_L2+3];
            temp_idx    = lsq_store_dc.addr[`DCACHE_LINE_BITS_L2+2:3];
            if (next_valids[temp_idx][0] && next_tags[temp_idx][0] == temp_tag) begin
                temp_valid              = 1'b1;
                temp_value              = next_data[temp_idx][0];
                casez (lsq_store_dc.mem_size)
                    BYTE: temp_value.byte_level[lsq_store_dc.addr[2:0]] = lsq_store_dc.value[7:0];
                    HALF: temp_value.half_level[lsq_store_dc.addr[2:1]] = lsq_store_dc.value[15:0];
                    WORD: temp_value.word_level[lsq_store_dc.addr[2]]   = lsq_store_dc.value[31:0];
                endcase
                next_data[temp_idx][0]  = temp_value;
            end else if (next_valids[temp_idx][1] && next_tags[temp_idx][1] == temp_tag) begin
                temp_valid                  = 1'b1;
                temp_value                  = next_data[temp_idx][1];
                casez (lsq_store_dc.mem_size)
                    BYTE: temp_value.byte_level[lsq_store_dc.addr[2:0]] = lsq_store_dc.value[7:0];
                    HALF: temp_value.half_level[lsq_store_dc.addr[2:1]] = lsq_store_dc.value[15:0];
                    WORD: temp_value.word_level[lsq_store_dc.addr[2]]   = lsq_store_dc.value[31:0];
                endcase
                next_data[temp_idx]         = {next_data[temp_idx][0], temp_value};
                next_tags[temp_idx]         = {next_tags[temp_idx][0], temp_tag};
                next_valids[temp_idx]       = {next_valids[temp_idx][0], 1'b1};
            end else begin
                for (int i = 0; i < `VICTIM_CACHE_LINES_L2; i += 1) begin
                    if (~temp_valid && next_victim_valid[i] && next_victim_addr[i] == lsq_store_dc.addr[15:3]) begin
                        temp_valid              = 1'b1;
                        temp_value              = next_victim_data[i];
                        casez (lsq_store_dc.mem_size)
                            BYTE: temp_value.byte_level[lsq_store_dc.addr[2:0]] = lsq_store_dc.value[7:0];
                            HALF: temp_value.half_level[lsq_store_dc.addr[2:1]] = lsq_store_dc.value[15:0];
                            WORD: temp_value.word_level[lsq_store_dc.addr[2]]   = lsq_store_dc.value[31:0];
                        endcase
                        next_victim_data[i]     = next_data[temp_idx][1];
                        next_victim_addr[i]     = {next_tags[temp_idx][1], temp_idx};
                        next_victim_valid[i]    = next_valids[temp_idx][1];
                        next_victim_head        = next_valids[temp_idx][1] ? (i+1) : i;
                        next_data[temp_idx]     = {next_data[temp_idx][0], temp_value};
                        next_tags[temp_idx]     = {next_tags[temp_idx][0], temp_tag};
                        next_valids[temp_idx]   = {next_valids[temp_idx][0], 1'b1};
                    end
                end
            end

            if (temp_valid) begin
                temp_valid = 1'b0;
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (~temp_valid && next_miss_entries[i].valid && ~next_miss_entries[i].sent && 
                        next_miss_entries[i].addr[15:3] == lsq_store_dc.addr[15:3] && next_miss_entries[i].op) begin
                        next_miss_entries[i].value = temp_value.double_level;
                        temp_valid = 1'b1;
                        dc_store_lsq.valid = 1'b1;
                    end
                end
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (~temp_valid && next_miss_entries[i].valid == 1'b0) begin
                        temp_valid  = 1'b1;
                        next_miss_entries[i] = {    1'b1,
                                                    1'b0,
                                                    4'b0000,
                                                    lsq_store_dc.addr[15:0],
                                                    temp_value.double_level,
                                                    lsq_store_dc.mem_size,
                                                    1'b1    };
                        dc_store_lsq.valid = 1'b1;
                    end
                end

            end else begin
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (next_miss_entries[i].valid && next_miss_entries[i].addr[15:3] == lsq_store_dc.addr[15:3] && ~next_miss_entries[i].op) begin
                        temp_valid      = 1'b1;
                    end
                end
                if (~temp_valid) begin
                    for (int i = 0; i < `MISS_LINES; i += 1) begin
                        if (~temp_valid && next_miss_entries[i].valid == 1'b0) begin
                            temp_valid  = 1'b1;
                            next_miss_entries[i] = {    1'b1,
                                                        1'b0,
                                                        4'b0000,
                                                        lsq_store_dc.addr[15:0],
                                                        64'b0,
                                                        lsq_store_dc.mem_size,
                                                        1'b0    };
                        end
                    end
                end
            end
        end

        proc2Dmem_valid             = 1'b0;
        proc2Dmem_data              = 64'b0;
        proc2Dmem_command           = BUS_NONE;
        proc2Dmem_addr              = `XLEN'b0;

        temp_valid = 1'b0;
        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (~temp_valid && next_miss_entries[i].valid && ~next_miss_entries[i].sent && next_miss_entries[i].op) begin
                next_miss_entries[i].sent   = chosen2Mem && (Dmem2proc_response != 4'b0);
                proc2Dmem_valid             = 1'b1;
                proc2Dmem_data              = next_miss_entries[i].value;
                proc2Dmem_command           = BUS_STORE;
                proc2Dmem_addr              = {16'b0, next_miss_entries[i].addr[15:3], 3'b0};
                next_miss_entries[i].tag    = Dmem2proc_response;
                temp_valid                  = 1'b1;
            end
        end
        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (~temp_valid && next_miss_entries[i].valid && ~next_miss_entries[i].sent) begin
                next_miss_entries[i].sent   = chosen2Mem && (Dmem2proc_response != 4'b0);
                proc2Dmem_valid             = 1'b1;
                proc2Dmem_data              = next_miss_entries[i].value;
                proc2Dmem_command           = BUS_LOAD;
                proc2Dmem_addr              = {16'b0, next_miss_entries[i].addr[15:3], 3'b0};
                next_miss_entries[i].tag    = Dmem2proc_response;
                temp_valid                  = 1'b1;
            end
        end

        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (next_miss_entries[i].valid && next_miss_entries[i].op && ~next_miss_entries[i].sent) begin
                dc_store_lsq.valid = 1'b0;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            data            <=  `SD 0;
            tags            <=  `SD 0;
            valids          <=  `SD 0;
            victim_data     <=  `SD 0;
            victim_addr     <=  `SD 0;
            victim_valid    <=  `SD 0;
            victim_head     <=  `SD 0;
            miss_entries    <=  `SD 0;
        end else begin
            data            <=  `SD next_data;
            tags            <=  `SD next_tags;
            valids          <=  `SD next_valids;
            victim_data     <=  `SD next_victim_data;
            victim_addr     <=  `SD next_victim_addr;
            victim_valid    <=  `SD next_victim_valid;
            victim_head     <=  `SD next_victim_head;
            miss_entries    <=  `SD next_miss_entries;
        end
    end
endmodule

`endif //__DCACHE_L2_V__
