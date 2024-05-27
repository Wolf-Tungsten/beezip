`include "parameters.vh"

module post_hash_pe_scheduler (
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num, 

    input wire input_valid,
    input wire [`NUM_HASH_PE-1:0] input_mask,
    input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_addr_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE-1:0] input_history_valid_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] input_meta_match_len_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE-1:0] input_meta_match_can_ext_vec,
    input wire [`NUM_HASH_PE-1:0] input_delim_vec,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
    output wire input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_row_valid,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_history_valid_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_meta_match_can_ext_vec,  
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire output_delim,
    input wire output_ready
);

    wire rc_output_valid;
    wire [`ADDR_WIDTH-1:0] rc_output_head_addr;
    wire [`HASH_ISSUE_WIDTH-1:0] rc_output_row_valid;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] rc_output_history_valid_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] rc_output_history_addr_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] rc_output_meta_match_len_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] rc_output_meta_match_can_ext_vec;
    wire [`HASH_ISSUE_WIDTH*8-1:0] rc_output_data;
    wire rc_output_delim;
    wire rc_output_ready;

    reorder_crossbar rc(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(input_valid),
        .input_mask(input_mask),
        .input_addr_vec(input_addr_vec),
        .input_history_valid_vec(input_history_valid_vec),
        .input_history_addr_vec(input_history_addr_vec),
        .input_meta_match_len_vec(input_meta_match_len_vec),
        .input_meta_match_can_ext_vec(input_meta_match_can_ext_vec),
        .input_delim_vec(input_delim_vec),
        .input_data(input_data),
        .input_ready(input_ready),

        .output_valid(rc_output_valid),
        .output_head_addr(rc_output_head_addr),
        .output_row_valid(rc_output_row_valid),
        .output_history_valid_vec(rc_output_history_valid_vec),
        .output_history_addr_vec(rc_output_history_addr_vec),
        .output_meta_match_len_vec(rc_output_meta_match_len_vec),
        .output_meta_match_can_ext_vec(rc_output_meta_match_can_ext_vec),
        .output_delim(rc_output_delim),
        .output_data(rc_output_data),
        .output_ready(rc_output_ready)
    );
    
    hash_row_synchronizer hrs(
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),

        .input_valid(rc_output_valid),
        .input_head_addr(rc_output_head_addr),
        .input_row_valid(rc_output_row_valid),
        .input_history_valid_vec(rc_output_history_valid_vec),
        .input_history_addr_vec(rc_output_history_addr_vec),
        .input_meta_match_len_vec(rc_output_meta_match_len_vec),
        .input_meta_match_can_ext_vec(rc_output_meta_match_can_ext_vec),
        .input_delim(rc_output_delim),
        .input_data(rc_output_data),
        .input_ready(rc_output_ready),

        .output_valid(output_valid),
        .output_head_addr(output_head_addr),
        .output_row_valid(output_row_valid),
        .output_history_valid_vec(output_history_valid_vec),
        .output_history_addr_vec(output_history_addr_vec),
        .output_meta_match_len_vec(output_meta_match_len_vec),
        .output_meta_match_can_ext_vec(output_meta_match_can_ext_vec),
        .output_delim(output_delim),
        .output_data(output_data),
        .output_ready(output_ready)
    );
endmodule