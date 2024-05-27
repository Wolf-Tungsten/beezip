`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module job_pe #(parameter MATCH_PE_IDX = 0)(
        input wire clk,
        input wire rst_n,

        // input hash result port
        input wire i_hash_result_valid,
        input wire [`ADDR_WIDTH-1:0] i_head_addr,
        input wire [`HASH_ISSUE_WIDTH-1:0] i_row_valid,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] i_history_valid,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] i_history_addr,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] i_meta_match_len,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] i_meta_match_can_ext,
        output wire o_hash_result_ready,

        // output seq port
        output wire o_seq_valid,
        output wire [`JOB_LEN_LOG2+1-1:0] o_seq_lit_len,
        output wire [`MAX_MATCH_LEN_LOG2+1-1:0] o_seq_match_len,
        output wire [`ADDR_WIDTH-1:0] o_seq_offset,
        output wire o_seq_end_of_job,
        output wire o_seq_overlapped,
        output wire [`JOB_LEN_LOG2+1-1:0] o_seq_overlap_len,
        input wire i_seq_ready,
        
        // match request port
        output wire o_match_req_valid,
        output wire [`ADDR_WIDTH-1:0] o_match_req_head_addr,
        output wire [`ADDR_WIDTH-1:0] o_match_req_history_addr,
        output wire [`JOB_PE_NUM_LOG2-1:0] o_match_req_job_pe_id,
        output wire [`ROW_SIZE_LOG2-1:0] o_match_req_slot_id,
        input wire  i_match_req_ready,

        // match resp port
        input wire i_match_resp_valid,
        input wire [`ROW_SIZE_LOG2-1:0] i_match_req_slot_id,
        input wire [`MAX_MATCH_LEN_LOG2+1-1:0] i_match_resp_len,
        output wire o_match_resp_ready
    );


    

endmodule
