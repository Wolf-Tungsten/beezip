`include "parameters.vh"

module match_engine (
    input wire clk,
    input wire rst_n,

    input wire i_hash_batch_valid,
    input wire [`ADDR_WIDTH-1:0] i_hash_batch_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] i_hash_batch_history_valid,
    input wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] i_hash_batch_history_addr,
    input wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] i_hash_batch_meta_match_len,
    input wire [`HASH_ISSUE_WIDTH-1:0] i_hash_batch_meta_match_can_ext,
    input wire i_hash_batch_delim,
    output wire i_hash_batch_ready,

    // output seq port
    output wire o_seq_packet_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_strb,
    output wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] o_seq_packet_ll,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_ml,
    output wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] o_seq_packet_offset,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_overlap,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_eoj,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_delim,
    input wire o_seq_packet_ready,

    // match pe write port
    input wire [`ADDR_WIDTH-1:0] i_match_pe_write_addr,
    input wire [`MATCH_PE_WIDTH*8-1:0] i_match_pe_write_data,
    input wire i_match_pe_write_enable
);

  reg rst_n_p0_reg;
  always @(posedge clk) begin
    rst_n_p0_reg <= rst_n;
  end

  // 所有 mesh router cluster 之间的连接
  wire [`NUM_SHARED_MATCH_PE-1:0] i_n_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_e_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_s_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_w_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_l_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_n_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_e_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_s_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_w_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_l_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_n_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_e_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_s_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_w_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_l_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_n_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_e_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_s_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_w_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_l_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_n_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_e_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_s_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_w_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] i_l_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_n_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_e_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_s_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_w_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_l_valid[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_n_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_e_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_s_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_w_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_l_dst_x[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_n_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_e_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_s_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_w_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_l_dst_y[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_n_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_e_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_s_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_w_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_l_payload[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_n_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_e_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_s_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_w_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];
  wire [`NUM_SHARED_MATCH_PE-1:0] o_l_ready[`MESH_X_SIZE-1:0][`MESH_Y_SIZE-1:0];

  genvar mesh_x_idx, mesh_y_idx;
  generate
    // 创建 mesh router cluster, 建立 mesh router 之间连接
    for (
        mesh_x_idx = 0; mesh_x_idx < `MESH_X_SIZE; mesh_x_idx = mesh_x_idx + 1
    ) begin : mesh_x_idx_gen
      reg mesh_col_rst_n_p1_reg;
      always @(posedge clk) begin
        mesh_col_rst_n_p1_reg <= rst_n_p0_reg;
      end
      for (
          mesh_y_idx = 0; mesh_y_idx < `MESH_Y_SIZE; mesh_y_idx = mesh_y_idx + 1
      ) begin : mesh_y_idx_gen
        mesh_router_cluster #(
            .MESH_X_IDX(mesh_x_idx),
            .MESH_Y_IDX(mesh_y_idx)
        ) mesh_router_cluster_inst (
            .clk(clk),
            .rst_n(mesh_col_rst_n_p1_reg),
            .i_n_valid(i_n_valid[mesh_x_idx][mesh_y_idx]),
            .i_e_valid(i_e_valid[mesh_x_idx][mesh_y_idx]),
            .i_s_valid(i_s_valid[mesh_x_idx][mesh_y_idx]),
            .i_w_valid(i_w_valid[mesh_x_idx][mesh_y_idx]),
            .i_l_valid(i_l_valid[mesh_x_idx][mesh_y_idx]),
            .i_n_dst_x(i_n_dst_x[mesh_x_idx][mesh_y_idx]),
            .i_e_dst_x(i_e_dst_x[mesh_x_idx][mesh_y_idx]),
            .i_s_dst_x(i_s_dst_x[mesh_x_idx][mesh_y_idx]),
            .i_w_dst_x(i_w_dst_x[mesh_x_idx][mesh_y_idx]),
            .i_l_dst_x(i_l_dst_x[mesh_x_idx][mesh_y_idx]),
            .i_n_dst_y(i_n_dst_y[mesh_x_idx][mesh_y_idx]),
            .i_e_dst_y(i_e_dst_y[mesh_x_idx][mesh_y_idx]),
            .i_s_dst_y(i_s_dst_y[mesh_x_idx][mesh_y_idx]),
            .i_w_dst_y(i_w_dst_y[mesh_x_idx][mesh_y_idx]),
            .i_l_dst_y(i_l_dst_y[mesh_x_idx][mesh_y_idx]),
            .i_n_payload(i_n_payload[mesh_x_idx][mesh_y_idx]),
            .i_e_payload(i_e_payload[mesh_x_idx][mesh_y_idx]),
            .i_s_payload(i_s_payload[mesh_x_idx][mesh_y_idx]),
            .i_w_payload(i_w_payload[mesh_x_idx][mesh_y_idx]),
            .i_l_payload(i_l_payload[mesh_x_idx][mesh_y_idx]),
            .i_n_ready(i_n_ready[mesh_x_idx][mesh_y_idx]),
            .i_e_ready(i_e_ready[mesh_x_idx][mesh_y_idx]),
            .i_s_ready(i_s_ready[mesh_x_idx][mesh_y_idx]),
            .i_w_ready(i_w_ready[mesh_x_idx][mesh_y_idx]),
            .i_l_ready(i_l_ready[mesh_x_idx][mesh_y_idx]),
            .o_n_valid(o_n_valid[mesh_x_idx][mesh_y_idx]),
            .o_e_valid(o_e_valid[mesh_x_idx][mesh_y_idx]),
            .o_s_valid(o_s_valid[mesh_x_idx][mesh_y_idx]),
            .o_w_valid(o_w_valid[mesh_x_idx][mesh_y_idx]),
            .o_l_valid(o_l_valid[mesh_x_idx][mesh_y_idx]),
            .o_n_dst_x(o_n_dst_x[mesh_x_idx][mesh_y_idx]),
            .o_e_dst_x(o_e_dst_x[mesh_x_idx][mesh_y_idx]),
            .o_s_dst_x(o_s_dst_x[mesh_x_idx][mesh_y_idx]),
            .o_w_dst_x(o_w_dst_x[mesh_x_idx][mesh_y_idx]),
            .o_l_dst_x(o_l_dst_x[mesh_x_idx][mesh_y_idx]),
            .o_n_dst_y(o_n_dst_y[mesh_x_idx][mesh_y_idx]),
            .o_e_dst_y(o_e_dst_y[mesh_x_idx][mesh_y_idx]),
            .o_s_dst_y(o_s_dst_y[mesh_x_idx][mesh_y_idx]),
            .o_w_dst_y(o_w_dst_y[mesh_x_idx][mesh_y_idx]),
            .o_l_dst_y(o_l_dst_y[mesh_x_idx][mesh_y_idx]),
            .o_n_payload(o_n_payload[mesh_x_idx][mesh_y_idx]),
            .o_e_payload(o_e_payload[mesh_x_idx][mesh_y_idx]),
            .o_s_payload(o_s_payload[mesh_x_idx][mesh_y_idx]),
            .o_w_payload(o_w_payload[mesh_x_idx][mesh_y_idx]),
            .o_l_payload(o_l_payload[mesh_x_idx][mesh_y_idx]),
            .o_n_ready(o_n_ready[mesh_x_idx][mesh_y_idx]),
            .o_e_ready(o_e_ready[mesh_x_idx][mesh_y_idx]),
            .o_s_ready(o_s_ready[mesh_x_idx][mesh_y_idx]),
            .o_w_ready(o_w_ready[mesh_x_idx][mesh_y_idx]),
            .o_l_ready(o_l_ready[mesh_x_idx][mesh_y_idx])
        );

        if (mesh_x_idx > 0) begin
          assign i_w_valid[mesh_x_idx][mesh_y_idx]   = o_e_valid[mesh_x_idx-1][mesh_y_idx];
          assign i_w_dst_x[mesh_x_idx][mesh_y_idx]   = o_e_dst_x[mesh_x_idx-1][mesh_y_idx];
          assign i_w_dst_y[mesh_x_idx][mesh_y_idx]   = o_e_dst_y[mesh_x_idx-1][mesh_y_idx];
          assign i_w_payload[mesh_x_idx][mesh_y_idx] = o_e_payload[mesh_x_idx-1][mesh_y_idx];
          assign o_e_ready[mesh_x_idx-1][mesh_y_idx] = i_w_ready[mesh_x_idx][mesh_y_idx];
        end else begin
          assign i_w_valid[mesh_x_idx][mesh_y_idx]   = 1'b0;
          assign i_w_dst_x[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_w_dst_y[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_w_payload[mesh_x_idx][mesh_y_idx] = '0;
        end

        if (mesh_x_idx < `MESH_X_SIZE - 1) begin
          assign i_e_valid[mesh_x_idx][mesh_y_idx]   = o_w_valid[mesh_x_idx+1][mesh_y_idx];
          assign i_e_dst_x[mesh_x_idx][mesh_y_idx]   = o_w_dst_x[mesh_x_idx+1][mesh_y_idx];
          assign i_e_dst_y[mesh_x_idx][mesh_y_idx]   = o_w_dst_y[mesh_x_idx+1][mesh_y_idx];
          assign i_e_payload[mesh_x_idx][mesh_y_idx] = o_w_payload[mesh_x_idx+1][mesh_y_idx];
          assign o_w_ready[mesh_x_idx+1][mesh_y_idx] = i_e_ready[mesh_x_idx][mesh_y_idx];
        end else begin
          assign i_e_valid[mesh_x_idx][mesh_y_idx]   = 1'b0;
          assign i_e_dst_x[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_e_dst_y[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_e_payload[mesh_x_idx][mesh_y_idx] = '0;
        end

        if (mesh_y_idx > 0) begin
          assign i_n_valid[mesh_x_idx][mesh_y_idx]   = o_s_valid[mesh_x_idx][mesh_y_idx-1];
          assign i_n_dst_x[mesh_x_idx][mesh_y_idx]   = o_s_dst_x[mesh_x_idx][mesh_y_idx-1];
          assign i_n_dst_y[mesh_x_idx][mesh_y_idx]   = o_s_dst_y[mesh_x_idx][mesh_y_idx-1];
          assign i_n_payload[mesh_x_idx][mesh_y_idx] = o_s_payload[mesh_x_idx][mesh_y_idx-1];
          assign o_s_ready[mesh_x_idx][mesh_y_idx-1] = i_n_ready[mesh_x_idx][mesh_y_idx];
        end else begin
          assign i_n_valid[mesh_x_idx][mesh_y_idx]   = 1'b0;
          assign i_n_dst_x[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_n_dst_y[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_n_payload[mesh_x_idx][mesh_y_idx] = '0;
        end

        if (mesh_y_idx < `MESH_Y_SIZE - 1) begin
          assign i_s_valid[mesh_x_idx][mesh_y_idx]   = o_n_valid[mesh_x_idx][mesh_y_idx+1];
          assign i_s_dst_x[mesh_x_idx][mesh_y_idx]   = o_n_dst_x[mesh_x_idx][mesh_y_idx+1];
          assign i_s_dst_y[mesh_x_idx][mesh_y_idx]   = o_n_dst_y[mesh_x_idx][mesh_y_idx+1];
          assign i_s_payload[mesh_x_idx][mesh_y_idx] = o_n_payload[mesh_x_idx][mesh_y_idx+1];
          assign o_n_ready[mesh_x_idx][mesh_y_idx+1] = i_s_ready[mesh_x_idx][mesh_y_idx];
        end else begin
          assign i_s_valid[mesh_x_idx][mesh_y_idx]   = 1'b0;
          assign i_s_dst_x[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_s_dst_y[mesh_x_idx][mesh_y_idx]   = '0;
          assign i_s_payload[mesh_x_idx][mesh_y_idx] = '0;
        end
      end
    end
  endgenerate

  // 创建 hash batch bus
  wire hash_batch_bus_i_valid[`NUM_JOB_PE-1:0];
  wire [`ADDR_WIDTH-1:0] hash_batch_bus_i_head_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_i_history_valid[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_bus_i_history_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_batch_bus_i_meta_match_len[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_i_meta_match_can_ext[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_i_delim[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_i_ready[`NUM_JOB_PE-1:0];

  wire hash_batch_bus_o_this_valid[`NUM_JOB_PE-1:0];
  wire [`ADDR_WIDTH-1:0] hash_batch_bus_o_this_head_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_o_this_history_valid[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_bus_o_this_history_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_batch_bus_o_this_meta_match_len[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_o_this_meta_match_can_ext[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_o_this_delim[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_o_this_ready[`NUM_JOB_PE-1:0];

  wire hash_batch_bus_o_next_valid[`NUM_JOB_PE-1:0];
  wire [`ADDR_WIDTH-1:0] hash_batch_bus_o_next_head_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_o_next_history_valid[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_bus_o_next_history_addr[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_batch_bus_o_next_meta_match_len[`NUM_JOB_PE-1:0];
  wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_bus_o_next_meta_match_can_ext[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_o_next_delim[`NUM_JOB_PE-1:0];
  wire hash_batch_bus_o_next_ready[`NUM_JOB_PE-1:0];

  reg [`NUM_JOB_PE / 4 - 1 : 0] hbbn_spbn_rst_n_p1_reg;
  always @(posedge clk) begin
    hbbn_spbn_rst_n_p1_reg <= {(`NUM_JOB_PE / 4) {rst_n_p0_reg}};
  end
  genvar hbbn_idx;  // hash batch bus node
  generate
    for (hbbn_idx = 0; hbbn_idx < `NUM_JOB_PE; hbbn_idx = hbbn_idx + 1) begin : hbbn_node_gen
      localparam h_idx = hbbn_idx;
      hash_batch_bus_node #(
          .IDX  (h_idx),
          .PIPED(1)
      ) hbbn_inst (
          .clk(clk),
          .rst_n(hbbn_spbn_rst_n_p1_reg[hbbn_idx>>2]),
          .i_valid(hash_batch_bus_i_valid[hbbn_idx]),
          .i_head_addr(hash_batch_bus_i_head_addr[hbbn_idx]),
          .i_history_valid(hash_batch_bus_i_history_valid[hbbn_idx]),
          .i_history_addr(hash_batch_bus_i_history_addr[hbbn_idx]),
          .i_meta_match_len(hash_batch_bus_i_meta_match_len[hbbn_idx]),
          .i_meta_match_can_ext(hash_batch_bus_i_meta_match_can_ext[hbbn_idx]),
          .i_delim(hash_batch_bus_i_delim[hbbn_idx]),
          .i_ready(hash_batch_bus_i_ready[hbbn_idx]),
          .o_this_valid(hash_batch_bus_o_this_valid[hbbn_idx]),
          .o_this_head_addr(hash_batch_bus_o_this_head_addr[hbbn_idx]),
          .o_this_history_valid(hash_batch_bus_o_this_history_valid[hbbn_idx]),
          .o_this_history_addr(hash_batch_bus_o_this_history_addr[hbbn_idx]),
          .o_this_meta_match_len(hash_batch_bus_o_this_meta_match_len[hbbn_idx]),
          .o_this_meta_match_can_ext(hash_batch_bus_o_this_meta_match_can_ext[hbbn_idx]),
          .o_this_delim(hash_batch_bus_o_this_delim[hbbn_idx]),
          .o_this_ready(hash_batch_bus_o_this_ready[hbbn_idx]),
          .o_next_valid(hash_batch_bus_o_next_valid[hbbn_idx]),
          .o_next_head_addr(hash_batch_bus_o_next_head_addr[hbbn_idx]),
          .o_next_history_valid(hash_batch_bus_o_next_history_valid[hbbn_idx]),
          .o_next_history_addr(hash_batch_bus_o_next_history_addr[hbbn_idx]),
          .o_next_meta_match_len(hash_batch_bus_o_next_meta_match_len[hbbn_idx]),
          .o_next_meta_match_can_ext(hash_batch_bus_o_next_meta_match_can_ext[hbbn_idx]),
          .o_next_delim(hash_batch_bus_o_next_delim[hbbn_idx]),
          .o_next_ready(hash_batch_bus_o_next_ready[hbbn_idx])
      );

      if (hbbn_idx > 0) begin
        assign hash_batch_bus_i_valid[hbbn_idx] = hash_batch_bus_o_next_valid[hbbn_idx-1];
        assign hash_batch_bus_i_head_addr[hbbn_idx] = hash_batch_bus_o_next_head_addr[hbbn_idx-1];
        assign hash_batch_bus_i_history_valid[hbbn_idx] = hash_batch_bus_o_next_history_valid[hbbn_idx-1];
        assign hash_batch_bus_i_history_addr[hbbn_idx] = hash_batch_bus_o_next_history_addr[hbbn_idx-1];
        assign hash_batch_bus_i_meta_match_len[hbbn_idx] = hash_batch_bus_o_next_meta_match_len[hbbn_idx-1];
        assign hash_batch_bus_i_meta_match_can_ext[hbbn_idx] = hash_batch_bus_o_next_meta_match_can_ext[hbbn_idx-1];
        assign hash_batch_bus_i_delim[hbbn_idx] = hash_batch_bus_o_next_delim[hbbn_idx-1];
        assign hash_batch_bus_o_next_ready[hbbn_idx-1] = hash_batch_bus_i_ready[hbbn_idx];
      end
    end
  endgenerate
  assign hash_batch_bus_o_next_ready[`NUM_JOB_PE-1] = 1'b0;  // 结尾的 ready tie off
  // 第一个节点的输入来自外部
  assign hash_batch_bus_i_valid[0] = i_hash_batch_valid;
  assign hash_batch_bus_i_head_addr[0] = i_hash_batch_head_addr;
  assign hash_batch_bus_i_history_valid[0] = i_hash_batch_history_valid;
  assign hash_batch_bus_i_history_addr[0] = i_hash_batch_history_addr;
  assign hash_batch_bus_i_meta_match_len[0] = i_hash_batch_meta_match_len;
  assign hash_batch_bus_i_meta_match_can_ext[0] = i_hash_batch_meta_match_can_ext;
  assign hash_batch_bus_i_delim[0] = i_hash_batch_delim;
  assign i_hash_batch_ready = hash_batch_bus_i_ready[0];

  // 创建 seq packet bus
  wire seq_packet_bus_i_token_valid[`NUM_JOB_PE-1:0];
  wire seq_packet_bus_i_token_ready[`NUM_JOB_PE-1:0];

  wire seq_packet_bus_o_token_valid[`NUM_JOB_PE-1:0];
  wire seq_packet_bus_o_token_ready[`NUM_JOB_PE-1:0];

  wire seq_packet_bus_i_local_valid[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_strb[`NUM_JOB_PE-1:0];
  wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_ll[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_ml[`NUM_JOB_PE-1:0];
  wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_offset[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_overlap[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_eoj[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_local_delim[`NUM_JOB_PE-1:0];
  wire seq_packet_bus_i_local_ready[`NUM_JOB_PE-1:0];

  wire seq_packet_bus_i_prev_valid[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_strb[`NUM_JOB_PE-1:0];
  wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_ll[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_ml[`NUM_JOB_PE-1:0];
  wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_offset[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_overlap[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_eoj[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_i_prev_delim[`NUM_JOB_PE-1:0];
  wire seq_packet_bus_i_prev_ready[`NUM_JOB_PE-1:0];

  wire seq_packet_bus_o_next_valid[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_strb[`NUM_JOB_PE-1:0];
  wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_ll[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_ml[`NUM_JOB_PE-1:0];
  wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_offset[`NUM_JOB_PE-1:0];
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_overlap[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_eoj[`NUM_JOB_PE-1:0];
  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_bus_o_next_delim[`NUM_JOB_PE-1:0];
  wire seq_packet_bus_o_next_ready[`NUM_JOB_PE-1:0];

  genvar spbn_idx;  // seq packet bus node
  generate
    for (spbn_idx = 0; spbn_idx < `NUM_JOB_PE; spbn_idx = spbn_idx + 1) begin : spbn_node_gen
      seq_packet_bus_node #(
          .FIRST(spbn_idx == 0),
          .SPBN_IDX(spbn_idx)
      ) spbn_inst (
          .clk(clk),
          .rst_n(hbbn_spbn_rst_n_p1_reg[spbn_idx>>2]),
          .i_token_valid(seq_packet_bus_i_token_valid[spbn_idx]),
          .i_token_ready(seq_packet_bus_i_token_ready[spbn_idx]),
          .o_token_valid(seq_packet_bus_o_token_valid[spbn_idx]),
          .o_token_ready(seq_packet_bus_o_token_ready[spbn_idx]),
          .i_local_valid(seq_packet_bus_i_local_valid[spbn_idx]),
          .i_local_strb(seq_packet_bus_i_local_strb[spbn_idx]),
          .i_local_ll(seq_packet_bus_i_local_ll[spbn_idx]),
          .i_local_ml(seq_packet_bus_i_local_ml[spbn_idx]),
          .i_local_offset(seq_packet_bus_i_local_offset[spbn_idx]),
          .i_local_overlap(seq_packet_bus_i_local_overlap[spbn_idx]),
          .i_local_eoj(seq_packet_bus_i_local_eoj[spbn_idx]),
          .i_local_delim(seq_packet_bus_i_local_delim[spbn_idx]),
          .i_local_ready(seq_packet_bus_i_local_ready[spbn_idx]),
          .i_prev_valid(seq_packet_bus_i_prev_valid[spbn_idx]),
          .i_prev_strb(seq_packet_bus_i_prev_strb[spbn_idx]),
          .i_prev_ll(seq_packet_bus_i_prev_ll[spbn_idx]),
          .i_prev_ml(seq_packet_bus_i_prev_ml[spbn_idx]),
          .i_prev_offset(seq_packet_bus_i_prev_offset[spbn_idx]),
          .i_prev_overlap(seq_packet_bus_i_prev_overlap[spbn_idx]),
          .i_prev_eoj(seq_packet_bus_i_prev_eoj[spbn_idx]),
          .i_prev_delim(seq_packet_bus_i_prev_delim[spbn_idx]),
          .i_prev_ready(seq_packet_bus_i_prev_ready[spbn_idx]),
          .o_next_valid(seq_packet_bus_o_next_valid[spbn_idx]),
          .o_next_strb(seq_packet_bus_o_next_strb[spbn_idx]),
          .o_next_ll(seq_packet_bus_o_next_ll[spbn_idx]),
          .o_next_ml(seq_packet_bus_o_next_ml[spbn_idx]),
          .o_next_offset(seq_packet_bus_o_next_offset[spbn_idx]),
          .o_next_overlap(seq_packet_bus_o_next_overlap[spbn_idx]),
          .o_next_eoj(seq_packet_bus_o_next_eoj[spbn_idx]),
          .o_next_delim(seq_packet_bus_o_next_delim[spbn_idx]),
          .o_next_ready(seq_packet_bus_o_next_ready[spbn_idx])
      );

      // token 组成令牌环
      if (spbn_idx > 0) begin
        assign seq_packet_bus_i_token_valid[spbn_idx]   = seq_packet_bus_o_token_valid[spbn_idx-1];
        assign seq_packet_bus_o_token_ready[spbn_idx-1] = seq_packet_bus_i_token_ready[spbn_idx];
      end else begin
        assign seq_packet_bus_i_token_valid[0] = seq_packet_bus_o_token_valid[`NUM_JOB_PE-1];
        assign seq_packet_bus_o_token_ready[`NUM_JOB_PE-1] = seq_packet_bus_i_token_ready[0];
      end

      if (spbn_idx > 0) begin
        assign seq_packet_bus_i_prev_valid[spbn_idx] = seq_packet_bus_o_next_valid[spbn_idx-1];
        assign seq_packet_bus_i_prev_strb[spbn_idx] = seq_packet_bus_o_next_strb[spbn_idx-1];
        assign seq_packet_bus_i_prev_ll[spbn_idx] = seq_packet_bus_o_next_ll[spbn_idx-1];
        assign seq_packet_bus_i_prev_ml[spbn_idx] = seq_packet_bus_o_next_ml[spbn_idx-1];
        assign seq_packet_bus_i_prev_offset[spbn_idx] = seq_packet_bus_o_next_offset[spbn_idx-1];
        assign seq_packet_bus_i_prev_overlap[spbn_idx] = seq_packet_bus_o_next_overlap[spbn_idx-1];
        assign seq_packet_bus_i_prev_eoj[spbn_idx] = seq_packet_bus_o_next_eoj[spbn_idx-1];
        assign seq_packet_bus_i_prev_delim[spbn_idx] = seq_packet_bus_o_next_delim[spbn_idx-1];
        assign seq_packet_bus_o_next_ready[spbn_idx-1] = seq_packet_bus_i_prev_ready[spbn_idx];
      end
    end
  endgenerate
  assign seq_packet_bus_i_prev_valid[0] = 1'b0;
  assign seq_packet_bus_i_prev_strb[0] = '0;
  assign seq_packet_bus_i_prev_ll[0] = '0;
  assign seq_packet_bus_i_prev_ml[0] = '0;
  assign seq_packet_bus_i_prev_offset[0] = '0;
  assign seq_packet_bus_i_prev_overlap[0] = '0;
  assign seq_packet_bus_i_prev_eoj[0] = '0;
  assign seq_packet_bus_i_prev_delim[0] = '0;
  assign o_seq_packet_valid = seq_packet_bus_o_next_valid[`NUM_JOB_PE-1];
  assign o_seq_packet_strb = seq_packet_bus_o_next_strb[`NUM_JOB_PE-1];
  assign o_seq_packet_ll = seq_packet_bus_o_next_ll[`NUM_JOB_PE-1];
  assign o_seq_packet_ml = seq_packet_bus_o_next_ml[`NUM_JOB_PE-1];
  assign o_seq_packet_offset = seq_packet_bus_o_next_offset[`NUM_JOB_PE-1];
  assign o_seq_packet_overlap = seq_packet_bus_o_next_overlap[`NUM_JOB_PE-1];
  assign o_seq_packet_eoj = seq_packet_bus_o_next_eoj[`NUM_JOB_PE-1];
  assign o_seq_packet_delim = seq_packet_bus_o_next_delim[`NUM_JOB_PE-1];
  assign seq_packet_bus_o_next_ready[`NUM_JOB_PE-1] = o_seq_packet_ready;

  generate
    for (
        mesh_x_idx = 0; mesh_x_idx < `MESH_X_SIZE; mesh_x_idx = mesh_x_idx + 1
    ) begin : job_match_pe_gen_x
      reg [`ADDR_WIDTH-1:0] match_pe_write_addr_reg;
      reg [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data_reg;
      reg match_pe_write_enable_reg;
      always @(posedge clk) begin
        if (rst_n == 1'b0) begin
          match_pe_write_enable_reg <= 1'b0;
        end else begin
          match_pe_write_addr_reg   <= i_match_pe_write_addr;
          match_pe_write_data_reg   <= i_match_pe_write_data;
          match_pe_write_enable_reg <= i_match_pe_write_enable;
        end
      end
      reg col_smpc_jmpc_rst_n_p1_reg;
      always @(posedge clk) begin
        col_smpc_jmpc_rst_n_p1_reg <= rst_n_p0_reg;
      end
      for (
          mesh_y_idx = 0; mesh_y_idx < `MESH_Y_SIZE; mesh_y_idx = mesh_y_idx + 1
      ) begin : job_match_pe_gen_y
        if (mesh_y_idx[0]) begin
          // 创建 shared_match_pe_cluster
          localparam shared_match_pe_slice_idx = {
            mesh_y_idx[1+:`MESH_Y_SIZE_LOG2-1], mesh_x_idx[`MESH_X_SIZE_LOG2-1:0]
          };
          shared_match_pe_cluster #(
              .SHARED_MATCH_PE_SLICE_IDX(shared_match_pe_slice_idx)
          ) smpc_inst (
              .clk  (clk),
              .rst_n(col_smpc_jmpc_rst_n_p1_reg),

              .from_mesh_valid  (o_l_valid[mesh_x_idx][mesh_y_idx]),
              .from_mesh_ready  (o_l_ready[mesh_x_idx][mesh_y_idx]),
              .from_mesh_payload(o_l_payload[mesh_x_idx][mesh_y_idx]),

              .to_mesh_valid  (i_l_valid[mesh_x_idx][mesh_y_idx]),
              .to_mesh_ready  (i_l_ready[mesh_x_idx][mesh_y_idx]),
              .to_mesh_x_dst  (i_l_dst_x[mesh_x_idx][mesh_y_idx]),
              .to_mesh_y_dst  (i_l_dst_y[mesh_x_idx][mesh_y_idx]),
              .to_mesh_payload(i_l_payload[mesh_x_idx][mesh_y_idx]),

              .match_pe_write_addr  (match_pe_write_addr_reg),
              .match_pe_write_data  (match_pe_write_data_reg),
              .match_pe_write_enable(match_pe_write_enable_reg)
          );
        end else begin
          // 创建 job_match_pe_cluster
          localparam job_match_pe_idx = {
            mesh_y_idx[1+:`MESH_Y_SIZE_LOG2-1], mesh_x_idx[`MESH_X_SIZE_LOG2-1:0]
          };
          job_match_pe_cluster #(
              .JOB_PE_IDX(job_match_pe_idx)
          ) jmpc_inst (
              .clk  (clk),
              .rst_n(col_smpc_jmpc_rst_n_p1_reg),

              .hash_batch_valid(hash_batch_bus_o_this_valid[job_match_pe_idx]),
              .hash_batch_head_addr(hash_batch_bus_o_this_head_addr[job_match_pe_idx]),
              .hash_batch_history_valid(hash_batch_bus_o_this_history_valid[job_match_pe_idx]),
              .hash_batch_history_addr(hash_batch_bus_o_this_history_addr[job_match_pe_idx]),
              .hash_batch_meta_match_len(hash_batch_bus_o_this_meta_match_len[job_match_pe_idx]),
              .hash_batch_meta_match_can_ext(hash_batch_bus_o_this_meta_match_can_ext[job_match_pe_idx]),
              .hash_batch_delim(hash_batch_bus_o_this_delim[job_match_pe_idx]),
              .hash_batch_ready(hash_batch_bus_o_this_ready[job_match_pe_idx]),

              // output seq packet port
              .seq_packet_valid(seq_packet_bus_i_local_valid[job_match_pe_idx]),
              .seq_packet_strb(seq_packet_bus_i_local_strb[job_match_pe_idx]),
              .seq_packet_ll(seq_packet_bus_i_local_ll[job_match_pe_idx]),
              .seq_packet_ml(seq_packet_bus_i_local_ml[job_match_pe_idx]),
              .seq_packet_offset(seq_packet_bus_i_local_offset[job_match_pe_idx]),
              .seq_packet_overlap(seq_packet_bus_i_local_overlap[job_match_pe_idx]),
              .seq_packet_eoj(seq_packet_bus_i_local_eoj[job_match_pe_idx]),
              .seq_packet_delim(seq_packet_bus_i_local_delim[job_match_pe_idx]),
              .seq_packet_ready(seq_packet_bus_i_local_ready[job_match_pe_idx]),

              // local match pe write port
              .match_pe_write_addr  (match_pe_write_addr_reg),
              .match_pe_write_data  (match_pe_write_data_reg),
              .match_pe_write_enable(match_pe_write_enable_reg),

              // to mesh port
              .to_mesh_valid  (i_l_valid[mesh_x_idx][mesh_y_idx]),
              .to_mesh_ready  (i_l_ready[mesh_x_idx][mesh_y_idx]),
              .to_mesh_x_dst  (i_l_dst_x[mesh_x_idx][mesh_y_idx]),
              .to_mesh_y_dst  (i_l_dst_y[mesh_x_idx][mesh_y_idx]),
              .to_mesh_payload(i_l_payload[mesh_x_idx][mesh_y_idx]),

              // from mesh port
              .from_mesh_valid  (o_l_valid[mesh_x_idx][mesh_y_idx]),
              .from_mesh_ready  (o_l_ready[mesh_x_idx][mesh_y_idx]),
              .from_mesh_payload(o_l_payload[mesh_x_idx][mesh_y_idx])
          );
        end
      end
    end
  endgenerate

`ifdef MATCH_ENGINE_DEBUG_LOG
  always @(posedge clk) begin
    if (i_match_pe_write_enable) begin
      $display("[match_engine @ %0t] write write_addr=%0d, write_data=0x%0h", $time,
               i_match_pe_write_addr, i_match_pe_write_data);
    end
  end
`endif

endmodule
