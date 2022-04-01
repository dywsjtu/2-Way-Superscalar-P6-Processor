module testbench;
    logic clock, reset,read_en, write_en, Dcache_valid_out, write_done;
    logic [3:0] Dmem2proc_response, Dmem2proc_tag;
    logic [63:0] Dmem2proc_data, proc2Dcache_data, Dcache_data_out, proc2Dmem_data;
    logic [`XLEN-1:0] proc2Dcache_addr, proc2Dmem_addr, read_addr, write_addr;
    logic [1:0] proc2Dmem_command;
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

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

   

    assign proc2Dcache_addr = (read_en)  ? read_addr :
                              (write_en) ? write_addr : 32'b0;
                            

    dcache dcache_(
    .clock(clock),
    .reset(reset),

    //Feedback from Dmem
    .Dmem2proc_response(mem2proc_response),
    .Dmem2proc_data(mem2proc_data),
    .Dmem2proc_tag(mem2proc_tag),

    //Control signals
    .read_en(read_en), 
    .write_en(write_en),

    // Address
    .proc2Dcache_addr(proc2Dcache_addr), //MUX logic outside

    // Write data
    .proc2Dcache_data(proc2Dcache_data), 

    //Load output
    .Dcache_data_out(Dcache_data_out), // value is memory[proc2Dcache_addr]
    .Dcache_valid_out(Dcache_valid_out),      // when this is high

    .write_done(write_done),

    //Output to Dmem
    .proc2Dmem_command(proc2Dmem_command),
    .proc2Dmem_addr(proc2Dmem_addr),
    .proc2Dmem_data(proc2Dmem_data)
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
      // read_en = 1;
      // write_en = 0;
      // read_addr = 8;
      // @(negedge clock);
      // #1;
      // check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      // read_en = 0;
      // mem_wait;
      // read_en = 1;
      // read_addr = 8;
      // @(negedge clock);
      // #1;
      // check(Dcache_data_out,64'b0,Dcache_valid_out,1);
      // #1;
      
      //Write to dcache
      read_en = 0;
      write_en = 1;
      write_addr = 16;
      proc2Dcache_data = 107;
      @(negedge clock);
      #1;
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      mem_wait;
      show_mem_with_decimal(16,16);
      //show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
        
      //Check for write
      read_en = 1;
      write_en = 0;
      read_addr = 16;
      @(negedge clock);
      #1;
      check(Dcache_data_out,107,Dcache_valid_out,1);

      //Write to dcache
      write_en = 1;
      read_en = 0;
      write_addr = 2832;
      proc2Dcache_data = 1122;
      @(negedge clock);
      #1;
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      mem_wait;

      //Check write
      read_en = 1;
      write_en = 0;
      read_addr = 2832;
      @(negedge clock);
      #1;
      check(Dcache_data_out,1122,Dcache_valid_out,1);

      //Check for dirty
      write_en = 1;
      read_en = 0;
      write_addr = 16;
      proc2Dcache_data = 107;
      @(negedge clock);
      #1;
      check(Dcache_data_out,64'b0,Dcache_valid_out,0); //dirty bit = 0
      mem_wait;

      write_en = 1;
      read_en = 0;
      write_addr = 16;
      proc2Dcache_data = 806;
      @(negedge clock);
      #1;
      check(Dcache_data_out,64'b0,Dcache_valid_out,0); //dirty bit = 1
      mem_wait;
     
      /*CHECK LRU*/ 
      write_en = 1;
      read_en = 0;
      write_addr = 4112;
      proc2Dcache_data = 1027;
      @(negedge clock);
      #1;
      mem_wait;

      //Check write
      read_en = 1;
      write_en = 0;
      read_addr = 2832; //replaced
      @(negedge clock);
      #1;
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);

      read_en = 1;
      write_en = 0;
      read_addr = 4112;
      @(negedge clock);
      #1;
      check(Dcache_data_out,1027,Dcache_valid_out,1);
      



      //Check for defering write


        



      $display("@@@Passed");
      $finish;

    end

endmodule