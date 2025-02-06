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
    input wire [`SEQ_PACKET_SIZE-1:0] i_eoj_delim,
    output wire i_seq_packet_ready,

    // output seq packet port
    output wire o_seq_packet_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_seq_packet_strb,
    output wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] o_seq_packet_ll,
    output wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_ml,
    output wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] o_seq_packet_offset,
    output wire [`SEQ_LL_BITS-1:0] o_first_seq_len,
    output wire o_first_ll_gte_mml,
    output wire [`SEQ_ML_BITS-1:0] o_seq_packet_overlap,
    output wire o_seq_packet_eoj,
    output wire o_eoj_delim,
    output wire o_eoj_gap_gt_0,
    output wire o_eoj_gap_overlap_eq_0,
    output wire o_eoj_0_lt_overlap_lt_job_len,
    output wire o_eoj_job_len_lte_overlap,
    input wire o_seq_packet_ready
);

  reg state_reg;
  localparam S_PASS = 1'b0;
  localparam S_FLUSH_BUF = 1'b1;

  reg [`SEQ_PACKET_SIZE-1:0] seq_packet_strb;
  reg [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] seq_packet_ll;
  reg [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] seq_packet_ml;
  reg [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] seq_packet_offset;
  reg [`SEQ_LL_BITS-1:0] first_seq_len;
  reg first_ll_gte_mml;
  reg [`SEQ_ML_BITS-1:0] seq_packet_overlap;
  reg seq_packet_eoj;
  reg eoj_delim;
  reg eoj_gap_gt_0;
  reg eoj_gap_overlap_eq_0;
  reg eoj_0_lt_overlap_lt_job_len;
  reg eoj_job_len_lte_overlap;

  reg [`SEQ_LL_BITS-1:0] seq_packet_ll_last_reg;
  reg [`SEQ_ML_BITS-1:0] seq_packet_ml_last_reg;
  reg [`SEQ_OFFSET_BITS-1:0] seq_packet_offset_last_reg;
  reg [`SEQ_ML_BITS-1:0] seq_packet_overlap_last_reg;
  reg eoj_delim_last_reg;


  always @(*) begin
    case (state_reg)
      S_PASS: begin
        for (integer i = 0; i < `SEQ_PACKET_SIZE; i = i + 1) begin
          seq_packet_strb[i] = i_seq_packet_strb[i] & ~i_seq_packet_eoj[i]; // 如果是 eoj 则延迟到下一拍第一个
          seq_packet_ll[i*`SEQ_LL_BITS +: `SEQ_LL_BITS] = i_seq_packet_ll[i*`SEQ_LL_BITS +: `SEQ_LL_BITS];
          seq_packet_ml[i*`SEQ_ML_BITS +: `SEQ_ML_BITS] = i_seq_packet_ml[i*`SEQ_ML_BITS +: `SEQ_ML_BITS];
          seq_packet_offset[i*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS] = i_seq_packet_offset[i*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS];
        end
        first_ll_gte_mml = i_seq_packet_ll[0 +: `SEQ_LL_BITS] >= `MIN_MATCH_LEN; 
        first_seq_len = i_seq_packet_ll[0 +: `SEQ_LL_BITS] + `ZERO_EXTEND(i_seq_packet_ml[0 +: `SEQ_ML_BITS], `SEQ_LL_BITS); 
        seq_packet_overlap = '0;
        seq_packet_eoj = '0;
        eoj_delim = '0;
        eoj_gap_gt_0 = '0;
        eoj_gap_overlap_eq_0 = '0;
        eoj_0_lt_overlap_lt_job_len = '0;
        eoj_job_len_lte_overlap = '0;
      end
      S_FLUSH_BUF: begin
        seq_packet_strb[0] = 1'b1;
        seq_packet_ll[0+:`SEQ_LL_BITS] = seq_packet_ll_last_reg;
        seq_packet_ml[0+:`SEQ_ML_BITS] = seq_packet_ml_last_reg;
        seq_packet_offset[0+:`SEQ_OFFSET_BITS] = seq_packet_offset_last_reg;
        for (integer i = 1; i < `SEQ_PACKET_SIZE; i = i + 1) begin
          seq_packet_strb[i] = '0;
          seq_packet_ll[i*`SEQ_LL_BITS+:`SEQ_LL_BITS] = '0;
          seq_packet_ml[i*`SEQ_ML_BITS+:`SEQ_ML_BITS] = '0;
          seq_packet_offset[i*`SEQ_OFFSET_BITS+:`SEQ_OFFSET_BITS] = '0;
        end
        first_ll_gte_mml = seq_packet_ll_last_reg >= `MIN_MATCH_LEN; 
        first_seq_len = seq_packet_ll_last_reg + `ZERO_EXTEND(seq_packet_ml_last_reg - seq_packet_overlap_last_reg, `SEQ_LL_BITS); 
        seq_packet_overlap = seq_packet_overlap_last_reg;
        seq_packet_eoj = 1'b1;
        eoj_delim = eoj_delim_last_reg;
        eoj_gap_gt_0 = seq_packet_ml_last_reg == 0;
        eoj_gap_overlap_eq_0 = seq_packet_ml_last_reg > 0 && seq_packet_overlap_last_reg == 0;
        eoj_0_lt_overlap_lt_job_len = 0 < seq_packet_overlap_last_reg && seq_packet_overlap_last_reg < `JOB_LEN; 
        eoj_job_len_lte_overlap = seq_packet_overlap_last_reg >= `JOB_LEN;
      end
      default: begin
        for (integer i = 0; i < `SEQ_PACKET_SIZE; i = i + 1) begin
          seq_packet_strb[i] = '0;
          seq_packet_ll[i*`SEQ_LL_BITS +: `SEQ_LL_BITS] = '0;
          seq_packet_ml[i*`SEQ_ML_BITS +: `SEQ_ML_BITS] = '0;
          seq_packet_offset[i*`SEQ_OFFSET_BITS +: `SEQ_OFFSET_BITS] = '0;
        end
        seq_packet_overlap = '0;
        seq_packet_eoj = '0;
        eoj_delim = '0;
        eoj_gap_gt_0 = '0;
        eoj_gap_overlap_eq_0 = '0;
        eoj_0_lt_overlap_lt_job_len = '0;
        eoj_job_len_lte_overlap = '0;
      end
    endcase
  end


  // 判断是否有 eoj
  wire i_seq_packet_has_eoj = |(i_seq_packet_strb & i_seq_packet_eoj);
  // 找出 eoj 的组合逻辑
  reg [`SEQ_LL_BITS-1:0] seq_packet_ll_last;
  reg [`SEQ_ML_BITS-1:0] seq_packet_ml_last;
  reg [`SEQ_OFFSET_BITS-1:0] seq_packet_offset_last;
  reg [`SEQ_ML_BITS-1:0] seq_packet_overlap_last;
  reg eoj_delim_last;
  always @(*) begin
    seq_packet_ll_last = '0;
    seq_packet_ml_last = '0;
    seq_packet_offset_last = '0;
    seq_packet_overlap_last = '0;
    eoj_delim_last = '0;
    for (integer j = 0; j < `SEQ_PACKET_SIZE; j = j + 1) begin
      if (i_seq_packet_strb[j] & i_seq_packet_eoj[j]) begin
        seq_packet_ll_last = i_seq_packet_ll[j*`SEQ_LL_BITS+:`SEQ_LL_BITS];
        seq_packet_ml_last = i_seq_packet_ml[j*`SEQ_ML_BITS+:`SEQ_ML_BITS];
        seq_packet_offset_last = i_seq_packet_offset[j*`SEQ_OFFSET_BITS+:`SEQ_OFFSET_BITS];
        seq_packet_overlap_last = i_seq_packet_overlap[j*`SEQ_ML_BITS+:`SEQ_ML_BITS];
        eoj_delim_last = i_eoj_delim[j];
      end else begin
        seq_packet_ll_last = seq_packet_ll_last;
        seq_packet_ml_last = seq_packet_ml_last;
        seq_packet_offset_last = seq_packet_offset_last;
        seq_packet_overlap_last = seq_packet_overlap_last;
        eoj_delim_last = eoj_delim_last;
      end
    end
  end
  // 保存 eoj 的时序逻辑
  always @(posedge clk) begin
    if (state_reg == S_PASS && i_seq_packet_has_eoj) begin
      seq_packet_ll_last_reg <= seq_packet_ll_last;
      seq_packet_ml_last_reg <= seq_packet_ml_last;
      seq_packet_offset_last_reg <= seq_packet_offset_last;
      seq_packet_overlap_last_reg <= seq_packet_overlap_last;
      eoj_delim_last_reg <= eoj_delim_last;
    end
  end

  wire handshake_reg_valid, handshake_reg_ready;
  wire has_pass_seq = |seq_packet_strb;
  assign handshake_reg_valid = ((state_reg == S_PASS) & i_seq_packet_valid & has_pass_seq) | (state_reg == S_FLUSH_BUF);
  // S_PASS 状态下，输入有效，且包含有效seq时 handshake_reg valid 有效
  // S_FLUSH 状态下，handshake_reg valid 有效
  assign i_seq_packet_ready = ((state_reg == S_PASS) & (has_pass_seq ? handshake_reg_ready : 1'b1));
  // S_PASS 状态下，有有效seq时等待handshake_reg握手，
  // 或者输入没有有效seq，则不需要等待handshake_reg
  // S_FLUSH_BUF 状态下，输入不握手

  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg <= S_PASS;
    end else begin
      case (state_reg)
        S_PASS: begin
          if (i_seq_packet_valid & i_seq_packet_ready) begin
            if (i_seq_packet_has_eoj) begin
              state_reg <= S_FLUSH_BUF;
            end
          end
        end
        S_FLUSH_BUF: begin
          if (handshake_reg_ready) begin
            state_reg <= S_PASS;
          end
        end
        default: begin
          state_reg <= S_PASS;
        end
      endcase
    end
  end

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
            o_first_seq_len,
            o_first_ll_gte_mml,
            o_eoj_delim,
            o_eoj_gap_gt_0,
            o_eoj_gap_overlap_eq_0,
            o_eoj_0_lt_overlap_lt_job_len,
            o_eoj_job_len_lte_overlap
          }
      ))
  ) handshake_reg (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(handshake_reg_valid),
      .input_payload({
        seq_packet_strb,
        seq_packet_ll,
        seq_packet_ml,
        seq_packet_offset,
        seq_packet_overlap,
        seq_packet_eoj,
        first_seq_len,
        first_ll_gte_mml,
        eoj_delim,
        eoj_gap_gt_0,
        eoj_gap_overlap_eq_0,
        eoj_0_lt_overlap_lt_job_len,
        eoj_job_len_lte_overlap
      }),
      .input_ready(handshake_reg_ready),
      .output_valid(o_seq_packet_valid),
      .output_payload({
        o_seq_packet_strb,
        o_seq_packet_ll,
        o_seq_packet_ml,
        o_seq_packet_offset,
        o_seq_packet_overlap,
        o_seq_packet_eoj,
        o_first_seq_len,
        o_first_ll_gte_mml,
        o_eoj_delim,
        o_eoj_gap_gt_0,
        o_eoj_gap_overlap_eq_0,
        o_eoj_0_lt_overlap_lt_job_len,
        o_eoj_job_len_lte_overlap
      }),
      .output_ready(o_seq_packet_ready)
  );

endmodule
