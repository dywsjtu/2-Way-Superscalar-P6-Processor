/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

/* Synthesis testing definition, used in DUT module instantiation */

`define DEBUG

`ifdef  SYNTH_TEST
`define DUT(mod) mod``_svsim
`else
`define DUT(mod) mod
`endif

//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////
//`define CACHE_MODE //removes the byte-level interface from the memory mode, DO NOT MODIFY!
`define NUM_MEM_TAGS           15

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0
`define SYNTH_CLOCK_PERIOD     10.0 // Clock period for synth and memory latency

`define MEM_LATENCY_IN_CYCLES (100.0/`SYNTH_CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period).  The default behavior for
// float to integer conversion is rounding to nearest

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

//////////////////////////////////////////////
//
// MapTable parameters
//
//////////////////////////////////////////////
`define ROB_SIZE 		8
`define REG_SIZE 		32
//`define ROB_IDX_LEN 	clog2(`ROB_SIZE+1)
`define ROB_IDX_LEN 	6
`define ZERO_TAG 		6'b100000
`define CDB_BUFFER_SIZE	2

`define SMALL_FU_OUT_TEST
`define FU_SIZE			1
`define FU_CAT			4
`define NUM_ALU			1
`define NUM_LS			0
`define NUM_MULT		0
`define NUM_BEQ			0
`define ALU_OFFSET		1
`define LS_OFFSET		1
`define MULT_OFFSET		1
`define BEQ_OFFSET		1

// `define FU_SIZE			20
// `define CAT_FU			4
// `define NUM_ALU			8
// `define NUM_LS			4
// `define NUM_MULT			4
// `define NUM_BEQ			4
// `define ALU_OFFSET		8
// `define LS_OFFSET		12
// `define MULT_OFFSET		16
// `define BEQ_OFFSET		20

//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

`ifndef CACHE_MODE
typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;
`endif
//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} IF_ID_PACKET;

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic 			[`XLEN-1:0] 	NPC;   			// PC + 4
	logic 			[`XLEN-1:0] 	PC;    			// PC

	// logic 		[`XLEN-1:0] 	rs1_value;    	// reg A value                                  
	// logic 		[`XLEN-1:0]		rs2_value;    	// reg B value                                  
	                                                                                
	ALU_OPA_SELECT 					opa_select;		// ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT 					opb_select;		// ALU opb mux select (ALU_OPB_xxx *)
	INST 							inst;			// instruction
	
	logic			[4:0] 			dest_reg_idx; 	// destination (writeback) register index      
	logic			[1:0][4:0]		input_reg_idx;

	ALU_FUNC    					alu_func;      	// ALU function select (ALU_xxx *)
	logic       					rd_mem;        	// does inst read memory?
	logic       					wr_mem;        	// does inst write memory?
	logic       					cond_branch;   	// is inst a conditional branch?
	logic       					uncond_branch; 	// is inst an unconditional branch?
	logic       					halt;          	// is this a halt?
	logic       					illegal;       	// is this instruction illegal?
	logic       					csr_op;        	// is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       					valid;         	// is inst a valid instruction to be counted for CPI calculations?
	logic			[1:0]			req_reg; 		// whether the register value is actually needed.
	logic							take_branch;
} ID_EX_PACKET;

// typedef struct packed {
// 	logic [`XLEN-1:0] alu_result; // alu_result
// 	logic [`XLEN-1:0] NPC; //pc + 4
// 	logic             take_branch; // is this a taken branch?
// 	//pass throughs from decode stage
// 	logic [`XLEN-1:0] rs2_value;
// 	logic             rd_mem, wr_mem;
// 	logic [4:0]       dest_reg_idx;
// 	logic             halt, illegal, csr_op, valid;
// 	logic [2:0]       mem_size; // byte, half-word or word
// } EX_MEM_PACKET;


typedef struct packed {
	logic						valid;
	logic	[`XLEN-1:0]			PC;				// alu result
	logic						ready;			// is value ready
	logic	[4:0]				dest_reg_idx;	// dest reg index
	logic	[`XLEN-1:0]			value;			// value
	logic						mis_pred;  		// is mispredicted 
	logic						take_branch;	// whether is predicted to take branch
} ROB_ENTRY;

typedef struct packed {
	logic	[`ROB_IDX_LEN:0] 	tag;
	logic	[`XLEN-1:0]			value;
	logic						valid;
	logic						take_branch;
} CDB_ENTRY;

typedef struct packed {
	logic	[1:0][`ROB_IDX_LEN-1:0]	entry_idx; // query index from RS to ROB
} RS_ROB_PACKET;

// typedef struct packed {
// 	logic						completed;	// whether an instruction is completed or not
// 	logic	[`ROB_IDX_LEN-1:0]	entry_idx;	// which ROB entry is completed
// 	logic	[`XLEN-1:0]			value;		// the value for completed instruction
// 	logic						mis_pred;	// whether is a mis pred
// } FU_ROB_PACKET;

typedef struct packed {
	logic	[`ROB_IDX_LEN-1:0]	rob_tail;	 // the tail of ROB
	logic	[1:0][`XLEN-1:0]	value ; // query values from ROB
	logic						squash;		 // signal of flushing
} ROB_RS_PACKET;

typedef struct packed {
	logic	[`ROB_IDX_LEN-1:0]	rob_tail;	// the tail of ROB
	logic						squash;		// signal of flushing
	logic 						dest_valid;
	logic 	[4:0]				dest_reg_idx;
} ROB_MT_PACKET;

typedef struct packed {
	logic						valid;
	logic						dest_valid;   // whether is ready and valid to write to regfile
	logic	[4:0]				dest_reg_idx; // the destination register to write to regfile
	logic	[`XLEN-1:0]			dest_value;	  // the value to write to destination register in regfile
} ROB_REG_PACKET;

typedef struct packed {
	logic						squash;
	logic	[`XLEN-1:0]			target_pc;
	`ifdef DEBUG
		logic	[`XLEN-1:0]		other_pc;
	`endif
} ROB_ID_PACKET;

typedef struct packed {
	logic [1:0][`XLEN-1:0]  rs_values;
} REG_RS_PACKET;


typedef struct packed {
	logic [`ROB_IDX_LEN:0] tag;
	logic ready;
} REG_INFO;

typedef struct packed{
	REG_INFO [1:0] rs_infos;
} MT_RS_PACKET;

typedef struct packed {
 logic [1:0][4:0]				register_idxes;
} RS_MT_PACKET;

typedef struct packed {
 logic [1:0][4:0]				register_idxes;
} RS_REG_PACKET;


// Functional unit tags and a count

// FU_COUNT is the number of FUs

typedef enum logic [2:0] { FU_ALU, FU_LOAD, FU_STORE, FU_FP, FU_COUNT} FU_TAG;

typedef struct packed {
	logic [`ROB_IDX_LEN:0] 					tag;
	logic [`XLEN-1:0]						V;
	logic 									V_ready;
} RS_ENTRY_INFO;

typedef struct packed {
	logic 									busy;
	logic 			[`ROB_IDX_LEN:0]		T_dest;
	RS_ENTRY_INFO 	[1:0] 					rs_entry_info;
	// logic ready_execute;
} RS_ENTRY;

typedef struct packed {
	logic 						valid;
	logic	[`XLEN-1:0]			PC;
	logic						dispatch_enable; // whether is enable to dispatch
	logic	[4:0]				dest_reg_idx;	 // destination register
	logic						take_branch;
} ID_ROB_PACKET;

typedef struct packed {
	logic dispatch_enable; 
	logic [4:0] dest_reg_idx;
} ID_MT_PACKET;

typedef struct packed {
	logic	[`XLEN-1:0]			NPC;			// PC + 4
	logic	[`XLEN-1:0]			PC;				// PC                               
	logic						dispatch_enable;// whether is enable to dispatch                             
	ALU_OPA_SELECT				opa_select;		// ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT				opb_select;		// ALU opb mux select (ALU_OPB_xxx *)
	INST						inst;			// instruction
	
	logic	[4:0]				dest_reg_idx;	// destination (writeback) register index      
	logic	[1:0][4:0]			input_reg_idx;
	
	ALU_FUNC					alu_func;		// ALU function select (ALU_xxx *)
	logic						rd_mem;			// does inst read memory?
	logic						wr_mem;			// does inst write memory?
	logic						cond_branch;	// is inst a conditional branch?
	logic						uncond_branch;	// is inst an unconditional branch?
	logic						halt;			// is this a halt?
	logic						illegal;		// is this instruction illegal?
	logic						csr_op;			// is this a CSR operation? (we only used this as a cheap way to get return code)
	logic						valid;			// is inst a valid instruction to be counted for CPI calculations?
	logic	[1:0]				req_reg; 		// whether the register value is actually needed. (i.e. whether need T and V)
} ID_RS_PACKET;

typedef struct packed {
	logic [`ROB_IDX_LEN:0] tag;
	logic ready;
} RS_INFO;

typedef struct packed {
	logic						squash;
	logic	[`XLEN-1:0]			NPC;			// PC + 4
	logic	[`XLEN-1:0]			PC;				// PC

	logic	[1:0][`XLEN-1:0]	rs_value;		// reg A & B value
	logic						rs_value_valid;                                  

	ALU_OPA_SELECT				opa_select;		// ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT				opb_select;		// ALU opb mux select (ALU_OPB_xxx *)
	INST						inst;			// instruction
	
	logic	[4:0]				dest_reg_idx;	// destination (writeback) register index      
	
	ALU_FUNC					alu_func;		// ALU function select (ALU_xxx *)
	logic						rd_mem;			// does inst read memory?
	logic						wr_mem;			// does inst write memory?
	logic						cond_branch;	// is inst a conditional branch?
	logic						uncond_branch;	// is inst an unconditional branch?
	logic						halt;			// is this a halt?
	logic						illegal;		// is this instruction illegal?
	logic						csr_op;			// is this a CSR operation? (we only used this as a cheap way to get return code)
	logic						valid;			// is inst a valid instruction to be counted for CPI calculations?
} RS_FU_PACKET;



//typedef struct packed {
//	logic	[`ROB_IDX_LEN-1:0]	entry_idx1; // query index1 from RS to ROB
//	logic	[`ROB_IDX_LEN-1:0]	entry_idx2;  // query index2 from RS to ROB
//} RS_ROB_PACKET;

// typedef struct packed {
	
// } CDB_MT_PACKET;

typedef struct packed {
	logic	[`XLEN-1:0]		alu_result; // alu_result
	logic	[`XLEN-1:0]		NPC; //pc + 4
	logic					take_branch; // is this a taken branch?
	//pass throughs from decode stage
	logic	[`XLEN-1:0]		rs2_value;
	logic					rd_mem, wr_mem;
	logic	[4:0]			dest_reg_idx;
	logic					halt, illegal, csr_op;
	logic					valid;	// whether the output of fu is valid
	logic	[2:0]			mem_size; // byte, half-word or word
} FU_RS_PACKET;

`endif // __SYS_DEFS_VH__
