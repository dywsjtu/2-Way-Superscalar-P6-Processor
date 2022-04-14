/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv  (write through)                          //
//                                                                     //
//  Description :  data cache;                                         // 
/////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_IN_V__
`define __DCACHE_IN_V__
`timescale 1ns/100ps

module dcahce_in (
    input   logic                   clock,
    input   logic                   reset,

    input   logic                   read_en,
    input   logic                   [`XLEN-1:0] read_addr,

    input   logic                   write_en,
    input   logic                   [`XLEN-1:0] write_addr,
    input   MEM_SIZE		        write_mem_size, 
    input   logic [`XLEN-1:0]       write_data_in,

    input   logic                   mem_en,
    input   logic [`XLEN-1:0]       mem_addr,
    input   logic [63:0]            mem_data_in,

    output  logic                   read_hit,
    output  logic [63:0]            read_data_out,

    output  EXAMPLE_CACHE_BLOCK     write_data_out,
    output  logic                   write_hit
    );

    //Inside Dcache
    DCACHE_ENTRY_NEW    [`D_CACHE_LINES-1:0]      dcache_entries;

    logic [$clog2(`D_CACHE_LINES)-1:0]    load_idx, store_idx, mem_idx;
    logic [12 - $clog2(`D_CACHE_LINES):0] load_tag, store_tag, mem_tag;

    assign {load_tag, load_idx} = read_addr[15:3];
    assign {store_tag, store_idx} = write_addr[15:3];
    assign {mem_tag, mem_idx} = mem_addr[15:3];

    // assign read_hit  = read_en && ((dcache_entries[load_idx].valid && dcache_entries[load_idx].tag == load_tag)
    //                                 || (write_hit && load_idx == store_idx && load_tag == store_tag)) ;
    assign write_hit = dcache_entries[store_idx].valid && dcache_entries[store_idx].tag == store_tag && write_en &&
                       (~mem_en || (store_idx != mem_idx));
    // assign read_data_out = (read_en && dcache_entries[load_idx].valid && dcache_entries[load_idx].tag == load_tag) ? dcache_entries[load_idx].data : 
    //                        (read_en && write_hit && load_idx == store_idx && load_tag == store_tag) ? write_data_out: 64'b0;

    always_comb begin
        read_hit = 1'b0;
        read_data_out = 64'b0;
        if (read_en) begin
            if (dcache_entries[load_idx].valid && dcache_entries[load_idx].tag == load_tag) begin
                read_hit = 1'b1;
                read_data_out = dcache_entries[load_idx].data;
            end else if (mem_en && mem_idx == load_idx && load_tag == mem_tag) begin
                read_hit = 1'b1;
                read_data_out = mem_data_in;
            end else if (write_hit && store_idx == load_idx && load_tag == store_tag) begin
                read_hit = 1'b1;
                read_data_out = write_data_out;
            end
        end
    end

    //Write
    always_comb begin
        write_data_out = 64'b0;
        if (write_hit) begin
            write_data_out = dcache_entries[store_idx].data;
            casez (write_mem_size)
                BYTE: write_data_out.byte_level[write_addr[2:0]]    = write_data_in[7:0];
                HALF: write_data_out.half_level[write_addr[2:1]]    = write_data_in[15:0];
                WORD: write_data_out.word_level[write_addr[2]]      = write_data_in[31:0];
            endcase
        end
    end

   
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            dcache_entries <= `SD 0;
        end else begin
            if (mem_en) begin
                dcache_entries[mem_idx].data <= `SD mem_data_in;
                dcache_entries[mem_idx].valid <= `SD 1'b1;
                dcache_entries[mem_idx].tag   <= `SD mem_tag;
            end
            if (write_hit) begin
                casez (write_mem_size)
                    BYTE: dcache_entries[store_idx].data.byte_level[write_addr[2:0]]    <= `SD write_data_in[7:0];
                    HALF: dcache_entries[store_idx].data.half_level[write_addr[2:1]]    <= `SD write_data_in[15:0];
                    WORD: dcache_entries[store_idx].data.word_level[write_addr[2]]      <= `SD write_data_in[31:0];
                endcase
                dcache_entries[store_idx].valid     <= `SD 1'b1;
                dcache_entries[store_idx].tag       <= `SD store_tag;
            end 
        end
        
    end

    `ifdef DEBUG
    logic [31:0] cycle_count;
    DCACHE_ENTRY_NEW cur_entry;
    // synopsys sync_set_reset "reset"
    always_ff @(negedge clock) begin
        if(reset) begin
            cycle_count = 0;
        end else begin
            for(int i = 0; i < `CACHE_LINES; i += 1) begin
                cur_entry = dcache_entries[i];
                $display("DEBUG %4d: dcache[%2d] = 0x%x, valid[%2d]=%b", cycle_count, i, cur_entry.data.double_level, i, cur_entry.valid);
            end
            cycle_count = cycle_count + 1;
        end
    end
    `endif

endmodule
`endif