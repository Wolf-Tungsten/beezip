`include "parameters.vh"

module shared_match_pe_cluster #(
    parameter SHARED_MATCH_PE_SLICE_IDX = 0
) (
    input wire clk,
    input wire rst_n,

    input wire [`NUM_SHARED_MATCH_PE-1:0] from_mesh_valid,
    output wire [`NUM_SHARED_MATCH_PE-1:0] from_mesh_ready,
    input wire [`NUM_SHARED_MATCH_PE * `MESH_W-1:0] from_mesh_payload,

    output wire [`NUM_SHARED_MATCH_PE-1:0] to_mesh_valid,
    input wire [`NUM_SHARED_MATCH_PE-1:0] to_mesh_ready,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_X_SIZE_LOG2-1:0] to_mesh_x_dst,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_Y_SIZE_LOG2-1:0] to_mesh_y_dst,
    output wire [`NUM_SHARED_MATCH_PE * `MESH_W-1:0] to_mesh_payload,

    input wire [`ADDR_WIDTH-1:0] match_pe_write_addr,
    input wire [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data,
    input wire match_pe_write_enable
);

  reg rst_n_reg;
  always @(posedge clk) begin
    rst_n_reg <= rst_n;
  end

  wire [`NUM_SHARED_MATCH_PE-1:0] match_req_valid;
  wire [`NUM_SHARED_MATCH_PE-1:0] match_req_ready;
  wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] match_req_head_addr;
  wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] match_req_history_addr;
  wire [`NUM_SHARED_MATCH_PE*(`NUM_JOB_PE_LOG2+`LAZY_LEN_LOG2)-1:0] match_req_tag;

  wire [`NUM_SHARED_MATCH_PE-1:0] match_resp_valid;
  wire [`NUM_SHARED_MATCH_PE-1:0] match_resp_ready;
  wire [`NUM_SHARED_MATCH_PE*(`NUM_JOB_PE_LOG2+`LAZY_LEN_LOG2)-1:0] match_resp_tag;
  wire [`NUM_SHARED_MATCH_PE*`MATCH_LEN_WIDTH-1:0] match_resp_match_len;

  mesh_adapter_shared_match_pe masmp_inst[`NUM_SHARED_MATCH_PE-1:0] (
      .clk  (clk),
      .rst_n(rst_n_reg),

      .from_mesh_valid  (from_mesh_valid),
      .from_mesh_ready  (from_mesh_ready),
      .from_mesh_payload(from_mesh_payload),

      .match_req_valid(match_req_valid),
      .match_req_ready(match_req_ready),
      .match_req_head_addr(match_req_head_addr),
      .match_req_history_addr(match_req_history_addr),
      .match_req_tag(match_req_tag),

      .match_resp_valid(match_resp_valid),
      .match_resp_ready(match_resp_ready),
      .match_resp_tag(match_resp_tag),
      .match_resp_match_len(match_resp_match_len),

      .to_mesh_valid  (to_mesh_valid),
      .to_mesh_ready  (to_mesh_ready),
      .to_mesh_x_dst  (to_mesh_x_dst),
      .to_mesh_y_dst  (to_mesh_y_dst),
      .to_mesh_payload(to_mesh_payload)
  );

  reg [`ADDR_WIDTH-1:0] match_pe_write_addr_reg;
  reg [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data_reg;
  reg match_pe_write_enable_reg;
  wire match_pe_write_history_enable = 
  match_pe_write_addr_reg[`SHARED_MATCH_PE_SLICE_SIZE_LOG2 +: `NUM_JOB_PE_LOG2] == 
  SHARED_MATCH_PE_SLICE_IDX[`NUM_JOB_PE_LOG2-1:0];
  
  always @(posedge clk) begin
    match_pe_write_addr_reg   <= match_pe_write_addr;
    match_pe_write_data_reg   <= match_pe_write_data;
    match_pe_write_enable_reg <= match_pe_write_enable;
  end

  match_pe #(
      .TAG_BITS (`NUM_JOB_PE_LOG2 + `LAZY_LEN_LOG2),
      .SIZE_LOG2(`WINDOW_LOG - `NUM_JOB_PE_LOG2),
      .LABEL("shared_match_pe"),
      .JOB_PE_IDX(`NUM_JOB_PE),
      .MATCH_PE_IDX(SHARED_MATCH_PE_SLICE_IDX)
  ) match_pe_inst[`NUM_SHARED_MATCH_PE-1:0] (
      .clk  (clk),
      .rst_n(rst_n_reg),

      .match_req_valid(match_req_valid),
      .match_req_ready(match_req_ready),
      .match_req_tag(match_req_tag),
      .match_req_head_addr(match_req_head_addr),
      .match_req_history_addr(match_req_history_addr),

      .match_resp_valid(match_resp_valid),
      .match_resp_ready(match_resp_ready),
      .match_resp_tag(match_resp_tag),
      .match_resp_match_len(match_resp_match_len),

      .write_addr(match_pe_write_addr_reg),
      .write_data(match_pe_write_data_reg),
      .write_enable(match_pe_write_enable_reg),
      .write_history_enable(match_pe_write_history_enable)
  );
endmodule
