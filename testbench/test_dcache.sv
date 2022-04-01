module testbench;
    logic clock, reset,read_en, write_en, Dcache_valid_out, write_done;
    logic [3:0] Dmem2proc_response, Dmem2proc_tag;
    logic [63:0] Dmem2proc_data, proc2Dcache_data, Dcache_data_out, proc2Dmem_data;
    logic [`XLEN-1:0] proc2Dcache_addr, proc2Dmem_addr, read_addr, write_addr;
    logic [1:0] proc2Dmem_command;
    mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
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
    .Dmem2proc_response(Dmem2proc_response),
    .Dmem2proc_data(Dmem2proc_data),
    .Dmem2proc_tag(Dmem2proc_tag),

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
      $display("Dcache_out = %d, hit = %d", data,hit);
      if (data != data_ground || hit != hit_ground) begin
        // $display("Dcache_out = %d, hit = %d", data,hit);
        $display("Dcache_ground = %d, hit_ground = %d", data_ground,hit_ground);
        exit_on_error;
      end
    end
    endtask

    always #5 clock = ~clock;
    initial begin

      clock = 0;
      reset = 0;
      @(negedge clock);
      reset = 1;
      @(negedge clock);
      reset = 0;

      /*READ ONLY + WRITE ONLY*/
    
      read_addr = 8;
      read_en = 1;
      @(negedge clock);
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      mem_wait; //Wait for mem
      check(Dcache_data_out,64'b0,Dcache_valid_out,1);

      //Write to dcache
      read_en = 0;
      write_en = 1;
      write_addr = 16;
      proc2Dcache_data = 107;
      @(negedge clock);
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      mem_wait;
        
      //Check for write
      read_en = 1;
      write_en = 0;
      read_addr = 16;
      @(negedge clock);
      check(Dcache_data_out,107,Dcache_valid_out,1);

      //Write to dcache
      write_en = 1;
      read_en = 0;
      write_addr = 2832;
      proc2Dcache_data = 1122;
      @(negedge clock);
      check(Dcache_data_out,64'b0,Dcache_valid_out,0);
      mem_wait;

      //Check write
      read_en = 1;
      write_en = 0;
      read_addr = 2832;
      @(negedge clock);
      // check(Dcache_data_out,1123,Dcache_valid_out,1);
      $display("Data_out = %d", Dcache_data_out);
      if (Dcache_data_out == 1123) begin
        exit_on_error;
      end



      //Check for defering write


        



      $display("@@@Passed");
      $finish;

    end

endmodule