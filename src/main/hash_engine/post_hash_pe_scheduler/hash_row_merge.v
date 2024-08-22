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
  localparam TREE_SIZE = 2 ** LAYER - 1;
  localparam LEAF_SIZE = 2 ** (LAYER - 1);

  /**
  在 hash row 内部进行合并
  1. 为了支持不是 2 的幂次方的 ROW_SIZE，叶节点数量是 2 的幂次方，多余的叶节点 valid 为 0
  2. 叶节点数量 = 2**($clog2(ROW_SIZE))
  3. 树的深度 = $clog2(ROW_SIZE) + 1
  */

  reg fire_reg [LAYER];
  reg ready_reg[LAYER];
  localparam BYPASS_W = $bits({input_mask, input_addr_vec, input_delim_vec, input_data});
  reg [BYPASS_W-1:0] mask_addr_delim_data_reg[LAYER];
  assign input_ready = ready_reg[0];
  integer layer_idx;
  always @(posedge clk) begin
    if (~rst_n) begin
      for (layer_idx = 0; layer_idx < LAYER; layer_idx = layer_idx + 1) begin
        fire_reg[layer_idx]  <= 1'b0;
        ready_reg[layer_idx] <= 1'b0;
      end
    end else begin
      fire_reg[0] <= input_valid && input_ready;
      ready_reg[LAYER-1] <= output_ready;
      mask_addr_delim_data_reg[0] <= {input_mask, input_addr_vec, input_delim_vec, input_data};
      for (layer_idx = 1; layer_idx < LAYER; layer_idx = layer_idx + 1) begin
        fire_reg[layer_idx] <= fire_reg[layer_idx-1];
        mask_addr_delim_data_reg[layer_idx] <= mask_addr_delim_data_reg[layer_idx-1];
        ready_reg[layer_idx-1] <= ready_reg[layer_idx];
      end
    end
  end

  reg [`NUM_HASH_PE*TREE_SIZE-1:0] history_valid_reg;
  reg [`NUM_HASH_PE*TREE_SIZE*`ADDR_WIDTH-1:0] history_addr_reg;
  reg [`NUM_HASH_PE*TREE_SIZE*`META_MATCH_LEN_WIDTH-1:0] meta_match_len_reg;
  reg [`NUM_HASH_PE*TREE_SIZE-1:0] meta_match_can_ext_reg;

  task automatic update_parent;
    input integer pe_idx;
    input integer parent_idx;
    input integer child_idx;
    begin
      history_valid_reg[pe_idx*TREE_SIZE+parent_idx] <= 1'b1;
      history_addr_reg[(pe_idx*TREE_SIZE + parent_idx) * `ADDR_WIDTH +: `ADDR_WIDTH] <= history_addr_reg[(pe_idx*TREE_SIZE + child_idx) * `ADDR_WIDTH +: `ADDR_WIDTH];
      meta_match_len_reg[(pe_idx*TREE_SIZE + parent_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] <= meta_match_len_reg[(pe_idx*TREE_SIZE + child_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH];
      meta_match_can_ext_reg[pe_idx*TREE_SIZE + parent_idx] <= meta_match_can_ext_reg[pe_idx*TREE_SIZE + child_idx];
    end
  endtask

  integer pe_idx, i, leaf_idx, l_idx, r_idx;
  always @(posedge clk) begin
    history_valid_reg <= meta_match_can_ext_reg;
    for (pe_idx = 0; pe_idx < `NUM_HASH_PE; pe_idx = pe_idx + 1) begin
      // 输入连接到叶子结点，如果 ROW_SIZE 不是 2 的幂次方，多余的叶节点 valid 为 0
      for (i = 0; i < LEAF_SIZE; i = i + 1) begin
        if (i < `ROW_SIZE) begin
          history_valid_reg[(pe_idx * TREE_SIZE + i + LEAF_SIZE - 1)] <= input_history_valid_vec[pe_idx*`ROW_SIZE+i];
          history_addr_reg[(pe_idx * TREE_SIZE + i + LEAF_SIZE - 1) * `ADDR_WIDTH +: `ADDR_WIDTH] <= input_history_addr_vec[pe_idx * `ROW_SIZE * `ADDR_WIDTH + i * `ADDR_WIDTH +: `ADDR_WIDTH];
          meta_match_len_reg[(pe_idx * TREE_SIZE + i + LEAF_SIZE - 1) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] <= input_meta_match_len_vec[pe_idx * `ROW_SIZE * `META_MATCH_LEN_WIDTH + i * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH];
          meta_match_can_ext_reg[(pe_idx * TREE_SIZE + i + LEAF_SIZE - 1)] <= input_meta_match_can_ext_vec[pe_idx * `ROW_SIZE + i];
        end else begin
          history_valid_reg[(pe_idx*TREE_SIZE+i+LEAF_SIZE-1)] <= 1'b0;
        end
      end
      /* 树内部的选择逻辑
        1.两个叶节点都无效，父节点无效
        2.只有一个叶节点有效，父节点选择有效的叶节点
        3.两个叶节点都有效，父节点优先选择更长的，如果一样长则选择history_addr更大的
        */
      for (i = 0; i < LEAF_SIZE - 1; i = i + 1) begin
        l_idx = i * 2 + 1;
        r_idx = i * 2 + 2;
        if (history_valid_reg[pe_idx * TREE_SIZE + l_idx] && history_valid_reg[pe_idx * TREE_SIZE + r_idx]) begin
          if (meta_match_len_reg[(pe_idx * TREE_SIZE + l_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] == meta_match_len_reg[(pe_idx * TREE_SIZE + r_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH]) begin
            if (history_addr_reg[(pe_idx * TREE_SIZE + l_idx) * `ADDR_WIDTH +: `ADDR_WIDTH] > history_addr_reg[(pe_idx * TREE_SIZE + r_idx) * `ADDR_WIDTH +: `ADDR_WIDTH]) begin
              update_parent(pe_idx, i, l_idx);
            end else begin
              update_parent(pe_idx, i, r_idx);
            end
          end else if (meta_match_len_reg[(pe_idx * TREE_SIZE + l_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] > meta_match_len_reg[(pe_idx * TREE_SIZE + r_idx) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH]) begin
            update_parent(pe_idx, i, l_idx);
          end else begin
            update_parent(pe_idx, i, r_idx);
          end
        end else if (history_valid_reg[pe_idx*TREE_SIZE+l_idx]) begin
          update_parent(pe_idx, i, l_idx);
        end else if (history_valid_reg[pe_idx*TREE_SIZE+r_idx]) begin
          update_parent(pe_idx, i, r_idx);
        end else begin
          history_valid_reg[pe_idx*TREE_SIZE+i] <= 1'b0;
        end
      end
    end
  end

  wire fifo_i_ready_tileoff;
  reg [`NUM_HASH_PE-1:0] fifo_i_mask;
  reg [`NUM_HASH_PE*`ADDR_WIDTH-1:0] fifo_i_addr;
  reg [`NUM_HASH_PE-1:0] fifo_i_history_valid;
  reg [`NUM_HASH_PE*`ADDR_WIDTH-1:0] fifo_i_history_addr;
  reg [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] fifo_i_meta_match_len;
  reg [`NUM_HASH_PE-1:0] fifo_i_meta_match_can_ext;
  reg [`NUM_HASH_PE-1:0] fifo_i_delim;
  reg [`HASH_ISSUE_WIDTH*8-1:0] fifo_i_data;

  always @(*) begin
    {fifo_i_mask, fifo_i_addr, fifo_i_delim, fifo_i_data} = mask_addr_delim_data_reg[LAYER-1];
    for (pe_idx = 0; pe_idx < `NUM_HASH_PE; pe_idx = pe_idx + 1) begin
      fifo_i_history_valid[pe_idx] = history_valid_reg[pe_idx*TREE_SIZE+0];
      fifo_i_history_addr[pe_idx*`ADDR_WIDTH+:`ADDR_WIDTH] = history_addr_reg[(pe_idx * TREE_SIZE + 0) * `ADDR_WIDTH +: `ADDR_WIDTH];
      fifo_i_meta_match_len[pe_idx*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] = meta_match_len_reg[(pe_idx * TREE_SIZE + 0) * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH];
      fifo_i_meta_match_can_ext[pe_idx] = meta_match_can_ext_reg[pe_idx*TREE_SIZE+0];
    end
  end

  fifo #(
      .W(BYPASS_W + `NUM_HASH_PE * (1 + `ADDR_WIDTH + `META_MATCH_LEN_WIDTH + 1)),
      .DEPTH(LAYER + 1)
  ) fifo_inst (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(fire_reg[LAYER-1]),
      .input_payload({
        fifo_i_mask,
        fifo_i_addr,
        fifo_i_history_valid,
        fifo_i_history_addr,
        fifo_i_meta_match_len,
        fifo_i_meta_match_can_ext,
        fifo_i_delim,
        fifo_i_data
      }),
      .input_ready(fifo_i_ready_tileoff),
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


endmodule
