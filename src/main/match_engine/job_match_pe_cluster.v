`include "parameters.vh"

module job_match_pe_cluster #(
    parameter JOB_PE_IDX = 0
) (
    input wire clk,
    input wire rst_n,

    input wire hash_batch_valid,
    input wire [`ADDR_WIDTH-1:0] hash_batch_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_history_valid,
    input wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_history_addr,
    input wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_batch_meta_match_len,
    input wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_meta_match_can_ext,
    input wire hash_batch_delim,
    output wire hash_batch_ready,

    // output seq packet port
    output wire seq_packet_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] seq_packet_strb,
    output wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] seq_packet_ll,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] seq_packet_ml,
    output wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] seq_packet_offset,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] seq_packet_overlap,
    output wire [`SEQ_PACKET_SIZE-1:0] seq_packet_eoj,
    output wire [`SEQ_PACKET_SIZE-1:0] seq_packet_delim,
    input wire seq_packet_ready,

    // local match pe write port
    input wire [`ADDR_WIDTH-1:0] match_pe_write_addr,
    input wire [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data,
    input wire match_pe_write_enable,

    // to mesh port
    output wire [`NUM_SHARED_MATCH_PE-1:0] to_mesh_valid,
    input wire [`NUM_SHARED_MATCH_PE-1:0] to_mesh_ready,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_X_SIZE_LOG2-1:0] to_mesh_x_dst,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_Y_SIZE_LOG2-1:0] to_mesh_y_dst,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_W-1:0] to_mesh_payload,

    // from mesh port
    input wire [`NUM_SHARED_MATCH_PE-1:0] from_mesh_valid,
    output wire [`NUM_SHARED_MATCH_PE-1:0] from_mesh_ready,
    input wire [`NUM_SHARED_MATCH_PE * `MESH_W-1:0] from_mesh_payload

);

  wire match_req_group_valid;
  wire [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_head_addr;
  wire [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_history_addr;
  wire [`LAZY_LEN*`NUM_MATCH_REQ_CH-1:0] match_req_group_router_map;
  wire [`LAZY_LEN-1:0] match_req_group_strb;
  wire match_req_group_ready;

  wire match_resp_group_valid;
  wire match_resp_group_ready;
  wire [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] match_resp_group_match_len;

  wire seq_valid;
  wire [`SEQ_LL_BITS-1:0] seq_ll;
  wire [`SEQ_ML_BITS-1:0] seq_ml;
  wire [`SEQ_OFFSET_BITS-1:0] seq_offset;
  wire seq_eoj;
  wire [`SEQ_ML_BITS-1:0] seq_overlap_len;
  wire seq_delim;
  wire seq_ready;

  job_pe #(
      .JOB_PE_IDX(JOB_PE_IDX)
  ) job_pe_inst (
      .clk(clk),
      .rst_n(rst_n),
      .hash_batch_valid(hash_batch_valid),
      .hash_batch_head_addr(hash_batch_head_addr),
      .hash_batch_history_valid(hash_batch_history_valid),
      .hash_batch_history_addr(hash_batch_history_addr),
      .hash_batch_meta_match_len(hash_batch_meta_match_len),
      .hash_batch_meta_match_can_ext(hash_batch_meta_match_can_ext),
      .hash_batch_delim(hash_batch_delim),
      .hash_batch_ready(hash_batch_ready),

      .match_req_group_valid(match_req_group_valid),
      .match_req_group_head_addr(match_req_group_head_addr),
      .match_req_group_history_addr(match_req_group_history_addr),
      .match_req_group_router_map(match_req_group_router_map),
      .match_req_group_strb(match_req_group_strb),
      .match_req_group_ready(match_req_group_ready),

      .match_resp_group_valid(match_resp_group_valid),
      .match_resp_group_ready(match_resp_group_ready),
      .match_resp_group_match_len(match_resp_group_match_len),

      .seq_valid(seq_valid),
      .seq_ll(seq_ll),
      .seq_ml(seq_ml),
      .seq_offset(seq_offset),
      .seq_eoj(seq_eoj),
      .seq_overlap_len(seq_overlap_len),
      .seq_delim(seq_delim),
      .seq_ready(seq_ready)
  );

  // shared match pe request port
  wire [`NUM_SHARED_MATCH_PE-1:0] shared_match_req_valid;
  wire [`NUM_SHARED_MATCH_PE-1:0] shared_match_req_ready;
  wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] shared_match_req_head_addr;
  wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] shared_match_req_history_addr;
  wire [`NUM_SHARED_MATCH_PE*`LAZY_LEN_LOG2-1:0] shared_match_req_tag;

  // shared match pe response port
  wire shared_match_resp_valid;
  wire shared_match_resp_ready;
  wire [`NUM_SHARED_MATCH_PE*`LAZY_LEN_LOG2-1:0] shared_match_resp_tag;
  wire [`NUM_SHARED_MATCH_PE*`MATCH_LEN_WIDTH-1:0] shared_match_resp_match_len;

  wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_req_valid;
  wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_req_ready;
  wire [`NUM_LOCAL_MATCH_PE*`ADDR_WIDTH-1:0] local_match_req_head_addr;
  wire [`NUM_LOCAL_MATCH_PE*`ADDR_WIDTH-1:0] local_match_req_history_addr;
  wire [`NUM_LOCAL_MATCH_PE*`LAZY_LEN_LOG2-1:0] local_match_req_tag;

  match_req_scheduler #(
      .JOB_PE_IDX(JOB_PE_IDX)
  ) match_req_scheduler_inst (
      .clk(clk),
      .rst_n(rst_n),
      .match_req_group_valid(match_req_group_valid),
      .match_req_group_ready(match_req_group_ready),
      .match_req_group_head_addr(match_req_group_head_addr),
      .match_req_group_history_addr(match_req_group_history_addr),
      .match_req_group_router_map(match_req_group_router_map),
      .match_req_group_strb(match_req_group_strb),
      .match_req_valid({shared_match_req_valid, local_match_req_valid}),
      .match_req_ready({shared_match_req_ready, local_match_req_ready}),
      .match_req_head_addr({shared_match_req_head_addr, local_match_req_head_addr}),
      .match_req_history_addr({shared_match_req_history_addr, local_match_req_history_addr}),
      .match_req_tag({shared_match_req_tag, local_match_req_tag})
  );

  wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_resp_valid;
  wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_resp_ready;
  wire [`NUM_LOCAL_MATCH_PE*`MATCH_LEN_WIDTH-1:0] local_match_resp_match_len;
  wire [`NUM_LOCAL_MATCH_PE*`LAZY_LEN_LOG2-1:0] local_match_resp_tag;

  // add reg for match pe write
  reg [`ADDR_WIDTH-1:0] match_pe_write_addr_reg;
  reg [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data_reg;
  reg match_pe_write_enable_reg;

  always @(posedge clk) begin
    match_pe_write_addr_reg   <= match_pe_write_addr;
    match_pe_write_data_reg   <= match_pe_write_data;
    match_pe_write_enable_reg <= match_pe_write_enable;
  end

  genvar i;
  generate
    for (i = 0; i < `NUM_LOCAL_MATCH_PE; i = i + 1) begin
      localparam size_log2 = (i == 0) ? `MATCH_PE_0_SIZE_LOG2 :
                                   (i == 1) ? `MATCH_PE_1_SIZE_LOG2 :
                                   (i == 2) ? `MATCH_PE_2_SIZE_LOG2 : 0;
      match_pe #(
          .TAG_BITS (`LAZY_LEN_LOG2),
          .SIZE_LOG2(size_log2)
      ) local_match_pe_inst (
          .clk(clk),
          .rst_n(rst_n),
          .match_req_valid(local_match_req_valid[i]),
          .match_req_ready(local_match_req_ready[i]),
          .match_req_tag(local_match_req_tag[i*`LAZY_LEN_LOG2+:`LAZY_LEN_LOG2]),
          .match_req_head_addr(local_match_req_head_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH]),
          .match_req_history_addr(local_match_req_history_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH]),

          .match_resp_valid(local_match_resp_valid[i]),
          .match_resp_ready(local_match_resp_ready[i]),
          .match_resp_tag(local_match_resp_tag[i*`LAZY_LEN_LOG2+:`LAZY_LEN_LOG2]),
          .match_resp_match_len(local_match_resp_match_len[i*`MATCH_LEN_WIDTH+:`MATCH_LEN_WIDTH]),

          .write_addr(match_pe_write_addr_reg),
          .write_data(match_pe_write_data_reg),
          .write_enable(match_pe_write_enable_reg),
          .write_history_enable(1'b1)
      );
    end
  endgenerate

  // match_resp_sync
  match_resp_sync #(
      .JOB_PE_IDX(JOB_PE_IDX)
  ) match_resp_sync_inst (
      .clk  (clk),
      .rst_n(rst_n),

      .req_group_fire(match_req_group_valid & match_req_group_ready),
      .req_group_strb (match_req_group_strb),

      .resp_valid({shared_match_resp_valid, local_match_resp_valid}),
      .resp_ready({shared_match_resp_ready, local_match_resp_ready}),
      .resp_tag({shared_match_resp_tag, local_match_resp_tag}),
      .resp_match_len({shared_match_resp_match_len, local_match_resp_match_len}),

      .resp_group_valid(match_resp_group_valid),
      .resp_group_ready(match_resp_group_ready),
      .resp_group_match_len(match_resp_group_match_len)
  );

  mesh_adapter_job_pe #(
      .JOB_PE_IDX(JOB_PE_IDX)
  ) majp_inst[`NUM_SHARED_MATCH_PE-1:0] (
      .clk  (clk),
      .rst_n(rst_n),

      .match_req_valid(shared_match_req_valid),
      .match_req_ready(shared_match_req_ready),
      .match_req_head_addr(shared_match_req_head_addr),
      .match_req_history_addr(shared_match_req_history_addr),
      .match_req_tag(shared_match_req_tag),

      .to_mesh_valid  (to_mesh_valid),
      .to_mesh_ready  (to_mesh_ready),
      .to_mesh_x_dst  (to_mesh_x_dst),
      .to_mesh_y_dst  (to_mesh_y_dst),
      .to_mesh_payload(to_mesh_payload),

      .from_mesh_valid  (from_mesh_valid),
      .from_mesh_ready  (from_mesh_ready),
      .from_mesh_payload(from_mesh_payload),

      .match_resp_valid(shared_match_resp_valid),
      .match_resp_ready(shared_match_resp_ready),
      .match_resp_tag(shared_match_resp_tag),
      .match_resp_match_len(shared_match_resp_match_len)
  );

  seq_packer seq_packer_inst (
      .clk  (clk),
      .rst_n(rst_n),

      .i_valid(seq_valid),
      .i_ll(seq_ll),
      .i_ml(seq_ml),
      .i_offset(seq_offset),
      .i_eoj(seq_eoj),
      .i_overlap_len(seq_overlap_len),
      .i_delim(seq_delim),
      .i_ready(seq_ready),

      .o_valid(seq_packet_valid),
      .o_strb(seq_packet_strb),
      .o_ll(seq_packet_ll),
      .o_ml(seq_packet_ml),
      .o_offset(seq_packet_offset),
      .o_overlap(seq_packet_overlap),
      .o_eoj(seq_packet_eoj),
      .o_delim(seq_packet_delim),
      .o_ready(seq_packet_ready)
  );

endmodule

