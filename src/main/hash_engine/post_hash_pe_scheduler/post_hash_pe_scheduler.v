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
    output wire [`HASH_ISSUE_WIDTH-1:0] output_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] output_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire output_delim,
    input wire output_ready
);

  wire merge_output_valid;
  wire [`NUM_HASH_PE-1:0] merge_output_mask;
  wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] merge_output_addr;
  wire [`NUM_HASH_PE-1:0] merge_output_history_valid;
  wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] merge_output_history_addr;
  wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] merge_output_meta_match_len;
  wire [`NUM_HASH_PE-1:0] merge_output_meta_match_can_ext;
  wire [`NUM_HASH_PE-1:0] merge_output_delim;
  wire [`NUM_HASH_PE*8-1:0] merge_output_data;
  wire merge_output_ready;

  hash_row_merge merge_inst (
      .clk  (clk),
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

      .output_valid(merge_output_valid),
      .output_mask(merge_output_mask),
      .output_addr(merge_output_addr),
      .output_history_valid(merge_output_history_valid),
      .output_history_addr(merge_output_history_addr),
      .output_meta_match_len(merge_output_meta_match_len),
      .output_meta_match_can_ext(merge_output_meta_match_can_ext),
      .output_delim(merge_output_delim),
      .output_data(merge_output_data),
      .output_ready(merge_output_ready)
  );

  always @(posedge clk) begin
    if (~rst_n) begin
    end else begin
      integer i;
      if (merge_output_valid & merge_output_ready) begin
        for (i = 0; i < `NUM_HASH_PE; i = i + 1) begin
          if (merge_output_history_valid[i]) begin
            $display(
                "[hash_row_merge output] head_addr=%0d, history_valid=%0d, history_addr=%0d, meta_match_len=%0d, meta_match_can_ext=%0d, delim=%0d, data=%0d",
                merge_output_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH], merge_output_history_valid[i],
                merge_output_history_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH],
                merge_output_meta_match_len[i*`META_MATCH_LEN_WIDTH+:`META_MATCH_LEN_WIDTH],
                merge_output_meta_match_can_ext[i], merge_output_delim[i],
                merge_output_data[i*8+:8]);
          end
        end
      end
    end
  end

  wire rc_output_valid;
  wire [`ADDR_WIDTH-1:0] rc_output_head_addr;
  wire [`HASH_ISSUE_WIDTH-1:0] rc_output_row_valid;
  wire [`HASH_ISSUE_WIDTH-1:0] rc_output_history_valid;
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] rc_output_history_addr;
  wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] rc_output_meta_match_len;
  wire [`HASH_ISSUE_WIDTH-1:0] rc_output_meta_match_can_ext;
  wire [`HASH_ISSUE_WIDTH*8-1:0] rc_output_data;
  wire rc_output_delim;
  wire rc_output_ready;

  reorder_crossbar rc (
      .clk  (clk),
      .rst_n(rst_n),

      .input_valid(merge_output_valid),
      .input_mask(merge_output_mask),
      .input_addr(merge_output_addr),
      .input_history_valid(merge_output_history_valid),
      .input_history_addr(merge_output_history_addr),
      .input_meta_match_len(merge_output_meta_match_len),
      .input_meta_match_can_ext(merge_output_meta_match_can_ext),
      .input_delim(merge_output_delim),
      .input_data(merge_output_data),
      .input_ready(merge_output_ready),

      .output_valid(rc_output_valid),
      .output_head_addr(rc_output_head_addr),
      .output_row_valid(rc_output_row_valid),
      .output_history_valid(rc_output_history_valid),
      .output_history_addr(rc_output_history_addr),
      .output_meta_match_len(rc_output_meta_match_len),
      .output_meta_match_can_ext(rc_output_meta_match_can_ext),
      .output_delim(rc_output_delim),
      .output_data(rc_output_data),
      .output_ready(rc_output_ready)
  );
  // 将 reorder_crossbar 的输出打印供调试检查
  always @(posedge clk) begin
    if (~rst_n) begin
    end else begin
      integer i;
      if (rc_output_valid & rc_output_ready) begin
        for (i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
          if (rc_output_row_valid[i]) begin
            $display(
                "[reorder_crossbar @ %0t] output head_addr=%0d, row_valid=%0d, history_valid=%0d, history_addr=%0d, meta_match_len=%0d, meta_match_can_ext=%0d, delim=%0d, data=%0d",
                $time, rc_output_head_addr + i[`ADDR_WIDTH-1:0], rc_output_row_valid[i],
                rc_output_history_valid[i], rc_output_history_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH],
                rc_output_meta_match_len[i*`META_MATCH_LEN_WIDTH+:`META_MATCH_LEN_WIDTH],
                rc_output_meta_match_can_ext[i], rc_output_delim, rc_output_data[i*8+:8]);
          end
        end
      end
    end
  end
  hash_row_synchronizer hrs (
      .clk  (clk),
      .rst_n(rst_n),

      .cfg_max_queued_req_num(cfg_max_queued_req_num),

      .input_valid(rc_output_valid),
      .input_head_addr(rc_output_head_addr),
      .input_row_valid(rc_output_row_valid),
      .input_history_valid(rc_output_history_valid),
      .input_history_addr(rc_output_history_addr),
      .input_meta_match_len(rc_output_meta_match_len),
      .input_meta_match_can_ext(rc_output_meta_match_can_ext),
      .input_delim(rc_output_delim),
      .input_data(rc_output_data),
      .input_ready(rc_output_ready),

      .output_valid(output_valid),
      .output_head_addr(output_head_addr),
      .output_history_valid(output_history_valid),
      .output_history_addr(output_history_addr),
      .output_meta_match_len(output_meta_match_len),
      .output_meta_match_can_ext(output_meta_match_can_ext),
      .output_delim(output_delim),
      .output_data(output_data),
      .output_ready(output_ready)
  );
endmodule
