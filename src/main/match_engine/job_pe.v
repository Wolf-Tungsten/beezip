`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module job_pe (
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

    // output seq port
    output reg seq_valid,
    output reg [`SEQ_LL_BITS-1:0] seq_ll,
    output reg [`SEQ_ML_BITS-1:0] seq_ml,
    output reg [`SEQ_OFFSET_BITS-1:0] seq_offset,
    output reg seq_eoj,
    output reg [`SEQ_ML_BITS-1:0] seq_overlap_len,
    output reg seq_delim,
    input wire seq_ready,

    // match request port
    output wire match_req_valid,
    output wire [`ADDR_WIDTH-1:0] match_req_head_addr,
    output reg [`ADDR_WIDTH-1:0] match_req_history_addr,
    output reg [`LAZY_MATCH_LEN_LOG2-1:0] match_req_tag,
    input wire match_req_ready,

    // match resp port
    input wire match_resp_valid,
    input wire [`MATCH_LEN_WIDTH-1:0] match_resp_len,
    input wire [`LAZY_MATCH_LEN_LOG2-1:0] match_resp_tag,
    output wire match_resp_ready
);

  localparam SEQ_OFFSET_BITS_LOG2 = $clog2(`SEQ_OFFSET_BITS);
  localparam LAZY_GAIN_BITS = `MATCH_LEN_WIDTH + 3;

  reg [`ADDR_WIDTH-1:0] job_head_addr_reg;
  reg job_delim_reg;
  reg [`JOB_LEN-1:0] job_tbl_history_valid_reg;
  reg [`JOB_LEN*`ADDR_WIDTH-1:0] job_tbl_history_addr_reg;
  reg [`JOB_LEN*`META_MATCH_LEN_WIDTH-1:0] job_tbl_meta_match_len_reg;
  reg [`JOB_LEN-1:0] job_tbl_meta_match_can_ext_reg;
  reg [`JOB_LEN*`SEQ_OFFSET_BITS-1:0] job_tbl_offset_reg; // 在 LOAD 时计算
  reg [`JOB_LEN*SEQ_OFFSET_BITS_LOG2-1:0] job_tbl_offset_bits_reg; // 在 SEEK_MATCH_HEAD 时计算

  // state machine
  localparam S_LOAD = 3'b001;
  localparam S_SEEK_MATCH_HEAD = 3'b010;
  localparam S_LAZY_MATCH = 3'b011;
  localparam S_LAZY_SUMMARY = 3'b100;
  localparam S_LIT_TAIL = 3'b101;
  reg [2:0] state_reg;

  // load part logic
  localparam LOAD_COUNT_LOG2 = `JOB_LEN_LOG2 - `HASH_ISSUE_WIDTH_LOG2;
  localparam MAX_LOAD_COUNT = 2 ** LOAD_COUNT_LOG2;
  reg [LOAD_COUNT_LOG2+1-1:0] load_counter_reg;
  wire [`HASH_ISSUE_WIDTH*`SEQ_OFFSET_BITS-1:0] hash_batch_offset;
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_history_addr_meta_bias;
  genvar g_i;
  // 在 load 时计算 offset
  generate
    for(g_i = 0; g_i < `HASH_ISSUE_WIDTH; g_i = g_i + 1) begin: HASH_BATCH_OFFSET_GEN
      assign `VEC_SLICE(hash_batch_offset, g_i, `SEQ_OFFSET_BITS) = {hash_batch_head_addr + g_i[`ADDR_WIDTH-1:0] - `VEC_SLICE(hash_batch_history_addr, g_i, `ADDR_WIDTH)}[`SEQ_OFFSET_BITS-1:0];
      assign `VEC_SLICE(hash_batch_history_addr_meta_bias, g_i, `ADDR_WIDTH) = `VEC_SLICE(hash_batch_history_addr, g_i, `ADDR_WIDTH) + `META_HISTORY_LEN;
    end
  endgenerate
  assign hash_batch_ready = (state_reg == S_LOAD);
  always @(posedge clk) begin
    if (!rst_n) begin
      load_counter_reg <= '0;
    end else begin
      if ((state_reg == S_LOAD) && hash_batch_valid) begin
        if (load_counter_reg == 0) begin
          job_head_addr_reg <= hash_batch_head_addr;
        end else if (load_counter_reg == (MAX_LOAD_COUNT[LOAD_COUNT_LOG2-1:0] - 1)) begin
          job_delim_reg <= hash_batch_delim;
        end
        for (integer i = 0; i < MAX_LOAD_COUNT; i = i + 1) begin
          if (i[LOAD_COUNT_LOG2+1-1:0] == load_counter_reg) begin
            job_tbl_history_valid_reg[i * `HASH_ISSUE_WIDTH +: `HASH_ISSUE_WIDTH] <= hash_batch_history_valid;
            job_tbl_history_addr_reg[i * `ADDR_WIDTH * `HASH_ISSUE_WIDTH +: `ADDR_WIDTH * `HASH_ISSUE_WIDTH] <= hash_batch_history_addr_meta_bias;
            job_tbl_meta_match_len_reg[i * `META_MATCH_LEN_WIDTH * `HASH_ISSUE_WIDTH +: `META_MATCH_LEN_WIDTH * `HASH_ISSUE_WIDTH] <= hash_batch_meta_match_len;
            job_tbl_meta_match_can_ext_reg[i * `HASH_ISSUE_WIDTH +: `HASH_ISSUE_WIDTH] <= hash_batch_meta_match_can_ext;
            job_tbl_offset_reg[i * `SEQ_OFFSET_BITS * `HASH_ISSUE_WIDTH +: `SEQ_OFFSET_BITS * `HASH_ISSUE_WIDTH] <= hash_batch_offset;
          end
        end
        load_counter_reg <= load_counter_reg + 1;
      end else begin
        load_counter_reg <= '0;
      end
    end
  end

  // seek match head part logic
  reg [`JOB_LEN_LOG2-1:0] seq_head_ptr_reg;
  reg [`JOB_LEN_LOG2-1:0] match_head_ptr_reg;
  reg [`SEQ_ML_BITS-1:0] best_seq_next_idx;
  wire [`JOB_LEN * SEQ_OFFSET_BITS_LOG2-1:0] job_tbl_offset_bits;
  generate
    for(g_i = 0; g_i < `JOB_LEN; g_i = g_i + 1) begin: JOB_TBL_OFFSET_BITS_GEN
      /* verilator lint_off PINCONNECTEMPTY */
      priority_encoder #(`SEQ_OFFSET_BITS) job_tbl_offset_bits_enc (
        .input_vec(`VEC_SLICE(job_tbl_offset_reg, g_i, `SEQ_OFFSET_BITS)),
        .output_valid(),
        .output_index(`VEC_SLICE(job_tbl_offset_bits, g_i, SEQ_OFFSET_BITS_LOG2))
      );
    end
  endgenerate
  always @(posedge clk) begin
    if (state_reg == S_LOAD) begin
      seq_head_ptr_reg   <= 0;
      match_head_ptr_reg <= 0;
    end else if (state_reg == S_SEEK_MATCH_HEAD) begin
      job_tbl_offset_bits_reg <= job_tbl_offset_bits;
      if((match_head_ptr_reg < `JOB_LEN - 8) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 8] == 8'h00)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 4;
      end else if ((match_head_ptr_reg < `JOB_LEN - 4) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 4] == 4'h0)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 2;
      end else if ((match_head_ptr_reg < `JOB_LEN - 1) && (job_tbl_history_valid_reg[match_head_ptr_reg] == 1'b0)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 1;
      end
    end else if (state_reg == S_LAZY_SUMMARY) begin
      if (seq_valid && seq_ready) begin
        seq_head_ptr_reg <= best_seq_next_idx[`JOB_LEN_LOG2-1:0];
        match_head_ptr_reg <= best_seq_next_idx[`JOB_LEN_LOG2-1:0];
      end
    end
  end

  
  // lazy match part logic
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_valid_reg;
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_pending_reg;
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_done_reg;
  reg [`LAZY_MATCH_LEN*`JOB_LEN_LOG2-1:0] lazy_tbl_idx_reg;
  reg [`LAZY_MATCH_LEN*`ADDR_WIDTH-1:0] lazy_tbl_head_addr_reg;
  reg [`LAZY_MATCH_LEN*`ADDR_WIDTH-1:0] lazy_tbl_history_addr_reg;
  reg [`LAZY_MATCH_LEN*`MATCH_LEN_WIDTH-1:0] lazy_tbl_match_len_reg;
  reg [`LAZY_MATCH_LEN*`SEQ_OFFSET_BITS-1:0] lazy_tbl_offset_reg;
  reg [`LAZY_MATCH_LEN*SEQ_OFFSET_BITS_LOG2-1:0] lazy_tbl_offset_bits_reg;
  reg [`LAZY_MATCH_LEN*LAZY_GAIN_BITS-1:0] lazy_tbl_match_gain_reg;
  wire [`LAZY_MATCH_LEN*LAZY_GAIN_BITS-1:0] lazy_tbl_match_gain;

  generate
    for(g_i = 0; g_i < `LAZY_MATCH_LEN; g_i = g_i + 1) begin: LAZY_TBL_OFFSET_HIGHBIT_ENC
      wire [LAZY_GAIN_BITS-1:0] bias = (`LAZY_MATCH_LEN - g_i) * 4;
      assign `VEC_SLICE(lazy_tbl_match_gain, g_i, LAZY_GAIN_BITS) = (`ZERO_EXTEND(`VEC_SLICE(lazy_tbl_match_len_reg, g_i, `MATCH_LEN_WIDTH), LAZY_GAIN_BITS) << 2) + bias;
    end
  endgenerate

  function automatic [`JOB_LEN_LOG2-1:0] match_head_relative_idx;
    input integer idx;
    begin
      match_head_relative_idx = match_head_ptr_reg + idx[`JOB_LEN_LOG2-1:0];
    end
  endfunction

  wire [`LAZY_MATCH_LEN-1:0] lazy_match_req_sel;
  priority_selector #(
    .W(`LAZY_MATCH_LEN)
  ) lazy_match_req_sel_inst (
    .input_vec(lazy_tbl_pending_reg),
    .output_vec(lazy_match_req_sel)
  );
  
  always @(posedge clk) begin
    if(state_reg == S_SEEK_MATCH_HEAD && job_tbl_history_valid_reg[match_head_ptr_reg]) begin
      for(integer i = 0; i < `LAZY_MATCH_LEN; i = i + 1) begin
        if({1'b0, match_head_ptr_reg} + i[`JOB_LEN_LOG2+1-1:0] < `JOB_LEN) begin
          lazy_tbl_valid_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)];
          lazy_tbl_pending_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)] && job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)];
          lazy_tbl_done_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)] ? (!job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)]) : 1'b1;
          `VEC_SLICE(lazy_tbl_idx_reg, i, `JOB_LEN_LOG2) <= match_head_relative_idx(i);
          // lazy_table 中的地址已经增加了 META_HISTORY_LEN 偏移
          `VEC_SLICE(lazy_tbl_head_addr_reg, i, `ADDR_WIDTH) <= job_head_addr_reg + `ZERO_EXTEND(match_head_relative_idx(i), `ADDR_WIDTH) + `META_HISTORY_LEN;
          `VEC_SLICE(lazy_tbl_history_addr_reg, i, `ADDR_WIDTH) <= `VEC_SLICE(job_tbl_history_addr_reg, match_head_relative_idx(i), `ADDR_WIDTH) + `META_HISTORY_LEN;
          `VEC_SLICE(lazy_tbl_offset_reg, i, `SEQ_OFFSET_BITS) <= `VEC_SLICE(job_tbl_offset_reg, match_head_relative_idx(i), `SEQ_OFFSET_BITS);
          `VEC_SLICE(lazy_tbl_offset_bits_reg, i, SEQ_OFFSET_BITS_LOG2) <= `VEC_SLICE(job_tbl_offset_bits_reg, match_head_relative_idx(i), SEQ_OFFSET_BITS_LOG2); 
          // lazy_table 中的 match_len 初始值就是 meta history 的匹配长度
          `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) <= `ZERO_EXTEND(`VEC_SLICE(job_tbl_meta_match_len_reg, match_head_relative_idx(i), `META_MATCH_LEN_WIDTH), `MATCH_LEN_WIDTH);
        end else begin
          lazy_tbl_valid_reg[i] <= 1'b0;
          lazy_tbl_pending_reg[i] <= 1'b0;
          lazy_tbl_done_reg[i] <= 1'b1;
          `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) <= '0;
        end
      end
    end if (state_reg == S_LAZY_MATCH) begin
      if(match_req_valid && match_req_ready) begin
        // 请求发送成功，将 pending 寄存器对应位置清零
        lazy_tbl_pending_reg <= lazy_tbl_pending_reg & ~lazy_match_req_sel;
      end
      if(match_resp_valid && match_resp_ready) begin
        // 响应接收成功，将 done 寄存器对应位置置一
        // 并且将 match_len 累加
        lazy_tbl_done_reg[match_resp_tag] <= 1'b1;
        `VEC_SLICE(lazy_tbl_match_len_reg, match_resp_tag, `MATCH_LEN_WIDTH) <= `VEC_SLICE(lazy_tbl_match_len_reg, match_resp_tag, `MATCH_LEN_WIDTH) + match_resp_len;
      end
      lazy_tbl_match_gain_reg <= lazy_tbl_match_gain;
    end
  end

  assign match_req_valid = (state_reg == S_LAZY_MATCH) && (|lazy_tbl_pending_reg);
  mux1h #(.P_CNT(`LAZY_MATCH_LEN), .P_W(`ADDR_WIDTH)) match_req_head_addr_mux (
    .input_payload_vec(lazy_tbl_head_addr_reg),
    .input_select_vec(lazy_match_req_sel),
    .output_payload(match_req_head_addr)
  );
  mux1h #(.P_CNT(`LAZY_MATCH_LEN), .P_W(`ADDR_WIDTH)) match_req_history_addr_mux (
    .input_payload_vec(lazy_tbl_history_addr_reg),
    .input_select_vec(lazy_match_req_sel),
    .output_payload(match_req_history_addr)
  );
  wire tag_valid_dump;
  priority_encoder #(.W(`LAZY_MATCH_LEN)) match_req_tag_enc (
    .input_vec(lazy_tbl_pending_reg),
    .output_valid(tag_valid_dump),
    .output_index(match_req_tag)
  );

  assign match_resp_ready = (state_reg == S_LAZY_MATCH) && ~(&lazy_tbl_done_reg);

  // lazy summary part logic
  reg lazy_summary_gain_valid_reg;
  reg [`LAZY_MATCH_LEN*LAZY_GAIN_BITS-1:0] lazy_summary_gain_reg;
  reg [LAZY_GAIN_BITS-1:0] best_gain;
  reg [`JOB_LEN_LOG2-1:0] best_idx;
  reg [`SEQ_LL_BITS-1:0] best_seq_ll_tmp, best_seq_ll;
  reg [`SEQ_ML_BITS-1:0] best_seq_ml_tmp, best_seq_ml;
  reg [`SEQ_OFFSET_BITS-1:0] best_seq_offset_tmp, best_seq_offset;
  reg [`SEQ_ML_BITS-1:0] best_seq_overlap_len_tmp, best_seq_overlap_len;
  reg move_to_next_job;

  always @(*) begin
    best_gain = lazy_summary_gain_reg[LAZY_GAIN_BITS-1:0];
    best_idx = lazy_tbl_idx_reg[`JOB_LEN_LOG2-1:0];
    best_seq_ll_tmp = `ZERO_EXTEND({best_idx - seq_head_ptr_reg}, `SEQ_LL_BITS);
    best_seq_ml_tmp = `ZERO_EXTEND(`VEC_SLICE(lazy_tbl_match_len_reg, 0, `MATCH_LEN_WIDTH), `SEQ_ML_BITS);
    best_seq_offset_tmp = `ZERO_EXTEND(`VEC_SLICE(lazy_tbl_offset_reg, 0, `SEQ_OFFSET_BITS), `SEQ_OFFSET_BITS);
    for(integer i = 1; i < `LAZY_MATCH_LEN; i = i + 1) begin
      if(lazy_tbl_valid_reg[i] && (`VEC_SLICE(lazy_summary_gain_reg, i, LAZY_GAIN_BITS) > best_gain)) begin
        best_gain = `VEC_SLICE(lazy_summary_gain_reg, i, LAZY_GAIN_BITS);
        best_idx = `VEC_SLICE(lazy_tbl_idx_reg, i, `JOB_LEN_LOG2);
        best_seq_ll_tmp = `ZERO_EXTEND({best_idx - seq_head_ptr_reg}, `SEQ_LL_BITS);
        best_seq_ml_tmp = `ZERO_EXTEND(`VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH), `SEQ_ML_BITS);
        best_seq_offset_tmp = `ZERO_EXTEND(`VEC_SLICE(lazy_tbl_offset_reg, i, `SEQ_OFFSET_BITS), `SEQ_OFFSET_BITS);
      end
    end
    best_seq_next_idx = `ZERO_EXTEND(best_idx, `SEQ_ML_BITS) + best_seq_ml_tmp;
    if ( best_seq_next_idx >= `JOB_LEN ) begin
      move_to_next_job = 1'b1;
      best_seq_overlap_len_tmp = best_seq_next_idx - `JOB_LEN;
      if(job_delim_reg) begin
        best_seq_ll = best_seq_ll_tmp + (`JOB_LEN - `ZERO_EXTEND(best_idx, `SEQ_LL_BITS));
        best_seq_ml = '0;
        best_seq_offset = '0;
        best_seq_overlap_len = '0;
      end else begin
        best_seq_ll = best_seq_ll_tmp;
        best_seq_ml = best_seq_ml_tmp;
        best_seq_offset = best_seq_offset_tmp;
        best_seq_overlap_len = best_seq_overlap_len_tmp;
      end
    end else begin
      move_to_next_job = 1'b0;
      best_seq_overlap_len_tmp = '0;
      best_seq_ll = best_seq_ll_tmp;
      best_seq_ml = best_seq_ml_tmp;
      best_seq_offset = best_seq_offset_tmp;
      best_seq_overlap_len = best_seq_overlap_len_tmp;
    end
  end
  

  always @(posedge clk) begin
    if(state_reg == S_LAZY_MATCH) begin
      lazy_summary_gain_valid_reg <= 1'b0;
    end else if (state_reg == S_LAZY_SUMMARY) begin
      if(!lazy_summary_gain_valid_reg) begin
        for(integer i = 0; i < `LAZY_MATCH_LEN; i = i + 1) begin
          if(lazy_tbl_valid_reg[i]) begin
            `VEC_SLICE(lazy_summary_gain_reg, i, LAZY_GAIN_BITS) <= `VEC_SLICE(lazy_tbl_match_gain_reg, i, LAZY_GAIN_BITS) - `ZERO_EXTEND(`VEC_SLICE(lazy_tbl_offset_bits_reg, i, SEQ_OFFSET_BITS_LOG2), LAZY_GAIN_BITS);
          end else begin
            `VEC_SLICE(lazy_summary_gain_reg, i, LAZY_GAIN_BITS) <= '0;
          end
        end
        lazy_summary_gain_valid_reg <= 1'b1;
      end
    end
  end

  always @(*) begin
    case(state_reg)
      S_LAZY_SUMMARY: begin
        seq_valid = lazy_summary_gain_valid_reg;
        seq_ll = best_seq_ll;
        seq_ml = best_seq_ml;
        seq_offset = best_seq_offset;
        seq_eoj = move_to_next_job;
        seq_overlap_len = best_seq_overlap_len;
        seq_delim = job_delim_reg; 
      end
      S_LIT_TAIL: begin
        seq_valid = 1'b1;
        seq_ll = `ZERO_EXTEND((match_head_ptr_reg - seq_head_ptr_reg), `SEQ_LL_BITS);
        seq_ml = '0;
        seq_offset = '0;
        seq_eoj = 1'b1;
        seq_overlap_len = '0;
        seq_delim = job_delim_reg;
      end
      default:begin
        seq_valid = 1'b0;
        seq_ll = '0;
        seq_ml = '0;
        seq_offset = '0;
        seq_eoj = 1'b0;
        seq_overlap_len = '0;
        seq_delim = 1'b0;
      end
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg <= S_LOAD;
    end else begin
      // 状态机的转换
      case (state_reg)
        S_LOAD: begin
          if(hash_batch_valid && (load_counter_reg == (MAX_LOAD_COUNT[LOAD_COUNT_LOG2+1-1:0]-1))) begin
            state_reg <= S_SEEK_MATCH_HEAD;
          end
        end
        S_SEEK_MATCH_HEAD: begin
          if (job_tbl_history_valid_reg[match_head_ptr_reg]) begin
            state_reg <= S_LAZY_MATCH;
          end else if (match_head_ptr_reg == `JOB_LEN - 1) begin
            state_reg <= S_LIT_TAIL;
          end
        end
        S_LAZY_MATCH: begin
          if (&lazy_tbl_done_reg) begin
            state_reg <= S_LAZY_SUMMARY;
          end
        end
        S_LAZY_SUMMARY: begin
          if (seq_valid && seq_ready) begin
            if(move_to_next_job) begin
              state_reg <= S_LOAD;
            end else begin
              state_reg <= S_SEEK_MATCH_HEAD;
            end
          end
        end
        S_LIT_TAIL: begin
          if (seq_valid && seq_ready) begin
            state_reg <= S_LOAD;
          end
        end
        default: begin
          state_reg <= S_LOAD;
        end
      endcase
    end
  end




endmodule
