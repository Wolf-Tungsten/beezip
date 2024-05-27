`default_nettype none
`include "parameters.vh"
`include "log.vh"

module zstd_accelerator (
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num,

    input  wire input_valid,
    output wire input_ready,
    input  wire input_delim,
    input  wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,

    output wire output_valid,
    output wire [64*4-1:0] output_seq_quad,
    input wire output_ready
);
    wire data_fifo_input_valid;
    wire [`HASH_ISSUE_WIDTH*8-1:0] data_fifo_input_data;
    wire data_fifo_input_ready;

    wire data_fifo_output_valid;
    wire [`HASH_ISSUE_WIDTH*8-1:0] data_fifo_output_data;
    wire data_fifo_output_ready;

    fifo #(.W(`HASH_ISSUE_WIDTH*8), .DEPTH(`MATCH_ENGINE_DATA_FIFO_DEPTH)) match_engine_data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(data_fifo_input_valid),
        .input_payload(data_fifo_input_data),
        .input_ready(data_fifo_input_ready),

        .output_valid(data_fifo_output_valid),
        .output_payload(data_fifo_output_data),
        .output_ready(data_fifo_output_ready)
    );

    wire hash_engine_input_valid;
    wire hash_engine_input_ready;
    wire match_engine_input_data_valid;
    wire match_engine_input_data_ready;

    assign input_ready = hash_engine_input_ready & data_fifo_input_ready;
    assign hash_engine_input_valid = input_valid & input_ready;
    assign data_fifo_input_valid = input_valid & input_ready;
    assign data_fifo_input_data = input_data;

    wire hash_engine_output_valid;
    wire hash_engine_output_ready;
    wire hash_engine_output_delim;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] hash_engine_output_valid_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] hash_engine_output_history_addr_vec;
    wire [`ADDR_WIDTH-1:0] hash_engine_output_head_addr;

    hash_engine_top hash_engine_inst(
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),

        .input_valid(hash_engine_input_valid),
        .input_data(input_data),
        .input_delim(input_delim),
        .input_ready(hash_engine_input_ready),

        .output_valid(hash_engine_output_valid),
        .output_ready(hash_engine_output_ready),
        .output_delim(hash_engine_output_delim),
        .output_head_addr(hash_engine_output_head_addr),
        .output_history_valid_vec(hash_engine_output_valid_vec),
        .output_history_addr_vec(hash_engine_output_history_addr_vec)
    );

    match_engine_top match_engine_inst(
        .clk(clk),
        .rst_n(rst_n),

        .input_data_valid(data_fifo_output_valid),
        .input_data_ready(data_fifo_output_ready),
        .input_data(data_fifo_output_data),

        .input_hash_result_valid(hash_engine_output_valid),
        .input_hash_result_ready(hash_engine_output_ready),
        .input_hash_valid_vec(hash_engine_output_valid_vec),
        .input_history_addr_vec(hash_engine_output_history_addr_vec),
        .input_hash_result_delim(hash_engine_output_delim),

        .output_valid(output_valid),
        .output_ready(output_ready),
        .output_seq_quad(output_seq_quad)
    );

endmodule