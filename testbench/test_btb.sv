module testbench;
    logic clock,reset, read_en, write_en, hit;
    logic [31:0] branchPC, PC_in, targetPC;
    logic [31:0] data_in;
    btb btb0(
    //INPUT
    .clock(clock),
    .reset(reset),
    //Read from BTB
    .read_en(read_en),
    .branchPC(branchPC),
    //Write into BTB
    .write_en(write_en),     
    .data_in(data_in),
    .PC_in(PC_in),
    //OUTPUT
    .targetPC(targetPC),
    .hit(hit)
    );

    always #5 clock = ~clock;

    task result_display;
        $display("targetPC  = 0x%x", targetPC);
        $display("hit = %d", hit);
    endtask

    task exit_on_error;
    begin
        $display("@@@Failed at time %f", $time);
        $finish;
    end
    endtask

    task check;
        input logic [31:0] targetPC;
        input logic hit;
        input logic [31:0] gt_targetPC;
        input logic gt_hit;
        if (targetPC != gt_targetPC | hit != gt_hit)
        begin
            $display("targetPC  = 0x%x, gt_targetPC = 0x%x", targetPC, gt_targetPC);
            $display("hit = %d, gt_hit = %d", hit, gt_hit);
            exit_on_error;
        end
    endtask

    initial begin
        clock = 1;
        @(negedge clock);
        reset = 1;
        @(negedge clock); 
        @(negedge clock);
        reset = 0;

        /*CHECK READ FOR NOT HIT*/
        read_en = 1;
        branchPC = 32'h0acb_0040;
        check(targetPC,hit,32'b0,0);
        @(negedge clock);

        /*CHECK WRITE*/
        //input datat is not in BTB
        read_en = 0;    
        write_en = 1;  
        PC_in = 32'h0806_002C;
        data_in = 32'h1122_1320;
        @(negedge clock);
        //input data is already in BTB
        @(negedge clock);
        //check the BTB output here 
        
        /*CHECK READ FOR HIT*/
        read_en = 1;
        write_en = 0;
        branchPC = 32'h0806_002C;
        @(negedge clock);
        check(targetPC,hit,32'h1122_1320,1);
        @(negedge clock);

        //Same index, but save in the other block
        read_en = 0;    
        write_en = 1;  
        PC_in = 32'h1027_00E8;
        data_in = 32'h0313_0575;
        @(negedge clock);
        
        read_en = 1;
        write_en = 0;
        branchPC = 32'h0806_002C;
        @(negedge clock);
        check(targetPC,hit,32'h1122_1320,1);
       
        read_en = 1;
        write_en = 0;
        branchPC = 32'h1027_00E8;
        @(negedge clock);
        check(targetPC,hit,32'h0313_0575,1);

        /*CHECK FOR OVERWRITE*/
        read_en = 0;    
        write_en = 1;  
        PC_in = 32'h0750_002C;
        data_in = 32'hAC2D_7569;
        @(negedge clock);

        read_en = 1;
        write_en = 0;
        branchPC = 32'h1027_00E8;
        @(negedge clock);
        check(targetPC,hit,32'h0313_0575,1);

        read_en = 1;
        write_en = 0;
        branchPC = 32'h0806_002C;
        @(negedge clock);
        check(targetPC,hit,32'b0,0);

        
        
        $display("@@@Passed");
        $finish;

    end
endmodule