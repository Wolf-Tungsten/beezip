`include "parameters.vh"
`include "util.vh"

module seq_packet_pick_last (
    input wire clk,
    input wire rst_n,

    // input seq packet port
    input wire i_seq_packet_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] i_seq_packet_strb,
    input wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] i_seq_packet_ll,
    input wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] i_seq_packet_ml,
    input wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] i_seq_packet_offset,
    input wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] i_seq_packet_overlap,
    input wire [`SEQ_PACKET_SIZE-1:0] i_seq_packet_eoj,
    input wire [`SEQ_PACKET_SIZE-1:0] i_seq_packet_delim,
    output wire i_seq_packet_ready,

    // output seq packet port
    output wire o_seq_packet_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_strb,
    output wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] o_seq_packet_ll,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_ml,
    output wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] o_seq_packet_offset,
    output wire [`SEQ_ML_BITS-1:0] o_seq_packet_overlap,
    output wire o_seq_packet_eoj,
    output wire o_seq_packet_has_gap,
    output wire o_seq_packet_has_overlap,
    output wire o_seq_packet_delim,
    input wire o_seq_packet_ready
);


  wire [`SEQ_PACKET_SIZE-1:0] seq_packet_strb;
  wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] seq_packet_ll;
  wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] seq_packet_ml;
  wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] seq_packet_offset;
  wire [`SEQ_ML_BITS-1:0] seq_packet_overlap;
  wire seq_packet_eoj;
  wire seq_packet_has_gap;
  wire seq_packet_has_overlap;
  wire seq_packet_delim;

  // 除了最后一个 slot，前面的 slot 都是如果不是 eoj 就直接输出，是 eoj 就屏蔽掉
  genvar g_i;
  generate
    for (g_i = 0; g_i < `SEQ_PACKET_SIZE - 1; g_i = g_i + 1) begin
      assign seq_packet_strb[g_i] = i_seq_packet_strb[g_i] & ~i_seq_packet_eoj[g_i];
      assign seq_packet_ll[g_i*`SEQ_LL_BITS +: `SEQ_LL_BITS] = i_seq_packet_ll[g_i*`SEQ_LL_BITS +: `SEQ_LL_BITS];
      assign seq_packet_ml[g_i*`SEQ_ML_BITS +: `SEQ_ML_BITS] = i_seq_packet_ml[g_i*`SEQ_ML_BITS +: `SEQ_ML_BITS];
      assign seq_packet_offset[g_i*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS] = i_seq_packet_offset[g_i*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS];
    end
  endgenerate

  // 判断是否有 eoj
  assign seq_packet_eoj = |(i_seq_packet_strb & i_seq_packet_eoj);
  // 找出 eoj 的逻辑
  reg [`SEQ_LL_BITS-1:0] seq_packet_ll_last;
  reg [`SEQ_ML_BITS-1:0] seq_packet_ml_last;
  reg [`SEQ_OFFSET_BITS-1:0] seq_packet_offset_last;
  reg [`SEQ_ML_BITS-1:0] seq_packet_overlap_last;
  always @(*) begin
    seq_packet_ll_last = '0;
    seq_packet_ml_last = '0;
    seq_packet_offset_last = '0;
    seq_packet_overlap_last = '0;
    for (integer j = 0; j < `SEQ_PACKET_SIZE; j = j + 1) begin
      if (i_seq_packet_strb[j] & i_seq_packet_eoj[j]) begin
        seq_packet_ll_last = i_seq_packet_ll[j*`SEQ_LL_BITS+:`SEQ_LL_BITS];
        seq_packet_ml_last = i_seq_packet_ml[j*`SEQ_ML_BITS+:`SEQ_ML_BITS];
        seq_packet_offset_last = i_seq_packet_offset[j*`SEQ_OFFSET_BITS+:`SEQ_OFFSET_BITS];
        seq_packet_overlap_last = i_seq_packet_overlap[j*`SEQ_ML_BITS+:`SEQ_ML_BITS];
      end else begin
        seq_packet_ll_last = seq_packet_ll_last;
        seq_packet_ml_last = seq_packet_ml_last;
        seq_packet_offset_last = seq_packet_offset_last;
        seq_packet_overlap_last = seq_packet_overlap_last;
      end
    end
  end

  // 最后一个 slot 在有 eoj 时输出 last seq，没有 eoj 时输出原来位置的 seq
  assign seq_packet_strb[`SEQ_PACKET_SIZE-1] = seq_packet_eoj ? 1'b1 : i_seq_packet_strb[`SEQ_PACKET_SIZE-1];
  assign seq_packet_ll[(`SEQ_PACKET_SIZE-1)*`SEQ_LL_BITS +: `SEQ_LL_BITS] = seq_packet_eoj ? seq_packet_ll_last : i_seq_packet_ll[(`SEQ_PACKET_SIZE-1)*`SEQ_LL_BITS +: `SEQ_LL_BITS];
  assign seq_packet_ml[(`SEQ_PACKET_SIZE-1)*`SEQ_ML_BITS +: `SEQ_ML_BITS] = seq_packet_eoj ? seq_packet_ml_last : i_seq_packet_ml[(`SEQ_PACKET_SIZE-1)*`SEQ_ML_BITS +: `SEQ_ML_BITS];
  assign seq_packet_offset[(`SEQ_PACKET_SIZE-1)*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS] = seq_packet_eoj ? seq_packet_offset_last : i_seq_packet_offset[(`SEQ_PACKET_SIZE-1)*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS];
  // 计算 overlap、gap 状态
  assign seq_packet_overlap = seq_packet_eoj ? seq_packet_overlap_last : '0;
  assign seq_packet_delim = seq_packet_eoj & (|i_seq_packet_delim);
  assign seq_packet_has_gap = seq_packet_eoj & (seq_packet_ml_last == '0);
  assign seq_packet_has_overlap = seq_packet_eoj & (seq_packet_overlap_last != '0);
  // 创建一个握手寄存器
  pingpong_reg #(
      .W($bits(
          {
            o_seq_packet_strb,
            o_seq_packet_ll,
            o_seq_packet_ml,
            o_seq_packet_offset,
            o_seq_packet_overlap,
            o_seq_packet_eoj,
            o_seq_packet_has_gap,
            o_seq_packet_has_overlap,
            o_seq_packet_delim
          }
      ))
  ) handshake_reg (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(i_seq_packet_valid),
      .input_payload({
        seq_packet_strb,
        seq_packet_ll,
        seq_packet_ml,
        seq_packet_offset,
        seq_packet_overlap,
        seq_packet_eoj,
        seq_packet_has_gap,
        seq_packet_has_overlap,
        seq_packet_delim
      }),
      .input_ready(i_seq_packet_ready),
      .output_valid(o_seq_packet_valid),
      .output_payload({
        o_seq_packet_strb,
        o_seq_packet_ll,
        o_seq_packet_ml,
        o_seq_packet_offset,
        o_seq_packet_overlap,
        o_seq_packet_eoj,
        o_seq_packet_has_gap,
        o_seq_packet_has_overlap,
        o_seq_packet_delim
      }),
      .output_ready(o_seq_packet_ready)
  );

endmodule
