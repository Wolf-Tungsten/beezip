`include "parameters.vh"

module hash_result_bus #(parameter [`NUM_JOB_PE_LOG2-1:0] IDX = '0, parameter PIPED=0) (
    input wire clk,
    input wire rst_n,

    input wire i_valid,
    input wire [`ADDR_WIDTH-1:0] i_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] i_history_valid,
    input wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] i_history_addr,
    input wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] i_meta_match_len,
    input wire [`HASH_ISSUE_WIDTH-1:0] i_meta_match_can_ext,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] i_data,
    input wire i_delim,
    output wire i_ready,

    output wire o_this_valid,
    output wire [`ADDR_WIDTH-1:0] o_this_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] o_this_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] o_this_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] o_this_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] o_this_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] o_this_data,
    output wire o_this_delim,
    input wire o_this_ready,

    output wire o_next_valid,
    output wire [`ADDR_WIDTH-1:0] o_next_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] o_next_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] o_next_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] o_next_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] o_next_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] o_next_data,
    output wire o_next_delim,
    input wire o_next_ready
);

    wire next_valid;
    wire [`ADDR_WIDTH-1:0] next_head_addr;
    wire [`HASH_ISSUE_WIDTH-1:0] next_history_valid;
    wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] next_history_addr;
    wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] next_meta_match_len;
    wire [`HASH_ISSUE_WIDTH-1:0] next_meta_match_can_ext;
    wire [`HASH_ISSUE_WIDTH*8-1:0] next_data;
    wire next_delim;
    wire next_ready;

    wire [`JOB_LEN_LOG2-1:0] ignore_lo_part;
    wire [`NUM_JOB_PE_LOG2-1:0] input_pe_idx;
    wire [`ADDR_WIDTH-$bits(input_pe_idx)-$bits(ignore_lo_part)-1:0] ignore_hi_part;
    assign {ignore_hi_part, input_pe_idx, ignore_lo_part} = i_head_addr;
    assign o_this_valid = i_valid && (input_pe_idx == IDX);
    assign next_valid = i_valid && (input_pe_idx != IDX);
    assign i_ready = (input_pe_idx == IDX) ? o_this_ready : next_ready;
    assign o_this_head_addr = i_head_addr;
    assign next_head_addr = i_head_addr;
    assign o_this_history_valid = i_history_valid;
    assign next_history_valid = i_history_valid;
    assign o_this_history_addr = i_history_addr;
    assign next_history_addr = i_history_addr;
    assign o_this_meta_match_len = i_meta_match_len;
    assign next_meta_match_len = i_meta_match_len;
    assign o_this_meta_match_can_ext = i_meta_match_can_ext;
    assign next_meta_match_can_ext = i_meta_match_can_ext;
    assign o_this_data = i_data;
    assign next_data = i_data;
    assign o_this_delim = i_delim;
    assign next_delim = i_delim;

    generate
        if(PIPED > 0) begin
            // create a handshake between this and next
            handshake_slice_reg #(
                .W(`ADDR_WIDTH + `HASH_ISSUE_WIDTH + `HASH_ISSUE_WIDTH*`ADDR_WIDTH + `HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH + `HASH_ISSUE_WIDTH + `HASH_ISSUE_WIDTH*8 + 1),
                .DEPTH(PIPED)
            ) pipeline_reg (
                .clk(clk),
                .rst_n(rst_n),
                .input_valid(next_valid),
                .input_ready(next_ready),
                .input_payload({next_head_addr, next_history_valid, next_history_addr, next_meta_match_len, next_meta_match_can_ext, next_data, next_delim}),
                .output_valid(o_next_valid),
                .output_ready(o_next_ready),
                .output_payload({o_next_head_addr, o_next_history_valid, o_next_history_addr, o_next_meta_match_len, o_next_meta_match_can_ext, o_next_data, o_next_delim})
            );
        end else begin
            assign o_next_valid = next_valid;
            assign o_next_head_addr = next_head_addr;
            assign o_next_history_valid = next_history_valid;
            assign o_next_history_addr = next_history_addr;
            assign o_next_meta_match_len = next_meta_match_len;
            assign o_next_meta_match_can_ext = next_meta_match_can_ext;
            assign o_next_data = next_data;
            assign o_next_delim = next_delim;
            assign next_ready = o_next_ready;
        end
    endgenerate

endmodule