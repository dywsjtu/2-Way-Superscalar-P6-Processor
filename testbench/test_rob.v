
module testbench;

    logic                           clock;
    logic                           reset;

    ID_ROB_PACKET                   id_rob;
    RS_ROB_PACKET                   rs_rob;
    FU_ROB_PACKET                   fu_rob;

    logic                           rob_full;

    ROB_RS_PACKET                   rob_rs;
    ROB_MT_PACKET                   rob_mt;
    ROB_REG_PACKET                  rob_reg;

    ROB_RS_PACKET                   gt_rob_rs;
    ROB_MT_PACKET                   gt_rob_mt;
    ROB_REG_PACKET                  gt_rob_reg;

    logic       [`ROB_IDX_LEN-1:0]  rob_head;
    logic       [`ROB_IDX_LEN-1:0]  rob_tail;
    logic       [`ROB_IDX_LEN:0]    rob_counter;
    ROB_ENTRY   [`ROB_SIZE-1:0]     rob_entries;

    rob test_rob (
        .clock(clock),
        .reset(reset),

        .id_rob(id_rob),
        .rs_rob(rs_rob),
        .fu_rob(fu_rob),

        .rob_full(rob_full),

        .rob_rs(rob_rs),
        .rob_mt(rob_mt),
        .rob_reg(rob_reg),

        .rob_head(rob_head),
        .rob_tail(rob_tail),
        .rob_counter(rob_counter),
        .rob_entries(rob_entries)
    );

    always #5 clock = ~clock;

    task check;
        input ID_ROB_PACKET   id_rob;
        input RS_ROB_PACKET   rs_rob;
        input FU_ROB_PACKET   fu_rob;
        // input logic           rob_full;
        input ROB_RS_PACKET   rob_rs;
        input ROB_MT_PACKET   rob_mt;
        input ROB_REG_PACKET  rob_reg;
        input ROB_RS_PACKET   gt_rob_rs;
        input ROB_MT_PACKET   gt_rob_mt;
        input ROB_REG_PACKET  gt_rob_reg;
        begin
            logic   flag;
            flag = 1'b0;
            if (rob_rs.rob_tail != gt_rob_rs.rob_tail) begin
                $display("@@@ Incorrect rob_rs.rob_tail at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_rs.value[0] != gt_rob_rs.value[0]) begin
                $display("@@@ Incorrect rob_rs.value[0] at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_rs.value[1] != gt_rob_rs.value[1]) begin
                $display("@@@ Incorrect rob_rs.value[1] at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_rs.squash != gt_rob_rs.squash) begin
                $display("@@@ Incorrect rob_rs.squash at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_mt.rob_tail != gt_rob_mt.rob_tail) begin
                $display("@@@ Incorrect rob_mt.rob_tail at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_mt.squash != gt_rob_mt.squash) begin
                $display("@@@ Incorrect rob_mt.squash at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_mt.dest_valid != gt_rob_mt.dest_valid) begin
                $display("@@@ Incorrect rob_mt.dest_valid at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_mt.dest_reg_idx != gt_rob_mt.dest_reg_idx) begin
                $display("@@@ Incorrect rob_mt.dest_reg_idx at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_reg.dest_valid != gt_rob_reg.dest_valid) begin
                $display("@@@ Incorrect rob_reg.dest_valid at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_reg.dest_reg_idx != gt_rob_reg.dest_reg_idx) begin
                $display("reg_idx", gt_rob_reg.dest_reg_idx);
                $display("@@@ Incorrect rob_reg.dest_reg_idx at time %4.0f", $time);
                flag = 1'b1;
            end
            if (rob_reg.dest_value != gt_rob_reg.dest_value) begin
                $display("@@@ Incorrect rob_reg.dest_value at time %4.0f", $time);
                flag = 1'b1;
            end

            #1;
            if (flag) begin
                $display("id_rob:  %p", id_rob);
                $display("rs_rob:  %p", rs_rob);
                $display("fu_rob:  %p", fu_rob);
                $display("rob_rs:  %p", rob_rs);
                $display("rob_mt:  %p", rob_mt);
                $display("rob_reg: %p", rob_reg);

                $display("@@@ Failed at time %f", $time);
                $finish;
            end
        end
    endtask

    assign gt_rob_mt.rob_tail       = gt_rob_rs.rob_tail;
    assign gt_rob_mt.squash         = gt_rob_rs.squash;
    assign gt_rob_mt.dest_valid     = gt_rob_reg.dest_valid;
    assign gt_rob_mt.dest_reg_idx   = gt_rob_mt.dest_reg_idx;

    initial begin
        $monitor("time: %3.0d head: %2.0d tail: %2.0d counter: %2.0d ", $time, rob_head, rob_tail, rob_counter);
        clock = 0;

        // reset
        reset                       = 1;
        id_rob.PC                   = `XLEN'b0;
        id_rob.dispatch_enable      = 1'b0;
        id_rob.dest_reg_idx         = 5'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;

        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00000;
        gt_rob_reg.dest_value       = `XLEN'b0;

        @(negedge clock);
        reset = 0;
        @(negedge clock);
        // check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);
        
        // do nothing
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b1;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b1;
        fu_rob.value                = `XLEN'b10;
        fu_rob.mis_pred             = 1'b1;
        
        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00000;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 0
        id_rob.PC                   = `XLEN'b0;
        id_rob.dest_reg_idx         = 5'b00011;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b1;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);        
        
        // fill rob 1
        id_rob.PC                   = `XLEN'b1;
        id_rob.dest_reg_idx         = 5'b00010;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00010;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 2
        id_rob.PC                   = `XLEN'b10;
        id_rob.dest_reg_idx         = 5'b00100;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00011;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 3
        id_rob.PC                   = `XLEN'b11;
        id_rob.dest_reg_idx         = 5'b01100;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00100;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);
        
        // fill rob 4; complete rob 1
        id_rob.PC                   = `XLEN'b100;
        id_rob.dest_reg_idx         = 5'b10000;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b0;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b0;
        fu_rob.completed            = 1'b1;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b1;
        fu_rob.value                = `XLEN'b01100;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00101;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // complete rob 0
        id_rob.PC                   = `XLEN'b100;
        id_rob.dest_reg_idx         = 5'b10000;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b1;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b10;
        fu_rob.completed            = 1'b1;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b1011;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00101;
        gt_rob_rs.value[0]          = `XLEN'b01100;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b1;
        gt_rob_reg.dest_reg_idx     = 5'b00011;
        gt_rob_reg.dest_value       = `XLEN'b1011;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // retire rob 0; fill rob 5
        id_rob.PC                   = `XLEN'b101;
        id_rob.dest_reg_idx         = 5'b01000;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b10;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b1;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b1011;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00110;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b01100;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b1;
        gt_rob_reg.dest_reg_idx     = 5'b00010;
        gt_rob_reg.dest_value       = `XLEN'b01100;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // retire rob 1
        id_rob.PC                   = `XLEN'b110;
        id_rob.dest_reg_idx         = 5'b11000;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b10;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b11;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b1011;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00110;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 6
        id_rob.PC                   = `XLEN'b110;
        id_rob.dest_reg_idx         = 5'b11000;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b10;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b11;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b1011;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00111;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 7
        id_rob.PC                   = `XLEN'b111;
        id_rob.dest_reg_idx         = 5'b00011;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b10;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b11;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 0
        id_rob.PC                   = `XLEN'b1000;
        id_rob.dest_reg_idx         = 5'b00011;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00001;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // fill rob 1
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b1;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00010;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // do nothing
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00010;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // complete 2, prepare to squash
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b1;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b10;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b1;
        
        gt_rob_rs.rob_tail          = 5'b00010;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b1;
        gt_rob_reg.dest_valid       = 1'b1;
        gt_rob_reg.dest_reg_idx     = 5'b00100;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // squash! tail=head=2
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00000;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // do nothing
        id_rob.PC                   = `XLEN'b1001;
        id_rob.dest_reg_idx         = 5'b00110;
        id_rob.dispatch_enable      = 1'b0;
        rs_rob.entry_idx[0]         = `ROB_IDX_LEN'b11;
        rs_rob.entry_idx[1]         = `ROB_IDX_LEN'b100;
        fu_rob.completed            = 1'b0;
        fu_rob.entry_idx            = `ROB_IDX_LEN'b0;
        fu_rob.value                = `XLEN'b0;
        fu_rob.mis_pred             = 1'b0;
        
        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00000;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        reset                       = 1;
        gt_rob_rs.rob_tail          = 5'b00000;
        gt_rob_rs.value[0]          = `XLEN'b0;
        gt_rob_rs.value[1]          = `XLEN'b0;
        gt_rob_rs.squash            = 1'b0;
        gt_rob_reg.dest_valid       = 1'b0;
        gt_rob_reg.dest_reg_idx     = 5'b00000;
        gt_rob_reg.dest_value       = `XLEN'b0;
        @(negedge clock);
        check(id_rob, rs_rob, fu_rob, rob_rs, rob_mt, rob_reg, gt_rob_rs, gt_rob_mt, gt_rob_reg);

        // // test complete
        // PC                  = 5;
        // dispatch_enable     = 0;
        // complete_enable     = 1;
        // complete_rob_entry  = 0;
        // dest_reg_idx        = 6;
        // value               = 156;
        // wrong_pred          = 0;
        // reqire_entry_idx    = 2;
        // @(negedge clock);

        // // test retire
        // PC                  = 5;
        // dispatch_enable     = 1;
        // complete_enable     = 0;
        // complete_rob_entry  = `ROB_IDX_LEN'b0;
        // dest_reg_idx        = 6;
        // value               = `XLEN'b1;
        // wrong_pred          = 0;
        // reqire_entry_idx    = `ROB_IDX_LEN'b0;
        // @(negedge clock);

        // PC                  = 6;
        // dispatch_enable     = 1;
        // complete_enable     = 0;
        // complete_rob_entry  = `ROB_IDX_LEN'b0;
        // dest_reg_idx        = 6;
        // value               = `XLEN'b1;
        // wrong_pred          = 0;
        // reqire_entry_idx    = 2;
        // @(negedge clock);

        // // test wrong pred
        // PC                  = 7;
        // dispatch_enable     = 1;
        // complete_enable     = 0;
        // complete_rob_entry  = `ROB_IDX_LEN'b0;
        // dest_reg_idx        = 2;
        // value               = `XLEN'b1;
        // wrong_pred          = 1;
        // reqire_entry_idx    = 2;
        // @(negedge clock);

        // // test complete after wrong predect
        // PC                  = 8;
        // dispatch_enable     = 1;
        // complete_enable     = 1;
        // complete_rob_entry  = `ROB_IDX_LEN'b0;
        // dest_reg_idx        = 6;
        // value               = `XLEN'b1;
        // wrong_pred          = 0;
        // reqire_entry_idx    = 2;
        // @(negedge clock);

        // PC                  = 9;
        // dispatch_enable     = 1;
        // complete_enable     = 1;
        // complete_rob_entry  = `ROB_IDX_LEN'b0;
        // dest_reg_idx        = 6;
        // value               = `XLEN'b1;
        // wrong_pred          = 0;
        // reqire_entry_idx    = 2;
        // @(negedge clock);
        $display("@@@Passed");
        $finish;
    end
endmodule
