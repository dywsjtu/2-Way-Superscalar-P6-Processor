module testbench;

    logic                           clock;
    logic                           reset;
    logic       [`XLEN-1:0]         PC;
    logic                           dispatch_enable;            // whether is ready to dispatch
    logic                           complete_enable;            // whether value is ready && cdb is not full
    logic       [`ROB_IDX_LEN-1:0]  complete_rob_entry;         // which entry is ready
    logic       [4:0]               dest_reg_idx;
    logic       [`XLEN-1:0]         value;                      // value to cdb and rob entry
    logic                           wrong_pred;                 
    logic       [`ROB_IDX_LEN-1:0]  reqire_entry_idx;           // query rob entry from reservation station
    
    logic                           rob_full;
    logic                           squash_at_head;             // head is branch instruction and mis predicted
    logic                           dest_valid;                 
    logic       [4:0]               dest_reg;                   // store value in the dest_reg
    logic       [`ROB_IDX_LEN-1:0]  dest_value;                 // value to store in the dest_reg
    logic       [`ROB_IDX_LEN-1:0]  required_value;             // query value from reservation station

    logic       [`ROB_IDX_LEN-1:0]  rob_head;
    logic       [`ROB_IDX_LEN-1:0]  rob_tail;
    logic       [`ROB_IDX_LEN-1:0]  rob_counter;
    logic                           rob_empty;
    logic                           retire_valid;
    ROB_ENTRY   [`ROB_SIZE-1:0]     rob_entries;

    rob test_rob (
        .clock(clock),
        .reset(reset),
        .PC(PC),
        .dispatch_enable(dispatch_enable),
        .complete_enable(complete_enable),
        .complete_rob_entry(complete_rob_entry),
        .dest_reg_idx(dest_reg_idx),
        .value(value),
        .wrong_pred(wrong_pred),
        .reqire_entry_idx(reqire_entry_idx),

        .rob_full(rob_full),
        .squash_at_head(squash_at_head),
        .dest_valid(dest_valid),
        .dest_reg(dest_reg),
        .dest_value(dest_value),
        .required_value(required_value),

        .rob_head(rob_head),
        .rob_tail(rob_tail),
        .rob_counter(rob_counter),
        .rob_empty(rob_empty),
        .retire_valid(retire_valid),
        .rob_entries(rob_entries)
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

        // reset
        reset               = 1;
        PC                  = `XLEN'b0;
        dispatch_enable     = 0;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 5'b0;
        value               = `XLEN'b0;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;

        @(negedge clock);
        reset = 0;

        // test dispatch
        PC                  = 1;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 1;
        value               = `XLEN'b0;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;
        @(negedge clock);
        
        // test dispatch
        PC                  = 2;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 2;
        value               = `XLEN'b0;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;
        @(negedge clock);

        // test dispatch
        PC                  = 3;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 3;
        value               = `XLEN'b0;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;
        @(negedge clock);

        // test complete
        PC                  = 4;
        dispatch_enable     = 1;
        complete_enable     = 1;
        complete_rob_entry  = 2;
        dest_reg_idx        = 2;
        value               = `XLEN'b1;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;
        @(negedge clock);

        // test complete
        PC                  = 5;
        dispatch_enable     = 0;
        complete_enable     = 1;
        complete_rob_entry  = 0;
        dest_reg_idx        = 6;
        value               = 156;
        wrong_pred          = 0;
        reqire_entry_idx    = 2;
        @(negedge clock);

        // test retire
        PC                  = 5;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 6;
        value               = `XLEN'b1;
        wrong_pred          = 0;
        reqire_entry_idx    = `ROB_IDX_LEN'b0;
        @(negedge clock);

        PC                  = 6;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 6;
        value               = `XLEN'b1;
        wrong_pred          = 0;
        reqire_entry_idx    = 2;
        @(negedge clock);

        // test wrong pred
        PC                  = 7;
        dispatch_enable     = 1;
        complete_enable     = 0;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 2;
        value               = `XLEN'b1;
        wrong_pred          = 1;
        reqire_entry_idx    = 2;
        @(negedge clock);

        // test complete after wrong predect
        PC                  = 8;
        dispatch_enable     = 1;
        complete_enable     = 1;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 6;
        value               = `XLEN'b1;
        wrong_pred          = 0;
        reqire_entry_idx    = 2;
        @(negedge clock);

        PC                  = 9;
        dispatch_enable     = 1;
        complete_enable     = 1;
        complete_rob_entry  = `ROB_IDX_LEN'b0;
        dest_reg_idx        = 6;
        value               = `XLEN'b1;
        wrong_pred          = 0;
        reqire_entry_idx    = 2;
        @(negedge clock);











        $display("@@@Passed");
        $finish;
    end
);






















endmodule