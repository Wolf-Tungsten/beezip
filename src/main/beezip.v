`default_nettype none
`include "parameters.vh"
`include "log.vh"

module beezip (
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num,

    input  wire i_valid,
    output wire i_ready,
    input  wire i_delim,
    input wire [`ADDR_WIDTH-1:0] dbg_i_head_addr,
    input  wire [`HASH_ISSUE_WIDTH*8-1:0] i_data,

    output wire o_seq_packet_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_strb,
    output wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] o_seq_packet_ll,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_ml,
    output wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] o_seq_packet_offset,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_overlap,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_eoj,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_delim,
    input wire o_seq_packet_ready,

    output wire dbg_hash_engine_o_valid,
    output wire [`ADDR_WIDTH-1:0] dbg_hash_engine_o_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] dbg_hash_engine_o_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] dbg_hash_engine_o_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] dbg_hash_engine_o_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] dbg_hash_engine_o_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] dbg_hash_engine_o_data,
    output wire dbg_hash_engine_o_delim,
    output wire dbg_hash_engine_o_ready
);


    wire hash_engine_o_valid;
    wire [`ADDR_WIDTH-1:0] hash_engine_o_head_addr;
    wire [`HASH_ISSUE_WIDTH-1:0] hash_engine_o_history_valid;
    wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_engine_o_history_addr;
    wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_engine_o_meta_match_len;
    wire [`HASH_ISSUE_WIDTH-1:0] hash_engine_o_meta_match_can_ext;
    wire [`HASH_ISSUE_WIDTH*8-1:0] hash_engine_o_data;
    wire hash_engine_o_delim;
    wire hash_engine_o_ready;

    hash_engine hash_engine_inst(
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),

        .i_valid(i_valid),
        .i_data(i_data),
        .i_delim(i_delim),
        .i_ready(i_ready),
        .dbg_i_head_addr(dbg_i_head_addr),

        .o_valid(hash_engine_o_valid),
        .o_ready(hash_engine_o_ready),
        .o_head_addr(hash_engine_o_head_addr),
        .o_history_valid(hash_engine_o_history_valid),
        .o_history_addr(hash_engine_o_history_addr),
        .o_meta_match_len(hash_engine_o_meta_match_len),
        .o_meta_match_can_ext(hash_engine_o_meta_match_can_ext),
        .o_data(hash_engine_o_data),
        .o_delim(hash_engine_o_delim)
    );

    match_engine match_engine_inst(
        .clk(clk),
        .rst_n(rst_n),
        
        .i_hash_batch_valid(hash_engine_o_valid),
        .i_hash_batch_head_addr(hash_engine_o_head_addr),
        .i_hash_batch_history_valid(hash_engine_o_history_valid),
        .i_hash_batch_history_addr(hash_engine_o_history_addr),
        .i_hash_batch_meta_match_len(hash_engine_o_meta_match_len),
        .i_hash_batch_meta_match_can_ext(hash_engine_o_meta_match_can_ext),
        .i_hash_batch_delim(hash_engine_o_delim),
        .i_hash_batch_ready(hash_engine_o_ready),

        .i_match_pe_write_addr(hash_engine_o_head_addr),
        .i_match_pe_write_data(hash_engine_o_data),
        .i_match_pe_write_enable(hash_engine_o_valid),

        .o_seq_packet_valid(o_seq_packet_valid),
        .o_seq_packet_strb(o_seq_packet_strb),
        .o_seq_packet_ll(o_seq_packet_ll),
        .o_seq_packet_ml(o_seq_packet_ml),
        .o_seq_packet_offset(o_seq_packet_offset),
        .o_seq_packet_overlap(o_seq_packet_overlap),
        .o_seq_packet_eoj(o_seq_packet_eoj),
        .o_seq_packet_delim(o_seq_packet_delim),
        .o_seq_packet_ready(o_seq_packet_ready)
    );

    assign dbg_hash_engine_o_valid = hash_engine_o_valid;
    assign dbg_hash_engine_o_head_addr = hash_engine_o_head_addr;
    assign dbg_hash_engine_o_history_valid = hash_engine_o_history_valid;
    assign dbg_hash_engine_o_history_addr = hash_engine_o_history_addr;
    assign dbg_hash_engine_o_meta_match_len = hash_engine_o_meta_match_len;
    assign dbg_hash_engine_o_meta_match_can_ext = hash_engine_o_meta_match_can_ext;
    assign dbg_hash_engine_o_data = hash_engine_o_data;
    assign dbg_hash_engine_o_delim = hash_engine_o_delim;
    assign dbg_hash_engine_o_ready = hash_engine_o_ready;

endmodule