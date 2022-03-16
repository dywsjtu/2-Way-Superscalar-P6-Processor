module testbench;
    logic reset, clock, squash, full;
    logic [`ROB_IDX_LEN] FU_tag;
    logic [`XLEN-1:0] FU_value;
    CDB_ENTRY cdb_out;

    cdb cdb_test(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .FU_tag(FU_tag),
        .FU_value(FU_value),
        .cdb_out(cdb_out),
        .full(full)
    );

    always #5 clock = ~clock;

    task cdb_display;
        $display("CDB_tag   = %d", cdb_out.tag);
        $display("CDB_value = %d", cdb_out.value);
        //$display("full_signal = %d", full);
    endtask

    task exit_on_error;
  begin
            //cdb_display;
   $display("@@@Failed at time %f", $time);
   $finish;
  end
 endtask

    task check;
        input CDB_ENTRY cdb_out;
        input [`ROB_IDX_LEN:0] gt_tag;
        input [`XLEN-1:0] gt_value;
        //input logic full;
        //input logic gt_full;
        if (cdb_out.value != gt_value | cdb_out.tag != gt_tag)
        begin
            exit_on_error;
        end
    endtask

    initial begin
        clock = 1;
        @(negedge clock);

        /**INSERT CDB TEST**/
        FU_tag = 3;
        FU_value = 128;
        reset = 0;
        squash = 0;
        cdb_display;
        check(cdb_out,3,128);

        FU_tag = 16;
        FU_value = 313;
        reset = 0;
        squash = 0;
        cdb_display;
        check(cdb_out,16,313);
        
        $display("@@@Passed");
        $finish;

    end
endmodule