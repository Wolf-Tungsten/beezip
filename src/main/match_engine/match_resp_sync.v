/**

match_resp_sync

收集来自 M 个 match_pe 的响应，收集到 LAZY_LEN 个响应后，将这些响应发送到 job_pe。

*/

`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module match_resp_sync #(
    parameter JOB_PE_IDX = 0,
    parameter L = `LAZY_LEN,
    parameter C = `NUM_MATCH_REQ_CH,
    parameter TAG_BITS = `LAZY_LEN_LOG2,
    parameter ML = `MATCH_LEN_WIDTH
) (
    input wire clk,
    input wire rst_n,

    input req_group_fire,
    input [L-1:0] req_group_strb,

    input wire [C-1:0] resp_valid,
    output wire [C-1:0] resp_ready,
    input wire [C*TAG_BITS-1:0] resp_tag,
    input wire [C*ML-1:0] resp_match_len,

    output wire resp_group_valid,
    input wire resp_group_ready,
    output wire [L*ML-1:0] resp_group_match_len
);

  reg [L-1:0] done_reg;
  reg [L*ML-1:0] match_len_reg;

  reg [L-1:0] valid_vec;
  reg [L*ML-1:0] match_len_vec;
  reg valid_tmp;
  always @(*) begin
    for (integer i = 0; i < L; i = i + 1) begin
      valid_vec[i] = '0;
      match_len_vec[i*ML+:ML] = '0;
      for (integer j = 0; j < C; j = j + 1) begin
        valid_tmp = resp_valid[j] && (resp_tag[j*TAG_BITS+:TAG_BITS] == i[TAG_BITS-1:0]);
        valid_vec[i] |= valid_tmp;
        match_len_vec[i*ML+:ML] |= valid_tmp ? resp_match_len[j*ML+:ML] : '0;
      end
    end
  end

`ifdef JOB_PE_DEBUG_LOG
  always @(posedge clk) begin
    if (resp_group_valid & resp_group_ready) begin
      for (integer i = 0; i < `LAZY_LEN; i = i + 1) begin
        $display("[match_resp_sync %0d @ %0t] send resp[%0d] match_len=%0d to job pe", JOB_PE_IDX, $time,
                 i, resp_group_match_len[i*`MATCH_LEN_WIDTH+:`MATCH_LEN_WIDTH]);
      end
    end
  end
`endif

  assign resp_group_valid = &done_reg;
  assign resp_ready = {C{~&done_reg}};
  assign resp_group_match_len = match_len_reg;

  always @(posedge clk) begin
    if (~rst_n) begin
      done_reg <= '0;
      match_len_reg <= '0;
    end else begin
      if (req_group_fire) begin
`ifdef JOB_PE_DEBUG_LOG
        $display("[match_resp_sync %0d @ %0t] load done_reg = b%b", JOB_PE_IDX, $time,
                 ~req_group_strb);
`endif
        done_reg <= ~req_group_strb;
      end else if (|(resp_ready & resp_valid)) begin
        done_reg <= done_reg | valid_vec;
        match_len_reg <= match_len_reg | match_len_vec;
      end
    end
  end
endmodule
