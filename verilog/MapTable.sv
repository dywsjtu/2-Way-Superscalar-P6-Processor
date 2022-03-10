module maptable (
        //INPUT
        input logic clock,
        input logic reset,

        input logic [$clog2(`ROB_SIZE+1)-1:0] ROB_idx, //rd tag from ROB in dispatch stage: start from 1
        input logic [$clog2(`REG_SIZE)-1:0] rd_dispatch, // dest reg to be set in dispatch stage

        input logic [$clog2(`ROB_SIZE+1)-1:0] CDB_tag, //rd tag from CDB in complete stage

        input logic [$clog2(`REG_SIZE)-1:0] rs1_dispatch, //check rs1 tag for RS
        input logic [$clog2(`REG_SIZE)-1:0] rs2_dispatch, //check rs2 tag for RS

        input logic [$clog2(`REG_SIZE)-1:0] rd_retire, // rd idx of the head entry in ROB
        input logic clear, //whether to clear tag in retire stage

        input logic flush, //for brach or exception 

        //OUTPUT
        output logic [$clog2(`ROB_SIZE+1)-1:0] rs1_tag,
        output logic [$clog2(`ROB_SIZE+1)-1:0] rs2_tag, 
        output logic rs1_ready, //whether valid in ROB
        output logic rs2_ready
    );

    //MapTable
    logic [$clog2(`ROB_SIZE+1)-1:0] Tag [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0] ready_in_ROB;

    //To avoid multiple drive
    logic [$clog2(`ROB_SIZE+1)-1:0] Tag_next [`REG_SIZE-1:0];
    logic [`REG_SIZE-1:0] ready_in_ROB_next;

    always_comb begin
        if (flush) begin
            Tag_next = '{default:32'h0000_0000_0000_0000};
            ready_in_ROB_next = 0;
        end
        else begin
            Tag_next = Tag;
            ready_in_ROB_next = ready_in_ROB;

            //clear Tag in retire stage
            if (clear) begin
                Tag_next[rd_retire] = 0;
                ready_in_ROB_next[rd_retire] = 0;
            end

            //set ready bit in complete stage
            for (int i = 0; i < `REG_SIZE; i++)  begin
                if (Tag[i] == CDB_tag) begin
                    ready_in_ROB_next[i] = 1'b1;
                    //break; 
                end
            end
            //set rd tag in dispatch stage
            Tag_next[rd_dispatch] = ROB_idx;
            end
    end

    
    //MapTable output in dispatch
    assign rs1_tag = Tag_next[rs1_dispatch]; //bypassing from retire/complete to dispatch
    assign rs2_tag = Tag_next[rs2_dispatch];
    assign rs1_ready = ready_in_ROB_next[rs1_dispatch];
    assign rs2_ready = ready_in_ROB_next[rs2_dispatch];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | flush) begin 
            //All from reg file
            Tag <= `SD '{default:32'h0000_0000_0000_0000};//need to change to `SD
            ready_in_ROB <= `SD 0;
        end
        else begin
            //update Maptable
            Tag <= `SD Tag_next;//need to change to `SD
            ready_in_ROB <= `SD ready_in_ROB_next;
        end
    end

endmodule