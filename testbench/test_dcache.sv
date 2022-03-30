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

    task exit_on_error;
		begin
			#1;
			$display("@@@Failed at time %f", $time);
			$finish;
		end
	endtask

    always #5 clock = ~clock;
    initial begin

        clock = 0;
        reset = 0;
        @(negedge clock);
        reset = 1;
        @(negedge clock);

        //READ + NO HIT
        read_addr = 8;
        read_en = 1;
        @(negedge clock);
        if (Dcache_data_out != 64'b0 || Dcache_valid_out) begin
            exit_on_error;
        end
        for (int i = 0; i < `MEM_LATENCY_IN_CYCLES; i += 1) begin
            @(negedge clock); //wait to be fetched from mem
        end
        if (~Dcache_valid_out) begin
            exit_on_error;
        end



        //Check for defering write


        



        $display("@@@Passed");
        $finish;

    end

endmodule