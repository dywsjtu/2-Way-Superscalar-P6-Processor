module testbench;

    logic clock, reset, clear,dispatch_enable;
    logic [$clog2(`REG_SIZE)-1:0] rd_retire, rd_dispatch;
    RS_MT_PACKET rs_mt;
    logic [`ROB_IDX_LEN:0] CDB_tag;
    MT_RS_PACKET mt_rs;
    ROB_MT_PACKET rob_mt;

    map_table test_map (.clock(clock),
    .reset(reset),
    .rob_mt(rob_mt),
    .rd_dispatch(rd_dispatch),
    .CDB_tag(CDB_tag),
    .rs_mt(rs_mt),
    .rd_retire(rd_retire),
    .clear(clear),
    .dispatch_enable(dispatch_enable),
    .mt_rs(mt_rs)
    );

    always #5 clock = ~clock;
    task exit_on_error;
		begin
			#1;
			$display("@@@Failed at time %f", $time);
			$finish;
		end
	endtask
    
    task check_rf;
        for(int i=0; i<`REG_SIZE; i++) begin
                rs_mt.rs1_dispatch = i;
                if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready) begin
                    $display("@@@Reset Error");
                    exit_on_error;
                end
        end
    endtask

    initial begin
        clock = 0;

        /**RESET TEST**/
        reset = 1;
        rob_mt.squash = 0;
        @(negedge clock);
        check_rf;
        reset = 0;

        /**Dispatch TEST**/
        dispatch_enable = 1;
        rd_dispatch = 15;
        rob_mt.rob_tail = 1;
        @(negedge clock);
        dispatch_enable = 0;
        rd_dispatch = 11;
        rob_mt.rob_tail = 2;
        @(negedge clock);

        #1
        for(int i=0; i<`REG_SIZE; i++) begin
            rs_mt.rs1_dispatch = i;
            #1
            if (rs_mt.rs1_dispatch == 11) begin
                if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready) begin
                    $display("@@@Dispatch Error 11");
                    exit_on_error;
                end
            end
            else if (rs_mt.rs1_dispatch == 15) begin
                if (mt_rs.rs1_tag != 1 | mt_rs.rs1_ready) begin 
                    $display("@@@Dispatch Error");
                    exit_on_error;
                end
            end
            else begin
                if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready) begin
                    $display("@@@Dispatch Error");
                    exit_on_error;
                end
            end

        end 

        rd_dispatch = 11;
        rob_mt.rob_tail = 2;
        dispatch_enable = 1;
        @(negedge clock);
        rs_mt.rs1_dispatch = 11;
        #1
        if (mt_rs.rs1_tag != 2 | mt_rs.rs1_ready) begin
            $display("@@@Dispatch Error 1");
            exit_on_error;
        end
        

        /**COMPLETE TEST**/
        dispatch_enable = 1;
        rd_dispatch = 31;
        rob_mt.rob_tail = 3;
        @(negedge clock);
        dispatch_enable = 1;
        rd_dispatch = 7;
        rob_mt.rob_tail = 4;
        @(negedge clock);

        //ROB#2 is completed
        CDB_tag = 2;
        rs_mt.rs2_dispatch = 11;
        #1
        if (mt_rs.rs2_tag != 2 | ~mt_rs.rs2_ready) begin
            $display("@@@Complete Error 1");
            exit_on_error;
        end
        @(negedge clock);

        //ROB#3 is completed
        CDB_tag = 3;
        rs_mt.rs1_dispatch = 31;
        #1
        if (mt_rs.rs1_tag != 3 | ~mt_rs.rs1_ready) begin
            $display("@@@Complete Error 2");
            exit_on_error;
        end
        @(negedge clock);
        
        //ROB#5 is completed +  ROB#5 is not in MapTable
        CDB_tag = 5;
        rs_mt.rs2_dispatch = 7;
        #1
        if (mt_rs.rs2_tag != 4 | mt_rs.rs2_ready) begin
            $display("@@@Complete Error 3");
            exit_on_error;
        end

        /**RETIRE TESET**/
        //retire reg[31]
        clear = 1;
        rd_retire = 31;
        rs_mt.rs1_dispatch = 31;
        rs_mt.rs2_dispatch = 11;
        @(negedge clock);
        if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready | mt_rs.rs2_tag != 2| ~mt_rs.rs2_ready) begin
            $display("@@@Retire Error 1");
            exit_on_error;
        end
        @(negedge clock);

        clear = 0;
        @(negedge clock);
        //no instruction retire
        #1
        for(int i=0; i<`REG_SIZE; i++) begin
            rs_mt.rs1_dispatch = i;
            #1
            if (rs_mt.rs1_dispatch == 7) begin //dispatched
                if (mt_rs.rs1_tag != 4 | mt_rs.rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else if (rs_mt.rs1_dispatch == 11) begin // completed
                if (mt_rs.rs1_tag != 2 | ~mt_rs.rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else if (rs_mt.rs1_dispatch == 15) begin //dispatched
                if (mt_rs.rs1_tag != 1 | mt_rs.rs1_ready) begin 
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
            else begin
                if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready) begin
                    $display("@@@Retire Error");
                    exit_on_error;
                end
            end
        end

        //retire reg[11]
        clear = 1;
        rd_retire = 11;
        @(negedge clock);
        if (mt_rs.rs1_tag != `ZERO_TAG | mt_rs.rs1_ready | mt_rs.rs2_tag != `ZERO_TAG| mt_rs.rs2_ready) begin
            $display("@@@Retire Error 3");
            exit_on_error;
        end

        /**FLUSH TEST**/
        rob_mt.squash = 1;
        reset = 0;
        @(negedge clock);

        //all tag = 0 and not ready
        check_rf;

     $display("@@@Passed");
     $finish;

    end
    

endmodule