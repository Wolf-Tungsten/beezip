`include "parameters.vh"
`include "util.vh"

module seq_packet_overlap_eliminate (
    input wire clk,
    input wire rst_n,

    // input seq packet port
    input wire i_seq_packet_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] i_seq_packet_strb,
    input wire [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] i_seq_packet_ll,
    input wire [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] i_seq_packet_ml,
    input wire [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] i_seq_packet_offset,
    input wire [`SEQ_LL_BITS-1:0] i_first_seq_len,
    input wire i_first_ll_gte_mml,
    input wire [`SEQ_ML_BITS-1:0] i_seq_packet_overlap,
    input wire i_seq_packet_eoj,
    input wire i_eoj_delim,
    input wire i_eoj_gap_gt_0,
    input wire i_eoj_gap_overlap_eq_0,
    input wire i_eoj_0_lt_overlap_lt_job_len,
    input wire i_eoj_job_len_lte_overlap,
    output reg i_seq_packet_ready,

    output reg o_seq_packet_valid,
    output reg [`SEQ_PACKET_SIZE-1:0] o_seq_packet_strb,
    output reg [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] o_seq_packet_ll,
    output reg [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] o_seq_packet_ml,
    output reg [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] o_seq_packet_offset,
    output reg o_seq_packet_delim,
    input wire o_seq_packet_ready
);

  localparam S_EMPTY = 0;
  localparam S_NORMAL = 1;
  localparam S_FLUSH = 2;
  localparam S_HANDLE_GAP = 3;
  localparam S_HANDLE_OVERLAP = 4;
  localparam S_SKIP_NEXT_JOB = 5;

  reg [5:0] state_reg;
  reg [5:0] next_state;
  reg update_state;

  reg [`SEQ_PACKET_SIZE-1:0] buf_seq_packet_strb_reg;
  reg [`SEQ_PACKET_SIZE*`SEQ_LL_BITS-1:0] buf_seq_packet_ll_reg;
  reg [`SEQ_PACKET_SIZE*`SEQ_ML_BITS-1:0] buf_seq_packet_ml_reg;
  reg [`SEQ_PACKET_SIZE*`SEQ_OFFSET_BITS-1:0] buf_seq_packet_offset_reg;
  reg [`SEQ_LL_BITS-1:0] buf_seq_len_reg;
  reg [`SEQ_ML_BITS-1:0] buf_seq_overlap_reg;
  reg buf_seq_packet_delim_reg;

  wire hop_output_seq_valid;
  wire [`SEQ_LL_BITS-1:0] hop_output_seq_ll;
  wire [`SEQ_ML_BITS-1:0] hop_output_seq_ml;
  wire [`SEQ_OFFSET_BITS-1:0] hop_output_seq_offset;

  wire hop_next_buf_seq_valid;
  wire [`SEQ_LL_BITS-1:0] hop_next_buf_seq_ll;
  wire [`SEQ_ML_BITS-1:0] hop_next_buf_seq_ml;
  wire [`SEQ_OFFSET_BITS-1:0] hop_next_buf_seq_offset;
  wire [`SEQ_LL_BITS-1:0] hop_next_buf_seq_len;
  wire [`SEQ_ML_BITS-1:0] hop_next_buf_seq_overlap;
  wire hop_next_buf_delim;

  wire hop_turn_to_empty;
  wire hop_turn_to_normal;
  wire hop_turn_to_flush;
  wire hop_turn_to_handle_gap;
  wire hop_turn_to_handle_overlap;
  wire hop_turn_to_skip_next_job;

  wire hop_buf_update;

  handle_overlap_process hop_inst (
      .buf_seq_ll(buf_seq_packet_ll_reg[`SEQ_LL_BITS-1:0]),
      .buf_seq_ml(buf_seq_packet_ml_reg[`SEQ_ML_BITS-1:0]),
      .buf_seq_offset(buf_seq_packet_offset_reg[`SEQ_OFFSET_BITS-1:0]),
      .buf_seq_len(buf_seq_len_reg),
      .buf_seq_overlap(buf_seq_overlap_reg),

      .next_seq_ll(i_seq_packet_ll[`SEQ_LL_BITS-1:0]),
      .next_seq_ml(i_seq_packet_ml[`SEQ_ML_BITS-1:0]),
      .next_seq_offset(i_seq_packet_offset[`SEQ_OFFSET_BITS-1:0]),
      .next_seq_len(i_first_seq_len),
      .next_seq_eoj(i_seq_packet_eoj),
      .next_seq_delim(i_eoj_delim),
      .next_seq_overlap(i_seq_packet_overlap),
      .next_seq_ll_gte_mml(i_first_ll_gte_mml),
      .next_seq_gap_gt_0(i_eoj_gap_gt_0),
      .next_seq_gap_overlap_eq_0(i_eoj_gap_overlap_eq_0),
      .next_seq_0_lt_overlap_lt_job_len(i_eoj_0_lt_overlap_lt_job_len),
      .next_seq_job_len_lte_overlap(i_eoj_job_len_lte_overlap),

      .output_seq_valid(hop_output_seq_valid),
      .output_seq_ll(hop_output_seq_ll),
      .output_seq_ml(hop_output_seq_ml),
      .output_seq_offset(hop_output_seq_offset),

      .next_buf_seq_valid(hop_next_buf_seq_valid),
      .next_buf_seq_ll(hop_next_buf_seq_ll),
      .next_buf_seq_ml(hop_next_buf_seq_ml),
      .next_buf_seq_offset(hop_next_buf_seq_offset),
      .next_buf_seq_len(hop_next_buf_seq_len),
      .next_buf_seq_overlap(hop_next_buf_seq_overlap),
      .next_buf_delim(hop_next_buf_delim),

      .turn_to_empty(hop_turn_to_empty),
      .turn_to_normal(hop_turn_to_normal),
      .turn_to_flush(hop_turn_to_flush),
      .turn_to_handle_gap(hop_turn_to_handle_gap),
      .turn_to_handle_overlap(hop_turn_to_handle_overlap),
      .turn_to_skip_next_job(hop_turn_to_skip_next_job),
      .buf_update(hop_buf_update)
  );

  // hgp_inst
  wire [`SEQ_LL_BITS-1:0] hgp_next_buf_seq_ll;
  wire [`SEQ_ML_BITS-1:0] hgp_next_buf_seq_ml;
  wire [`SEQ_OFFSET_BITS-1:0] hgp_next_buf_seq_offset;
  wire [`SEQ_LL_BITS-1:0] hgp_next_buf_seq_len;
  wire [`SEQ_ML_BITS-1:0] hgp_next_buf_seq_overlap;
  wire hgp_next_buf_delim;

  wire hgp_turn_to_empty;
  wire hgp_turn_to_normal;
  wire hgp_turn_to_flush;
  wire hgp_turn_to_handle_gap;
  wire hgp_turn_to_handle_overlap;
  wire hgp_turn_to_skip_next_job;

  handle_gap_process hgp_inst (
    .buf_seq_ll(buf_seq_packet_ll_reg[`SEQ_LL_BITS-1:0]),
    .buf_seq_ml(buf_seq_packet_ml_reg[`SEQ_ML_BITS-1:0]),
    .buf_seq_offset(buf_seq_packet_offset_reg[`SEQ_OFFSET_BITS-1:0]),
    .buf_seq_len(buf_seq_len_reg),
    .buf_seq_overlap(buf_seq_overlap_reg),

    .next_seq_ll(i_seq_packet_ll[`SEQ_LL_BITS-1:0]),
    .next_seq_ml(i_seq_packet_ml[`SEQ_ML_BITS-1:0]),
    .next_seq_offset(i_seq_packet_offset[`SEQ_OFFSET_BITS-1:0]),
    .next_seq_len(i_first_seq_len),
    .next_seq_eoj(i_seq_packet_eoj),
    .next_seq_delim(i_eoj_delim),
    .next_seq_overlap(i_seq_packet_overlap),
    .next_seq_ll_gte_mml(i_first_ll_gte_mml),
    .next_seq_gap_gt_0(i_eoj_gap_gt_0),
    .next_seq_gap_overlap_eq_0(i_eoj_gap_overlap_eq_0),
    .next_seq_0_lt_overlap_lt_job_len(i_eoj_0_lt_overlap_lt_job_len),
    .next_seq_job_len_lte_overlap(i_eoj_job_len_lte_overlap),

    .next_buf_seq_ll(hgp_next_buf_seq_ll),
    .next_buf_seq_ml(hgp_next_buf_seq_ml),
    .next_buf_seq_offset(hgp_next_buf_seq_offset),
    .next_buf_seq_len(hgp_next_buf_seq_len),
    .next_buf_seq_overlap(hgp_next_buf_seq_overlap),
    .next_buf_delim(hgp_next_buf_delim),

    .turn_to_empty(hgp_turn_to_empty),
    .turn_to_normal(hgp_turn_to_normal),
    .turn_to_flush(hgp_turn_to_flush),
    .turn_to_handle_gap(hgp_turn_to_handle_gap),
    .turn_to_handle_overlap(hgp_turn_to_handle_overlap),
    .turn_to_skip_next_job(hgp_turn_to_skip_next_job)
  );
  // 

  // 状态机转换
  always @(*) begin
    next_state = '0;
    update_state = 1'b0;
    case (1'b1)
      state_reg[S_EMPTY]: begin
        if (i_seq_packet_valid) begin
          update_state = 1'b1;
          if (i_seq_packet_eoj) begin
            if (i_eoj_delim) begin
              next_state[S_FLUSH] = 1'b1;
            end else begin
              if (i_eoj_gap_gt_0) begin
                next_state[S_HANDLE_GAP] = 1'b1;
              end else if (i_eoj_gap_overlap_eq_0) begin
                next_state[S_NORMAL] = 1'b1;
              end else if (i_eoj_0_lt_overlap_lt_job_len) begin
                next_state[S_HANDLE_OVERLAP] = 1'b1;
              end else if (i_eoj_job_len_lte_overlap) begin
                next_state[S_SKIP_NEXT_JOB] = 1'b1;
              end else begin
                `FATAL_ERROR("Illegal eoj state");
              end
            end
          end else begin
            next_state[S_NORMAL] = 1'b1;
          end
        end
      end
      state_reg[S_NORMAL]: begin
        if (i_seq_packet_valid & o_seq_packet_ready) begin
          update_state = 1'b1;
          if (i_seq_packet_eoj) begin
            if (i_eoj_delim) begin
              next_state[S_FLUSH] = 1'b1;
            end else begin
              if (i_eoj_gap_gt_0) begin
                next_state[S_HANDLE_GAP] = 1'b1;
              end else if (i_eoj_gap_overlap_eq_0) begin
                next_state[S_NORMAL] = 1'b1;
              end else if (i_eoj_0_lt_overlap_lt_job_len) begin
                next_state[S_HANDLE_OVERLAP] = 1'b1;
              end else if (i_eoj_job_len_lte_overlap) begin
                next_state[S_SKIP_NEXT_JOB] = 1'b1;
              end else begin
                `FATAL_ERROR("Illegal eoj state");
              end
            end
          end else begin
            next_state[S_NORMAL] = 1'b1;
          end
        end else if (~i_seq_packet_valid & o_seq_packet_ready) begin
          update_state = 1'b1;
          next_state[S_EMPTY] = 1'b1;
        end
      end
      state_reg[S_FLUSH]: begin
        if (o_seq_packet_ready) begin
          update_state = 1'b1;
          next_state[S_EMPTY] = 1'b1;
        end
      end
      state_reg[S_HANDLE_GAP]: begin
        if(i_seq_packet_valid) begin
          update_state = 1'b1;
          case(1'b1)
            hgp_turn_to_empty: begin
              next_state[S_EMPTY] = 1'b1;
            end
            hgp_turn_to_normal: begin
              next_state[S_NORMAL] = 1'b1;
            end
            hgp_turn_to_flush: begin
              next_state[S_FLUSH] = 1'b1;
            end
            hgp_turn_to_handle_gap: begin
              next_state[S_HANDLE_GAP] = 1'b1;
            end
            hgp_turn_to_handle_overlap: begin
              next_state[S_HANDLE_OVERLAP] = 1'b1;
            end
            hgp_turn_to_skip_next_job: begin
              next_state[S_SKIP_NEXT_JOB] = 1'b1;
            end
            default: begin
              `FATAL_ERROR("Illegal handle_gap_process state");
            end
          endcase
        end
      end
      state_reg[S_HANDLE_OVERLAP]: begin
        if (i_seq_packet_valid && o_seq_packet_ready) begin
          update_state = 1'b1;
          case (1'b1)
            hop_turn_to_empty: begin
              next_state[S_EMPTY] = 1'b1;
            end
            hop_turn_to_normal: begin
              next_state[S_NORMAL] = 1'b1;
            end
            hop_turn_to_flush: begin
              next_state[S_FLUSH] = 1'b1;
            end
            hop_turn_to_handle_gap: begin
              next_state[S_HANDLE_GAP] = 1'b1;
            end
            hop_turn_to_handle_overlap: begin
              next_state[S_HANDLE_OVERLAP] = 1'b1;
            end
            hop_turn_to_skip_next_job: begin
              next_state[S_SKIP_NEXT_JOB] = 1'b1;
            end
            default: begin
              `FATAL_ERROR("Illegal handle_overlap_process state");
            end
          endcase
        end
      end
      state_reg[S_SKIP_NEXT_JOB]: begin
        if(i_seq_packet_valid & i_seq_packet_eoj) begin
          if(buf_seq_overlap_reg == `JOB_LEN) begin
            update_state = 1'b1;
            next_state[S_FLUSH] = 1'b1;
          end else if (buf_seq_overlap_reg < 2 * `JOB_LEN) begin
            update_state = 1'b1;
            next_state[S_HANDLE_OVERLAP] = 1'b1;
          end
        end
      end
      default: begin
        update_state = 1'b1;
        next_state[S_EMPTY] = 1'b1;  // 默认复位到 S0
      end
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg <= 6'b1;
    end else begin
      if(update_state) begin
        state_reg <= next_state;
      end
    end
  end

  // 输出逻辑
  always @(*) begin
    i_seq_packet_ready = 1'b0;
    o_seq_packet_valid = 1'b0;
    o_seq_packet_ll = '0;
    o_seq_packet_ml = '0;
    o_seq_packet_offset = '0;
    o_seq_packet_delim = 1'b0;
    case (1'b1)
      state_reg[S_EMPTY]: begin
        i_seq_packet_ready = 1'b1;
      end
      state_reg[S_NORMAL]: begin
        o_seq_packet_valid = 1'b1;
        o_seq_packet_ll = buf_seq_packet_ll_reg;
        o_seq_packet_ml = buf_seq_packet_ml_reg;
        o_seq_packet_offset = buf_seq_packet_offset_reg;
        o_seq_packet_delim = buf_seq_packet_delim_reg;
        i_seq_packet_ready = o_seq_packet_ready;
      end
      state_reg[S_FLUSH]: begin
        o_seq_packet_valid = 1'b1;
        o_seq_packet_ll = buf_seq_packet_ll_reg;
        o_seq_packet_ml = buf_seq_packet_ml_reg;
        o_seq_packet_offset = buf_seq_packet_offset_reg;
        o_seq_packet_delim = buf_seq_packet_delim_reg;
      end
      state_reg[S_HANDLE_GAP]: begin
        i_seq_packet_ready = 1'b1;
      end
      state_reg[S_HANDLE_OVERLAP]: begin
        o_seq_packet_strb = `ZERO_EXTEND(hop_output_seq_valid, `SEQ_PACKET_SIZE);
        o_seq_packet_ll = `ZERO_EXTEND(hop_output_seq_ll, `SEQ_PACKET_SIZE * `SEQ_LL_BITS);
        o_seq_packet_ml = `ZERO_EXTEND(hop_output_seq_ml, `SEQ_PACKET_SIZE * `SEQ_ML_BITS);
        o_seq_packet_offset = `ZERO_EXTEND(hop_output_seq_offset,
                                           `SEQ_PACKET_SIZE * `SEQ_OFFSET_BITS);
        o_seq_packet_delim = 1'b0;
        // 握手部分
        o_seq_packet_valid = hop_output_seq_valid;
        i_seq_packet_ready = o_seq_packet_ready;
      end
      state_reg[S_SKIP_NEXT_JOB]: begin
        i_seq_packet_ready = 1'b1;
      end
      default: begin

      end
    endcase
  end

  wire [`SEQ_PACKET_SIZE-1-1:0] remain_seq_packet_strb = i_seq_packet_strb[1 +: `SEQ_PACKET_SIZE-1];
  wire [(`SEQ_PACKET_SIZE-1)*`SEQ_LL_BITS-1:0] remain_seq_packet_ll = i_seq_packet_ll[`SEQ_LL_BITS +: (`SEQ_PACKET_SIZE-1)*`SEQ_LL_BITS];
  wire [(`SEQ_PACKET_SIZE-1)*`SEQ_ML_BITS-1:0] remain_seq_packet_ml = i_seq_packet_ml[`SEQ_ML_BITS +: (`SEQ_PACKET_SIZE-1)*`SEQ_ML_BITS];
  wire [(`SEQ_PACKET_SIZE-1)*`SEQ_OFFSET_BITS-1:0] remain_seq_packet_offset = i_seq_packet_offset[`SEQ_OFFSET_BITS +: (`SEQ_PACKET_SIZE-1)*`SEQ_OFFSET_BITS];

  // buf 更新逻辑
  always @(posedge clk) begin
    case (1'b1)
      state_reg[S_EMPTY]: begin
        if (i_seq_packet_valid) begin
          buf_seq_packet_strb_reg <= i_seq_packet_strb;
          buf_seq_packet_ll_reg <= i_seq_packet_ll;
          buf_seq_packet_ml_reg <= i_seq_packet_ml;
          buf_seq_packet_offset_reg <= i_seq_packet_offset;
          buf_seq_len_reg <= i_first_seq_len;
          buf_seq_overlap_reg <= i_seq_packet_overlap;
          buf_seq_packet_delim_reg <= i_eoj_delim;
        end
      end
      state_reg[S_NORMAL]: begin
        if (i_seq_packet_valid & o_seq_packet_ready) begin
          buf_seq_packet_strb_reg <= i_seq_packet_strb;
          buf_seq_packet_ll_reg <= i_seq_packet_ll;
          buf_seq_packet_ml_reg <= i_seq_packet_ml;
          buf_seq_packet_offset_reg <= i_seq_packet_offset;
          buf_seq_len_reg <= i_first_seq_len;
          buf_seq_overlap_reg <= i_seq_packet_overlap;
          buf_seq_packet_delim_reg <= i_eoj_delim;
        end
      end
      state_reg[S_FLUSH]: begin
        // Do Nothing
      end
      state_reg[S_HANDLE_GAP]: begin
        if(i_seq_packet_valid) begin
          buf_seq_packet_strb_reg <= i_seq_packet_strb;
          buf_seq_packet_ll_reg <= {remain_seq_packet_ll, hgp_next_buf_seq_ll};
          buf_seq_packet_ml_reg <= {remain_seq_packet_ml, hgp_next_buf_seq_ml};
          buf_seq_packet_offset_reg <= {remain_seq_packet_offset, hgp_next_buf_seq_offset};
          buf_seq_len_reg <= hgp_next_buf_seq_len;
          buf_seq_overlap_reg <= hgp_next_buf_seq_overlap;
          buf_seq_packet_delim_reg <= hgp_next_buf_delim;
        end
      end
      state_reg[S_HANDLE_OVERLAP]: begin
        if (hop_buf_update) begin
          if (i_seq_packet_valid & o_seq_packet_ready) begin
            buf_seq_packet_strb_reg <= {remain_seq_packet_strb, hop_next_buf_seq_valid};
            buf_seq_packet_ll_reg <= {remain_seq_packet_ll, hop_next_buf_seq_ll};
            buf_seq_packet_ml_reg <= {remain_seq_packet_ml, hop_next_buf_seq_ml};
            buf_seq_packet_offset_reg <= {remain_seq_packet_offset, hop_next_buf_seq_offset};
            buf_seq_len_reg <= hop_next_buf_seq_len;
            buf_seq_overlap_reg <= hop_next_buf_seq_overlap;
            buf_seq_packet_delim_reg <= hop_next_buf_delim;
          end
        end
      end
      state_reg[S_SKIP_NEXT_JOB]: begin
        if(i_seq_packet_valid & i_seq_packet_eoj) begin
          buf_seq_packet_delim_reg <= i_eoj_delim;
          buf_seq_overlap_reg <= buf_seq_overlap_reg - `JOB_LEN; 
        end
      end
      default: next_state[S_EMPTY] = 1'b1;  // 默认复位到 S0
    endcase
  end

endmodule
