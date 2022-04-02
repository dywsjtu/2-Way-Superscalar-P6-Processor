module testbench;
    logic clock, reset, stall;
    logic [3:0] Dmem2proc_response, Dmem2proc_tag;
    logic [`XLEN-1:0] Dmem2proc_data, proc2Dcache_addr, proc2Dmem_addr,proc2Dmem_data;
    logic [1:0] proc2Dmem_command;
    LSQ_LOAD_DCACHE_PACKET lsq_load;
    LSQ_STORE_DCACHE_PACKET lsq_store;
    DCACHE_STORE_LSQ_PACKET dcache_store;
    DCACHE_LOAD_LSQ_PACKET  dcache_load;
    `ifndef CACHE_MODE
	    MEM_SIZE proc2Dmem_size; //BYTE, HALF, WORD or DOUBLE
    `endif
    mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2Dmem_command),
		.proc2mem_addr     (proc2Dmem_addr),
		.proc2mem_data     (proc2Dmem_data),
    `ifndef CACHE_MODE
		  .proc2mem_size     (proc2mem_size),
    `endif

		// Outputs

		.mem2proc_response (Dmem2proc_response),
		.mem2proc_data     (Dmem2proc_data),
		.mem2proc_tag      (Dmem2proc_tag)
	);

   

    dcache dcache_0(
    .clock(clock),
    .reset(reset),
    .stall(stall),

    //From Dmem
    .Dmem2proc_response(Dmem2proc_response),
    .Dmem2proc_data(Dmem2proc_data),
    .Dmem2proc_tag(Dmem2proc_tag),

    //From LSQ
    .lsq_load(lsq_load),
    .lsq_store(lsq_store),

    //To LSQ
    .dcache_store(dcache_store),
    .dcache_load(dcache_load),

    //To Dmem
    `ifndef CACHE_MODE
	    .proc2Dmem_size(proc2Dmem_size), //BYTE, HALF, WORD or DOUBLE
    `endif
    .proc2Dmem_data(proc2Dmem_data),
    .proc2Dmem_command(proc2Dmem_command),
    .proc2Dmem_addr(proc2Dmem_addr)
    );

    task mem_wait;
    begin
      for (int i = 0; i < `MEM_LATENCY_IN_CYCLES; i += 1) begin
          @(negedge clock); //wait to be fetched from mem
      end
    end
    endtask

    task exit_on_error;
		begin
			#1;
			$display("@@@Failed at time %f", $time);
			$finish;
		end
	  endtask

    task check;
      input logic [63:0] data;
      input logic [63:0] data_ground;
      input logic hit;
      input logic hit_ground;
    begin
      //$display("Dcache_out = %d, hit = %d", data,hit);
      if (data != data_ground || hit != hit_ground) begin
        // $display("Dcache_out = %d, hit = %d", data,hit);
        $display("Dcache_ground = %d, hit_ground = %d", data_ground,hit_ground);
        exit_on_error;
      end
    end
    endtask

    	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal

    always #5 clock = ~clock;
    initial begin

      clock = 0;
      reset = 1;
      @(negedge clock);
      reset = 0;

      //Read from mem
      lsq_load.valid = 1;
      lsq_store.valid = 0;
      lsq_load.addr = 8;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,0);
      lsq_load.valid = 0;
      mem_wait;
      lsq_load.valid = 1;
      lsq_load.addr = 8;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,1);
      #1;
      
      //Write to dcache
      lsq_load.valid = 0;
      lsq_store.valid = 1;
      lsq_store.addr = 16;
      lsq_store.value = 107;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,0);
      mem_wait;
      show_mem_with_decimal(16,16);
      //show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
        
      //Check for write
      lsq_load.valid = 1;
      lsq_store.valid = 0;
      lsq_load.addr = 16;
      @(negedge clock);
      #1;
      check(dcache_load.value,107,dcache_load.valid,1);

      //Write to dcache
      lsq_store.valid = 1;
      lsq_load.valid = 0;
      lsq_store.addr = 2832;
      lsq_store.value = 1122;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,0);
      mem_wait;

      //Check write
      lsq_load.valid = 1;
      lsq_store.valid = 0;
      lsq_load.addr = 2832;
      @(negedge clock);
      #1;
      check(dcache_load.value,1122,dcache_load.valid,1);

      //Check for dirty
      lsq_store.valid = 1;
      lsq_load.valid = 0;
      lsq_store.addr = 16;
      lsq_store.value = 107;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,0); //dirty bit = 0
      mem_wait;

      lsq_store.valid = 1;
      lsq_load.valid = 0;
      lsq_store.addr = 16;
      lsq_store.value = 806;
      @(negedge clock);
      #1;
      check(dcache_load.value,64'b0,dcache_load.valid,0); //dirty bit = 1
      mem_wait;
     
      // /*CHECK LRU*/ 
      // lsq_store.valid = 1;
      // lsq_load.valid = 0;
      // lsq_store.addr = 4112;
      // lsq_store.value = 1027;
      // @(negedge clock);
      // #1;
      // mem_wait;

      // //Check write
      // lsq_load.valid = 1;
      // lsq_store.valid = 0;
      // lsq_load.addr = 2832; //replaced
      // @(negedge clock);
      // #1;
      // check(dcache_load.value,64'b0,dcache_load.valid,0);

      // lsq_load.valid = 1;
      // lsq_store.valid = 0;
      // lsq_load.addr = 4112;
      // @(negedge clock);
      // #1;
      // check(dcache_load.value,1027,dcache_load.valid,1);
      



      //Check for defering write


        



      $display("@@@Passed");
      $finish;

    end

endmodule