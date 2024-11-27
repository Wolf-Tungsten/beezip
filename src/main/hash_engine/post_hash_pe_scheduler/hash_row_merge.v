`include "parameters.vh"

module hash_row_merge (
    input wire clk,
    input wire rst_n,

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
    output wire [`NUM_HASH_PE-1:0] output_mask,
    output wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] output_addr,
    output wire [`NUM_HASH_PE-1:0] output_history_valid,
    output wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] output_history_addr,
    output wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len,
    output wire [`NUM_HASH_PE-1:0] output_meta_match_can_ext,
    output wire [`NUM_HASH_PE-1:0] output_delim,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire output_ready
);

  localparam LAYER = $clog2(`ROW_SIZE) + 1;
  localparam ROW_SIZE_UP = 2 ** $clog2(`ROW_SIZE);

  /* verilator lint_off UNOPTFLAT */
  wire layer_i_valid[LAYER-1:0];
  wire layer_o_valid[LAYER-1:0];
  wire layer_i_ready[LAYER-1:0];
  wire layer_o_ready[LAYER-1:0];
  wire [`NUM_HASH_PE-1:0] layer_i_mask[LAYER-1:0];
  wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] layer_i_addr[LAYER-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP-1:0] layer_i_history_valid[LAYER-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP*`ADDR_WIDTH-1:0] layer_i_history_addr[LAYER-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP*`META_MATCH_LEN_WIDTH-1:0] layer_i_meta_match_len[LAYER-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP-1:0] layer_i_meta_match_can_ext[LAYER-1:0];
  wire [`NUM_HASH_PE-1:0] layer_i_delim[LAYER-1:0];
  wire [`HASH_ISSUE_WIDTH*8-1:0] layer_i_data[LAYER-1:0];
  wire [`NUM_HASH_PE-1:0] layer_o_mask[LAYER-1-1:0];
  wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] layer_o_addr[LAYER-1-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP-1:0] layer_o_history_valid[LAYER-1-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP*`ADDR_WIDTH-1:0] layer_o_history_addr[LAYER-1-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP*`META_MATCH_LEN_WIDTH-1:0] layer_o_meta_match_len[LAYER-1-1:0];
  wire [`NUM_HASH_PE*ROW_SIZE_UP-1:0] layer_o_meta_match_can_ext[LAYER-1-1:0];
  wire [`NUM_HASH_PE-1:0] layer_o_delim[LAYER-1-1:0];
  wire [`HASH_ISSUE_WIDTH*8-1:0] layer_o_data[LAYER-1-1:0];
  /* verilator lint_on UNOPTFLAT */

  genvar g_l;
  generate
    for(g_l = 0; g_l < LAYER; g_l = g_l + 1) begin
      if(g_l == 0) begin
        // 第一层输入接入到输入端口
        assign layer_i_valid[g_l] = input_valid;
        assign layer_i_mask[g_l] = input_mask;
        assign layer_i_addr[g_l] = input_addr_vec;
        assign layer_i_history_valid[g_l] = input_history_valid_vec;
        assign layer_i_history_addr[g_l] = input_history_addr_vec;
        assign layer_i_meta_match_len[g_l] = input_meta_match_len_vec;
        assign layer_i_meta_match_can_ext[g_l] = input_meta_match_can_ext_vec;
        assign layer_i_delim[g_l] = input_delim_vec;
        assign layer_i_data[g_l] = input_data;
        assign input_ready = layer_o_ready[g_l];
        // 第一层的 layer_i 直通到 layer_o
        assign layer_o_valid[g_l] = layer_i_valid[g_l];
        assign layer_o_mask[g_l] = layer_i_mask[g_l];
        assign layer_o_addr[g_l] = layer_i_addr[g_l];
        assign layer_o_history_valid[g_l] = layer_i_history_valid[g_l];
        assign layer_o_history_addr[g_l] = layer_i_history_addr[g_l];
        assign layer_o_meta_match_len[g_l] = layer_i_meta_match_len[g_l];
        assign layer_o_meta_match_can_ext[g_l] = layer_i_meta_match_can_ext[g_l];
        assign layer_o_delim[g_l] = layer_i_delim[g_l];
        assign layer_o_data[g_l] = layer_i_data[g_l];
        assign layer_i_ready[g_l] = layer_o_ready[g_l];        
      end else if (g_l == LAYER - 1) begin
        // 最后一层的输入接入到 pingpong_reg 再连接到模块输出
        pingpong_reg #(.W($bits({output_mask, output_addr, output_history_valid, output_history_addr, output_meta_match_len, output_meta_match_can_ext, output_delim, output_data}))) pingpong_reg_inst (
            .clk(clk),
            .rst_n(rst_n),
            .input_valid(layer_i_valid[g_l]),
            .input_payload({
              layer_i_mask[g_l],
              layer_i_addr[g_l],
              layer_i_history_valid[g_l][`NUM_HASH_PE-1:0],
              layer_i_history_addr[g_l][`NUM_HASH_PE*`ADDR_WIDTH-1:0],
              layer_i_meta_match_len[g_l][`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0],
              layer_i_meta_match_can_ext[g_l][`NUM_HASH_PE-1:0],
              layer_i_delim[g_l],
              layer_i_data[g_l]
            }),
            .input_ready(layer_i_ready[g_l]),
            .output_valid(output_valid),
            .output_payload({
              output_mask,
              output_addr,
              output_history_valid,
              output_history_addr,
              output_meta_match_len,
              output_meta_match_can_ext,
              output_delim,
              output_data
            }),
            .output_ready(output_ready)
        );
      end else begin
        // 输入通过 forward reg 连接到输出
        localparam LAYER_ROW_SIZE = ROW_SIZE_UP / (2 ** g_l);
        forward_reg #(.W(`NUM_HASH_PE * (1 + `ADDR_WIDTH + 1) + `NUM_HASH_PE * LAYER_ROW_SIZE * (1 + `ADDR_WIDTH + `META_MATCH_LEN_WIDTH + 1) + `HASH_ISSUE_WIDTH * 8)) forward_reg_inst (
            .clk(clk),
            .rst_n(rst_n),
            .input_valid(layer_i_valid[g_l]),
            .input_payload({
              layer_i_mask[g_l],
              layer_i_addr[g_l],
              layer_i_history_valid[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE-1:0],
              layer_i_history_addr[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE*`ADDR_WIDTH-1:0],
              layer_i_meta_match_len[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0],
              layer_i_meta_match_can_ext[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE-1:0],
              layer_i_delim[g_l],
              layer_i_data[g_l]
            }),
            .input_ready(layer_i_ready[g_l]),
            .output_valid(layer_o_valid[g_l]),
            .output_payload({
              layer_o_mask[g_l],
              layer_o_addr[g_l],
              layer_o_history_valid[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE-1:0],
              layer_o_history_addr[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE*`ADDR_WIDTH-1:0],
              layer_o_meta_match_len[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0],
              layer_o_meta_match_can_ext[g_l][`NUM_HASH_PE*LAYER_ROW_SIZE-1:0],
              layer_o_delim[g_l],
              layer_o_data[g_l]
            }),
            .output_ready(layer_o_ready[g_l])
        );
      end
    end
  endgenerate

  // 层次之间的二叉树合并
  genvar g_i, g_j;
  generate
    for(g_l = 1; g_l < LAYER; g_l = g_l + 1) begin
      assign layer_i_valid[g_l] = layer_o_valid[g_l-1];
      assign layer_i_mask[g_l] = layer_o_mask[g_l-1];
      assign layer_i_addr[g_l] = layer_o_addr[g_l-1];
      assign layer_i_delim[g_l] = layer_o_delim[g_l-1];
      assign layer_i_data[g_l] = layer_o_data[g_l-1];
      assign layer_o_ready[g_l-1] = layer_i_ready[g_l];
      localparam PREV_LAYER_ROW_SIZE = ROW_SIZE_UP / (2 ** (g_l-1));
      localparam LAYER_ROW_SIZE = ROW_SIZE_UP / (2 ** g_l);
      for(g_i = 0; g_i < `NUM_HASH_PE; g_i = g_i + 1) begin
        wire [PREV_LAYER_ROW_SIZE-1:0] prev_layer_history_valid = layer_o_history_valid[g_l-1][g_i*PREV_LAYER_ROW_SIZE +: PREV_LAYER_ROW_SIZE];
        wire [PREV_LAYER_ROW_SIZE*`ADDR_WIDTH-1:0] prev_layer_history_addr = layer_o_history_addr[g_l-1][g_i*PREV_LAYER_ROW_SIZE*`ADDR_WIDTH +: PREV_LAYER_ROW_SIZE*`ADDR_WIDTH];
        wire [PREV_LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] prev_layer_meta_match_len = layer_o_meta_match_len[g_l-1][g_i*PREV_LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH +: PREV_LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH];
        wire [PREV_LAYER_ROW_SIZE-1:0] prev_layer_meta_match_can_ext = layer_o_meta_match_can_ext[g_l-1][g_i*PREV_LAYER_ROW_SIZE +: PREV_LAYER_ROW_SIZE];
        wire [LAYER_ROW_SIZE-1:0] layer_history_valid;
        wire [LAYER_ROW_SIZE*`ADDR_WIDTH-1:0] layer_history_addr;
        wire [LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] layer_meta_match_len;
        wire [LAYER_ROW_SIZE-1:0] layer_meta_match_can_ext;
        assign layer_i_history_valid[g_l][g_i*LAYER_ROW_SIZE +: LAYER_ROW_SIZE] = layer_history_valid;
        assign layer_i_history_addr[g_l][g_i*LAYER_ROW_SIZE*`ADDR_WIDTH +: LAYER_ROW_SIZE*`ADDR_WIDTH] = layer_history_addr;
        assign layer_i_meta_match_len[g_l][g_i*LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH +: LAYER_ROW_SIZE*`META_MATCH_LEN_WIDTH] = layer_meta_match_len;
        assign layer_i_meta_match_can_ext[g_l][g_i*LAYER_ROW_SIZE +: LAYER_ROW_SIZE] = layer_meta_match_can_ext;
        for(g_j = 0; g_j < LAYER_ROW_SIZE; g_j = g_j + 1) begin
          wire child_l_history_valid = prev_layer_history_valid[g_j*2];
          wire child_r_history_valid = prev_layer_history_valid[g_j*2+1];
          wire [`ADDR_WIDTH-1:0] child_l_history_addr = prev_layer_history_addr[g_j*2*`ADDR_WIDTH +: `ADDR_WIDTH];
          wire [`ADDR_WIDTH-1:0] child_r_history_addr = prev_layer_history_addr[(g_j*2+1)*`ADDR_WIDTH +: `ADDR_WIDTH];
          wire [`META_MATCH_LEN_WIDTH-1:0] child_l_meta_match_len = prev_layer_meta_match_len[g_j*2*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH];
          wire [`META_MATCH_LEN_WIDTH-1:0] child_r_meta_match_len = prev_layer_meta_match_len[(g_j*2+1)*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH];
          wire child_l_meta_match_can_ext = prev_layer_meta_match_can_ext[g_j*2];
          wire child_r_meta_match_can_ext = prev_layer_meta_match_can_ext[g_j*2+1];
          reg parent_history_valid;
          reg [`ADDR_WIDTH-1:0] parent_history_addr;
          reg [`META_MATCH_LEN_WIDTH-1:0] parent_meta_match_len;
          reg parent_meta_match_can_ext;
          assign layer_history_valid[g_j] = parent_history_valid;
          assign layer_history_addr[g_j*`ADDR_WIDTH +: `ADDR_WIDTH] = parent_history_addr;
          assign layer_meta_match_len[g_j*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] = parent_meta_match_len;
          assign layer_meta_match_can_ext[g_j] = parent_meta_match_can_ext;
          always @(*) begin
            parent_history_valid = child_l_history_valid | child_r_history_valid;
            if (child_l_history_valid && child_r_history_valid) begin
              if (child_l_meta_match_len == child_r_meta_match_len) begin
                if (child_l_history_addr > child_r_history_addr) begin
                  parent_history_addr = child_l_history_addr;
                  parent_meta_match_len = child_l_meta_match_len;
                  parent_meta_match_can_ext = child_l_meta_match_can_ext;
                end else begin
                  parent_history_addr = child_r_history_addr;
                  parent_meta_match_len = child_r_meta_match_len;
                  parent_meta_match_can_ext = child_r_meta_match_can_ext;
                end
              end else if (child_l_meta_match_len > child_r_meta_match_len) begin
                parent_history_addr = child_l_history_addr;
                parent_meta_match_len = child_l_meta_match_len;
                parent_meta_match_can_ext = child_l_meta_match_can_ext;
              end else begin
                parent_history_addr = child_r_history_addr;
                parent_meta_match_len = child_r_meta_match_len;
                parent_meta_match_can_ext = child_r_meta_match_can_ext;
              end
            end else if (child_l_history_valid) begin
              parent_history_addr = child_l_history_addr;
              parent_meta_match_len = child_l_meta_match_len;
              parent_meta_match_can_ext = child_l_meta_match_can_ext;
            end else if (child_r_history_valid) begin
              parent_history_addr = child_r_history_addr;
              parent_meta_match_len = child_r_meta_match_len;
              parent_meta_match_can_ext = child_r_meta_match_can_ext;
            end else begin
              parent_history_addr = '0;
              parent_meta_match_len = '0;
              parent_meta_match_can_ext = 1'b0;
            end
          end
        end
      end
    end
  endgenerate


endmodule
