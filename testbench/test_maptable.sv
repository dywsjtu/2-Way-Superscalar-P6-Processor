module testbench;

    logic clock, reset, clear, flush;
    logic [$clog2(`REG_SIZE)-1:0] rs1_dispatch, rs2_dispatch, rd_retire, rd_dispatch;
    logic [$clog2(`ROB_SIZE+1)-1:0] rs1_tag, rs2_tag, ROB_idx, CDB_tag;
    logic rs1_ready, rs2_ready;

    maptable test_map (.clock(clock),
    .reset(reset),
    .ROB_idx(ROB_idx),
    .rd_dispatch(rd_dispatch),
    .CDB_tag(CDB_tag),
    .rs1_dispatch(rs1_dispatch),
    .rs2_dispatch(rs2_dispatch),
    .rd_retire(rd_retire),
    .clear(clear),
    .flush(flush),

    .rs1_tag(rs1_tag),
    .rs2_tag(rs2_tag),
    .rs1_ready(rs1_ready),
    .rs2_ready(rs2_ready)
    );

    always #5 clock = ~clock;
    task exit_on_error;
		begin
			#1;
			$display("@@@Failed at time %f", $time);
			$finish;
		end
	endtask

    initial begin
        clock = 0;

        /**RESET TEST**/
        reset = 1;
        flush = 0;
        @(negedge clock);

        //all tag = 0 and not ready
        for(int i=0; i<`REG_SIZE; i++) begin
            rs1_dispatch = i;
            if (rs1_tag != 0 | rs1_ready) begin
                $display("@@@Reset Error");
                exit_on_error;
            end
        end

        reset = 0;

        /**Dispatch TEST**/
        rd_dispatch = 15;
        ROB_idx = 1;
        @(negedge clock);
        rd_dispatch = 11;
        ROB_idx = 2;
        @(negedge clock);

        #1
        for(int i=0; i<`REG_SIZE; i++) begin
            rs1_dispatch = i;
            if (rs1_dispatch == 11) begin
                if (rs1_tag != 2 | rs1_ready) begin 
                    $display("@@@Dispatch Error");
                    exit_on_error;
                end
            end
            else if (rs1_dispatch == 15) begin
                if (rs1_tag != 1 | rs1_ready) begin 
                    $display("@@@Dispatch Error");
                    exit_on_error;
                end
            end
            else begin
                if (rs1_tag != 0 | rs1_ready) begin
                    $display("@@@Dispatch Error");
                    exit_on_error;
                end
            end
        end 
        

        /**COMPLETE TEST**/
        rd_dispatch = 31;
        ROB_idx = 3;
        @(negedge clock);
        rd_dispatch = 7;
        ROB_idx = 4;
        @(negedge clock);

        //ROB#2 is completed
        CDB_tag = 2;
        rs2_dispatch = 11;
        #1
        if (rs2_tag != 2 | ~rs2_ready) begin
            $display("@@@Complete Error 1");
            exit_on_error;
        end
        @(negedge clock);

        //ROB#3 is completed
        CDB_tag = 3;
        rs1_dispatch = 31;
        #1
        if (rs1_tag != 3 | ~rs1_ready) begin
            $display("@@@Complete Error 2");
            exit_on_error;
        end
        @(negedge clock);
        
        //ROB#5 is completed +  ROB#5 is not in MapTable
        CDB_tag = 5;
        rs2_dispatch = 7;
        #1
        if (rs2_tag != 4 | rs2_ready) begin
            $display("@@@Complete Error 3");
            exit_on_error;
        end

        /**RETIRE TESET**/
        //retire reg[31]
        clear = 1;
        rd_retire = 31;
        rs1_dispatch = 31;
        rs2_dispatch = 11;
        @(negedge clock);
        if (rs1_tag !=0 | rs1_ready | rs2_tag != 2| ~rs2_ready) begin
            $display("@@@Retire Error 1");
            exit_on_error;
        end
        @(negedge clock);

        clear = 0;
        @(negedge clock);
        //no instruction retire
        #1
        for(int i=0; i<`REG_SIZE; i++) begin
            rs1_dispatch = i;
            if (rs1_dispatch == 7) begin //dispatched
                if (rs1_tag != 4 | rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else if (rs1_dispatch == 11) begin // completed
                if (rs1_tag != 2 | ~rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else if (rs1_dispatch == 15) begin //dispatched
                if (rs1_tag != 1 | rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else begin
                if (rs1_tag != 0 | rs1_ready) begin
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
        end

        //retire reg[11]
        clear = 1;
        rd_retire = 11;
        @(negedge clock);
        if (rs1_tag !=0 | rs1_ready | rs2_tag != 0| rs2_ready) begin
            $display("@@@Retire Error 3");
            exit_on_error;
        end

        /**FLUSH TEST**/
        flush = 1;
        reset = 0;
        @(negedge clock);

        //all tag = 0 and not ready
        for(int i=0; i<`REG_SIZE; i++) begin
            rs1_dispatch = i;
            if (rs1_tag != 0 | rs1_ready) begin
                $display("@@@Flush Error");
                exit_on_error;
            end
        end

     $display("@@@Passed");
     $finish;

    end
    

endmodule
