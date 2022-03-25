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

        //check for read
        read_en = 1;
        branchPC = 32'h0acb_0040;
        check(targetPC,hit,32'b0,0);
        @(negedge clock);

        //check for write
        read_en = 0;    
        write_en = 1;  
        PC_in = 32'h0806_002C;
        data_in = 32'h1122_1320;
        @(negedge clock);
        @(negedge clock);
        
        //check(targetPC,hit,{branchPC[31:13],313,2'b0},1);
        read_en = 1;
        write_en = 0;
        branchPC = 32'h0806_002C;
        @(negedge clock);
        check(targetPC,hit,32'h1122_1320,1);
        write_en = 1; 
        
        
        $display("@@@Passed");
        $finish;

    end
endmodule