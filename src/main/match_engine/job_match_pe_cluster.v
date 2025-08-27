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
    input wire match_pe_write_enable

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


  // add reg for match pe write
  reg [`ADDR_WIDTH-1:0] match_pe_write_addr_reg;
  reg [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data_reg;
  reg match_pe_write_enable_reg;

  always @(posedge clk) begin
    match_pe_write_addr_reg   <= match_pe_write_addr;
    match_pe_write_data_reg   <= match_pe_write_data;
    match_pe_write_enable_reg <= match_pe_write_enable;
  end


    match_pe #(
        .TAG_BITS (1),
        .SIZE_LOG2(`MATCH_PE_0_SIZE_LOG2),
        .LABEL("local_match_pe"),
        .JOB_PE_IDX(JOB_PE_IDX),
        .MATCH_PE_IDX(0)
        //.LABEL($sformatf("job_pe_%0d_match_pe_%0d", JOB_PE_IDX, i))
    ) local_match_pe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .match_req_valid(match_req_group_valid),
        .match_req_ready(match_req_group_ready),
        .match_req_tag('0),
        .match_req_head_addr(match_req_group_head_addr),
        .match_req_history_addr(match_req_group_history_addr),

        .match_resp_valid(match_resp_group_valid),
        .match_resp_ready(match_resp_group_ready),
        .match_resp_tag(),
        .match_resp_match_len(match_resp_group_match_len),

        .write_addr(match_pe_write_addr_reg),
        .write_data(match_pe_write_data_reg),
        .write_enable(match_pe_write_enable_reg),
        .write_history_enable(1'b1)
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

