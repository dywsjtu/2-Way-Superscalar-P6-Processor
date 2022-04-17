`ifndef SYNTHESIS

//
// This is an automatically generated file from 
// dc_shell Version S-2021.06-SP1 -- Jul 13, 2021
//

// For simulation only. Do not modify.

module pipeline_svsim (
	input         				clock,                    	input         				reset,                    	input [3:0]   				mem2proc_response,        	input [63:0]  				mem2proc_data,            	input [3:0]   				mem2proc_tag,              	
	output logic [1:0]  		proc2mem_command,    	output logic [32-1:0] 	proc2mem_addr,      	output logic [63:0] 		proc2mem_data,      	 
	output logic [3:0]  		pipeline_completed_insts,
	output EXCEPTION_CODE   	pipeline_error_status,
	output logic [4:0]  		pipeline_commit_wr_idx_0,
	output logic [32-1:0] 	pipeline_commit_wr_data_0,
	output logic        		pipeline_commit_wr_en_0,
	output logic [32-1:0] 	pipeline_commit_NPC_0,
	output logic [4:0]  		pipeline_commit_wr_idx_1,
	output logic [32-1:0] 	pipeline_commit_wr_data_1,
	output logic        		pipeline_commit_wr_en_1,
	output logic [32-1:0] 	pipeline_commit_NPC_1	
);


		

  pipeline pipeline( {>>{ clock }}, {>>{ reset }}, {>>{ mem2proc_response }}, 
        {>>{ mem2proc_data }}, {>>{ mem2proc_tag }}, {>>{ proc2mem_command }}, 
        {>>{ proc2mem_addr }}, {>>{ proc2mem_data }}, 
        {>>{ pipeline_completed_insts }}, {>>{ pipeline_error_status }}, 
        {>>{ pipeline_commit_wr_idx_0 }}, {>>{ pipeline_commit_wr_data_0 }}, 
        {>>{ pipeline_commit_wr_en_0 }}, {>>{ pipeline_commit_NPC_0 }}, 
        {>>{ pipeline_commit_wr_idx_1 }}, {>>{ pipeline_commit_wr_data_1 }}, 
        {>>{ pipeline_commit_wr_en_1 }}, {>>{ pipeline_commit_NPC_1 }} );
endmodule
`endif
