/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_V__
`define __DCACHE_V__

`timescale 1ns/100ps


module dcache (
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

    DCACHE_ENTRY    [`CACHE_LINES-1:0]      dcache_entries;
    DCACHE_ENTRY    [`CACHE_LINES-1:0]      next_dcache_entries;

    MISS_ENTRY      [`MISS_LINES-1:0]       miss_entries;
    MISS_ENTRY      [`MISS_LINES-1:0]       next_miss_entries;
    
    // DEBUG show the icache state
    `ifdef DEBUG
    logic [31:0] cycle_count;
    DCACHE_ENTRY cur_entry;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `CACHE_LINES; i += 1) begin
                cur_entry = dcache_entries[i];
                $display("DEBUG %4d: dcache[%2d] = %p", cycle_count, i, cur_entry);
            end
            cycle_count = cycle_count + 1;
        end
    end
    `endif

    // DCACHE_LOAD_LSQ_PACKET                  next_dc_load_lsq;
    // DCACHE_STORE_LSQ_PACKET                 next_dc_store_lsq;

    logic                                   temp_valid;
    EXAMPLE_CACHE_BLOCK                     temp_value;
    logic           [13:0]                  temp_addr;
    logic                                   temp_op;
    logic           [`CACHE_IDX_LEN-1:0]    temp_minus;

    always_comb begin
        dc_load_lsq.valid       = 1'b0;
        dc_load_lsq.value       = `XLEN'b0;
        dc_store_lsq.valid      = 1'b0;
        dc_store_lsq.halt_valid = 1'b0;
        next_dcache_entries     = dcache_entries;
        next_miss_entries       = miss_entries;

        temp_valid  = 1'b0;
        temp_minus  = `CACHE_IDX_LEN'b0;
        temp_addr   = 14'b0;
        temp_value  = 64'b0;
        temp_op     = 1'b0;

        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (miss_entries[i].valid && miss_entries[i].sent && miss_entries[i].op) begin
                next_miss_entries[i] = 0;
            end
        end

        if (Dmem2proc_valid) begin
            for (int i = 0; i < `MISS_LINES; i += 1) begin
                // if (miss_entries[i].valid && miss_entries[i].sent && miss_entries[i].op) begin
                //     next_miss_entries[i] = 0;
                // end else 
                if (~temp_valid && next_miss_entries[i].valid && next_miss_entries[i].sent && next_miss_entries[i].tag == Dmem2proc_tag) begin
                    temp_valid  = 1'b1;
                    temp_value  = Dmem2proc_data;
                    temp_addr   = {1'b1, next_miss_entries[i].addr[15:3]};
                    temp_op     = next_miss_entries[i].op;
                    next_miss_entries[i].valid  = 1'b0;
                end
            end
            if (temp_valid && ~temp_op) begin
                temp_valid = 1'b0;
                for (int i = 0; i < `CACHE_LINES; i += 1) begin
                    if (~temp_valid && next_dcache_entries[i].lru_counter == `CACHE_IDX_LEN'b0) begin
                        temp_valid = 1'b1;
                        next_dcache_entries[i] = {  temp_value,
                                                    temp_addr[12:0],
                                                    `CACHE_IDX_LEN'b011111,
                                                    1'b1    };
                    end else if (next_dcache_entries[i].lru_counter != `CACHE_IDX_LEN'b0) begin
                        next_dcache_entries[i].lru_counter = next_dcache_entries[i].lru_counter - 1;
                    end
                end
            end
        end

        if (lsq_load_dc.valid && (~lsq_store_dc.valid || ~lsq_store_dc.halt)) begin
            temp_valid = 1'b0;
            temp_minus = `CACHE_IDX_LEN'b100000;
            for (int i = 0; i < `CACHE_LINES; i += 1) begin
                // match cache
                if (next_dcache_entries[i].valid && (next_dcache_entries[i].addr == lsq_load_dc.addr[15:3])) begin
                    dc_load_lsq.valid   = 1'b1;
                    casez (lsq_load_dc.mem_size)
                        BYTE: dc_load_lsq.value = {24'b0,   next_dcache_entries[i].data.byte_level[lsq_load_dc.addr[2:0]]};
                        HALF: dc_load_lsq.value = {16'b0,   next_dcache_entries[i].data.half_level[lsq_load_dc.addr[2:1]]};
                        WORD: dc_load_lsq.value =           next_dcache_entries[i].data.word_level[lsq_load_dc.addr[2]];
                    endcase                   
                    temp_valid = 1'b1;
                    temp_minus = next_dcache_entries[i].lru_counter;
                    next_dcache_entries[i].lru_counter = `CACHE_IDX_LEN'b100000;
                end
            end
            for (int i = 0; i < `CACHE_LINES; i += 1) begin
                next_dcache_entries[i].lru_counter = next_dcache_entries[i].lru_counter - 
                                                     (next_dcache_entries[i].lru_counter > temp_minus ? `CACHE_IDX_LEN'b1 : `CACHE_IDX_LEN'b0);
            end
            if (~temp_valid) begin
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
        if (lsq_store_dc.valid && ~lsq_store_dc.halt && (~temp_addr[13] || (lsq_store_dc.addr[15:3] != temp_addr[12:0]))) begin
            temp_valid = 1'b0;
            temp_minus = `CACHE_IDX_LEN'b100000;
            for (int i = 0; i < `CACHE_LINES; i += 1) begin
                // match cache
                if (next_dcache_entries[i].valid && (next_dcache_entries[i].addr == lsq_store_dc.addr[15:3])) begin
                    casez (lsq_store_dc.mem_size)
                        BYTE: next_dcache_entries[i].data.byte_level[lsq_store_dc.addr[2:0]]    = lsq_store_dc.value[7:0];
                        HALF: next_dcache_entries[i].data.half_level[lsq_store_dc.addr[2:1]]    = lsq_store_dc.value[15:0];
                        WORD: next_dcache_entries[i].data.word_level[lsq_store_dc.addr[2]]      = lsq_store_dc.value[31:0];
                    endcase
                    temp_valid = 1'b1;
                    temp_value = next_dcache_entries[i].data.double_level;
                    temp_minus = next_dcache_entries[i].lru_counter;
                    next_dcache_entries[i].lru_counter = `CACHE_IDX_LEN'b100000;
                end
            end
            for (int i = 0; i < `CACHE_LINES; i += 1) begin
                next_dcache_entries[i].lru_counter = next_dcache_entries[i].lru_counter - 
                                                     (next_dcache_entries[i].lru_counter > temp_minus ? `CACHE_IDX_LEN'b1 : `CACHE_IDX_LEN'b0);
            end
            if (temp_valid) begin
                temp_valid = 1'b0;
                for (int i = 0; i < `MISS_LINES; i += 1) begin
                    if (~temp_valid && next_miss_entries[i].valid == 1'b1 && next_miss_entries[i].sent == 1'b0 && 
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

        dc_store_lsq.halt_valid = 1'b1;
        for (int i = 0; i < `MISS_LINES; i += 1) begin
            if (next_miss_entries[i].valid && next_miss_entries[i].op && ~next_miss_entries[i].sent) begin
                dc_store_lsq.halt_valid = 1'b0;
                dc_store_lsq.valid = 1'b0;
            end
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            dcache_entries      <=  `SD 0;
            miss_entries        <=  `SD 0;
        end else begin
            dcache_entries      <=  `SD next_dcache_entries;
            miss_entries        <=  `SD next_miss_entries;
        end
    end
endmodule

`endif //__DCACHE_V__
