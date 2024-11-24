/**
  job_pe

  - 功能简述
    - 从 Hash Engine 接收 Match Job
    - 在 Match Job 内部进行串行处理，将仍然需要匹配的请求发送到 match_pe
    - 利用 lazy_summary_pipeline 汇总最优结果
    - 将最优结果通过 seq port 发出
*/
`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module job_pe #(parameter JOB_PE_IDX = 0) (
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
    output wire match_req_group_valid,
    output wire [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_head_addr,
    output reg [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_history_addr,
    output reg [`LAZY_LEN*`NUM_MATCH_REQ_CH-1:0] match_req_group_router_map,
    output reg [`LAZY_LEN-1:0] match_req_group_strb,
    input wire match_req_group_ready,

    input wire match_resp_group_valid,
    output wire match_resp_group_ready,
    input wire [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] match_resp_group_match_len
);

  localparam LAZY_GAIN_BITS = `MATCH_LEN_WIDTH + 3;

  reg [`ADDR_WIDTH-1:0] job_head_addr_reg;
  reg job_delim_reg;
  reg [`JOB_LEN-1:0] job_tbl_history_valid_reg;
  reg [`JOB_LEN*`ADDR_WIDTH-1:0] job_tbl_history_addr_reg;
  reg [`JOB_LEN*`META_MATCH_LEN_WIDTH-1:0] job_tbl_meta_match_len_reg;
  reg [`JOB_LEN-1:0] job_tbl_meta_match_can_ext_reg;
  reg [`JOB_LEN*`SEQ_OFFSET_BITS-1:0] job_tbl_offset_reg; // 在 LOAD 时计算

  // state machine
  localparam S_LOAD = 3'b001;
  localparam S_SEEK_MATCH_HEAD = 3'b010;
  localparam S_LAZY_MATCH_REQ = 3'b011;
  localparam S_LAZY_MATCH_RESP = 3'b100;
  localparam S_LAZY_SUMMARY = 3'b101;
  localparam S_LIT_TAIL = 3'b110;
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
      if ((state_reg == S_LOAD)) begin
        if(hash_batch_valid) begin
          $display("[job_pe @ %0t] LOAD %d", $time, load_counter_reg);
          if (load_counter_reg == 0) begin
            job_head_addr_reg <= hash_batch_head_addr;
          end else if (load_counter_reg == (MAX_LOAD_COUNT[LOAD_COUNT_LOG2+1-1:0] - 1)) begin
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
        end
      end else begin
        load_counter_reg <= '0;
      end
    end
  end

  // seek match head part logic
  reg [`JOB_LEN_LOG2-1:0] seq_head_ptr_reg;
  reg [`JOB_LEN_LOG2-1:0] match_head_ptr_reg;
  
  always @(posedge clk) begin
    if (state_reg == S_LOAD) begin
      seq_head_ptr_reg   <= 0;
      match_head_ptr_reg <= 0;
    end else if (state_reg == S_SEEK_MATCH_HEAD) begin
      $display("[job_pe %0d @ %0t] HistoryValid=%b", JOB_PE_IDX, $time, job_tbl_history_valid_reg);
      if((match_head_ptr_reg < `JOB_LEN - 8) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 8] == 8'h00)) begin
        $display("[job_pe %0d @ %0t] SEEK_MATCH_HEAD seq_head=%d, match_head=%d, move 8", JOB_PE_IDX, $time, seq_head_ptr_reg, match_head_ptr_reg);
        match_head_ptr_reg <= match_head_ptr_reg + 8;
      end else if ((match_head_ptr_reg < `JOB_LEN - 4) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 4] == 4'h0)) begin
        $display("[job_pe %0d @ %0t] SEEK_MATCH_HEAD seq_head=%d, match_head=%d, move 4", JOB_PE_IDX, $time, seq_head_ptr_reg, match_head_ptr_reg);
        match_head_ptr_reg <= match_head_ptr_reg + 4;
      end else if ((match_head_ptr_reg < `JOB_LEN - 1) && (job_tbl_history_valid_reg[match_head_ptr_reg] == 1'b0)) begin
        $display("[job_pe %0d @ %0t] SEEK_MATCH_HEAD seq_head=%d, match_head=%d, move 1", JOB_PE_IDX, $time, seq_head_ptr_reg, match_head_ptr_reg);
        match_head_ptr_reg <= match_head_ptr_reg + 1;
      end
    end else if (state_reg == S_LAZY_SUMMARY) begin
      if (seq_valid && seq_ready) begin
        $display("[job_pe %0d @ %0t] S_LAZY_SUMMARY seq_ll=%d, seq_ml=%d, seq_offset=%d", JOB_PE_IDX, $time, seq_ll, seq_ml, seq_offset);
        $display("[job_pe %0d @ %0t] S_LAZY_SUMMARY seq_head=%d, match_head=%d, move %d", JOB_PE_IDX, $time, seq_head_ptr_reg, match_head_ptr_reg, move_forward);
        seq_head_ptr_reg <= seq_head_ptr_reg + move_forward;
        match_head_ptr_reg <= seq_head_ptr_reg + move_forward;
      end
    end
  end

  
  // lazy match part logic
  reg [`LAZY_LEN-1:0] lazy_tbl_valid_reg;
  reg [`LAZY_LEN-1:0] lazy_tbl_pending_reg;
  reg [`LAZY_LEN*`JOB_LEN_LOG2-1:0] lazy_tbl_idx_reg;
  reg [`LAZY_LEN*`ADDR_WIDTH-1:0] lazy_tbl_head_addr_reg;
  reg [`LAZY_LEN*`ADDR_WIDTH-1:0] lazy_tbl_history_addr_reg;
  reg [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] lazy_tbl_match_len_reg;
  reg [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] lazy_tbl_offset_reg;
  function automatic [`JOB_LEN_LOG2-1:0] match_head_relative_idx;
    input integer idx;
    begin
      match_head_relative_idx = match_head_ptr_reg + idx[`JOB_LEN_LOG2-1:0];
    end
  endfunction

  always @(posedge clk) begin
    if(state_reg == S_SEEK_MATCH_HEAD && job_tbl_history_valid_reg[match_head_ptr_reg]) begin
      $display("[job_pe %0d @ %0t] S_SEEK_MATCH_HEAD load match_head=%d into lazy tbl", JOB_PE_IDX, $time, match_head_ptr_reg);
      for(integer i = 0; i < `LAZY_LEN; i = i + 1) begin
        if({1'b0, match_head_ptr_reg} + i[`JOB_LEN_LOG2+1-1:0] < `JOB_LEN) begin
          lazy_tbl_valid_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)];
          lazy_tbl_pending_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)] && job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)];
          `VEC_SLICE(lazy_tbl_idx_reg, i, `JOB_LEN_LOG2) <= match_head_relative_idx(i);
          // lazy_table 中的地址已经增加了 META_HISTORY_LEN 偏移
          `VEC_SLICE(lazy_tbl_head_addr_reg, i, `ADDR_WIDTH) <= job_head_addr_reg + `ZERO_EXTEND(match_head_relative_idx(i), `ADDR_WIDTH) + `META_HISTORY_LEN;
          `VEC_SLICE(lazy_tbl_history_addr_reg, i, `ADDR_WIDTH) <= `VEC_SLICE(job_tbl_history_addr_reg, match_head_relative_idx(i), `ADDR_WIDTH);
          `VEC_SLICE(lazy_tbl_offset_reg, i, `SEQ_OFFSET_BITS) <= `VEC_SLICE(job_tbl_offset_reg, match_head_relative_idx(i), `SEQ_OFFSET_BITS);
          // lazy_table 中的 match_len 初始值就是 meta history 的匹配长度
          `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) <= `ZERO_EXTEND(`VEC_SLICE(job_tbl_meta_match_len_reg, match_head_relative_idx(i), `META_MATCH_LEN_WIDTH), `MATCH_LEN_WIDTH);
          $display("[job_pe @ %0t] S_SEEK_MATCH_HEAD lazy_tbl[%0d] valid=%b, pending=%b, head_addr=%d, history_addr=%d, offset=%d, match_len=%d", $time, i, 
          job_tbl_history_valid_reg[match_head_relative_idx(i)], 
          job_tbl_history_valid_reg[match_head_relative_idx(i)] && job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)], 
          job_head_addr_reg + `ZERO_EXTEND(match_head_relative_idx(i), `ADDR_WIDTH) + `META_HISTORY_LEN, 
          `VEC_SLICE(job_tbl_history_addr_reg, match_head_relative_idx(i), `ADDR_WIDTH), 
          `VEC_SLICE(job_tbl_offset_reg, match_head_relative_idx(i), `SEQ_OFFSET_BITS),
          `ZERO_EXTEND(`VEC_SLICE(job_tbl_meta_match_len_reg, match_head_relative_idx(i), `META_MATCH_LEN_WIDTH), `MATCH_LEN_WIDTH),
          );
        end else begin
          lazy_tbl_valid_reg[i] <= 1'b0;
          lazy_tbl_pending_reg[i] <= 1'b0;
          `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) <= '0;
        end
      end
    end else if (state_reg == S_LAZY_MATCH_RESP && match_resp_group_valid) begin
      for(integer i = 0; i < `LAZY_LEN; i = i + 1) begin
        if(lazy_tbl_pending_reg[i]) begin
          $display("[job_pe @ %0t] S_LAZY_MATCH_RESP lazy_tbl[%0d] match_len=%d", $time, i, `VEC_SLICE(match_resp_group_match_len, i, `MATCH_LEN_WIDTH));
          `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) <= `VEC_SLICE(lazy_tbl_match_len_reg, i, `MATCH_LEN_WIDTH) + `VEC_SLICE(match_resp_group_match_len, i, `MATCH_LEN_WIDTH);
        end
      end
    end
  end

  assign match_req_group_valid = (state_reg == S_LAZY_MATCH_REQ) && (|lazy_tbl_pending_reg);
  assign match_req_group_head_addr = lazy_tbl_head_addr_reg;
  assign match_req_group_history_addr = lazy_tbl_history_addr_reg;
  assign match_req_group_strb = lazy_tbl_pending_reg;
  match_req_route_table mrrt(
    .offset(lazy_tbl_offset_reg),
    .route_map(match_req_group_router_map)
  );

  `ifdef JOB_PE_DEBUG_LOG
  always @(posedge clk) begin
    if (match_req_group_valid && match_req_group_ready) begin
      $display("[job_pe %0d @ %0t] seq_head=%d, match_head=%d", JOB_PE_IDX, $time, seq_head_ptr_reg, match_head_ptr_reg);
      for(integer i = 0; i < `LAZY_LEN; i = i + 1) begin
        $display("[job_pe %0d @ %0t] send match req[%0d] head_addr=%d, history_addr=%d, strb=%b, router_map=%0b", JOB_PE_IDX, $time, i, `VEC_SLICE(match_req_group_head_addr, i, `ADDR_WIDTH), `VEC_SLICE(match_req_group_history_addr, i, `ADDR_WIDTH), match_req_group_strb[i], `VEC_SLICE(match_req_group_router_map, i, `NUM_MATCH_REQ_CH));
      end
    end
  end
  `endif 

  assign match_resp_group_ready = state_reg == S_LAZY_MATCH_RESP;

  // lazy summary part logic
  wire lazy_summary_done, lazy_summary_seq_eoj, lazy_summary_overlap_len, lazy_summary_seq_delim, move_to_next_job;
  wire [`JOB_LEN_LOG2-1:0] move_forward;
  wire [`SEQ_LL_BITS-1:0] lazy_summary_seq_ll;
  wire [`SEQ_ML_BITS-1:0] lazy_summary_seq_ml;
  wire [`SEQ_OFFSET_BITS-1:0] lazy_summary_seq_offset;
  wire [`SEQ_ML_BITS-1:0] lazy_summary_seq_overlap_len;
  wire [`JOB_LEN_LOG2-1:0] lazy_summary_seq_head_ptr;
  lazy_summary_pipeline lsp_inst(
    .clk(clk),
    
    .i_match_done((state_reg == S_LAZY_MATCH_REQ & (&(~lazy_tbl_pending_reg))) | state_reg == S_LAZY_SUMMARY ),
    .i_match_head_ptr(match_head_ptr_reg),
    .i_seq_head_ptr(seq_head_ptr_reg),
    .i_delim(job_delim_reg),
    .i_match_valid(lazy_tbl_valid_reg),
    .i_match_len(lazy_tbl_match_len_reg),
    .i_offset(lazy_tbl_offset_reg),

    .o_summary_done(lazy_summary_done),
    .o_seq_head_ptr(lazy_summary_seq_head_ptr),
    .o_summary_ll(lazy_summary_seq_ll),
    .o_summary_ml(lazy_summary_seq_ml),
    .o_summary_offset(lazy_summary_seq_offset),
    .o_summary_eoj(lazy_summary_seq_eoj),
    .o_summary_overlap_len(lazy_summary_seq_overlap_len),
    .o_summary_delim(lazy_summary_seq_delim),
    .o_move_to_next_job(move_to_next_job),
    .o_move_forward(move_forward)
  );

  always @(*) begin
    case(state_reg)
      S_LAZY_SUMMARY: begin
        seq_valid = lazy_summary_done && (lazy_summary_seq_head_ptr == seq_head_ptr_reg);
        seq_ll = lazy_summary_seq_ll;
        seq_ml = lazy_summary_seq_ml;
        seq_offset = lazy_summary_seq_offset;
        seq_eoj = lazy_summary_seq_eoj;
        seq_overlap_len = lazy_summary_seq_overlap_len;
        seq_delim = lazy_summary_seq_delim;
      end
      S_LIT_TAIL: begin
        seq_valid = 1'b1;
        seq_ll = `ZERO_EXTEND((match_head_ptr_reg - seq_head_ptr_reg + 1'b1), `SEQ_LL_BITS);
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
            state_reg <= S_LAZY_MATCH_REQ;
          end else if (match_head_ptr_reg == `JOB_LEN - 1) begin
            state_reg <= S_LIT_TAIL;
          end
        end
        S_LAZY_MATCH_REQ: begin
          if (((|lazy_tbl_pending_reg) && match_req_group_ready)) begin
            state_reg <= S_LAZY_MATCH_RESP;
          end else if (~(|lazy_tbl_pending_reg)) begin
            state_reg <= S_LAZY_SUMMARY;
          end
        end
        S_LAZY_MATCH_RESP: begin
          if (match_resp_group_valid) begin
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
