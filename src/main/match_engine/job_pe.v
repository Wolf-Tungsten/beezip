`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module job_pe #(
    parameter MATCH_PE_IDX = 0
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

    // output seq port
    output wire seq_valid,
    output wire [`SEQ_LL_BITS-1:0] seq_ll,
    output wire [`SEQ_ML_BITS-1:0] seq_ml,
    output wire [`SEQ_OFFSET_BITS-1:0] seq_offset,
    output wire seq_eoj,
    output wire [`SEQ_ML_BITS-1:0] seq_overlap_len,
    output wire seq_delim,
    input wire seq_ready,

    // match request port
    output wire match_req_valid,
    output wire [`ADDR_WIDTH-1:0] match_req_head_addr,
    output reg [`ADDR_WIDTH-1:0] match_req_history_addr,
    output reg [7:0] match_req_tag,
    input wire match_req_ready,

    // match resp port
    input wire match_resp_valid,
    input wire [`MATCH_LEN_WIDTH-1:0] match_resp_len,
    input wire [7:0] match_resp_tag,
    output wire match_resp_ready
);

  reg [`ADDR_WIDTH-1:0] job_head_addr_reg;
  reg job_delim_reg;
  reg [`JOB_LEN-1:0] job_tbl_history_valid_reg;
  reg [`JOB_LEN*`ADDR_WIDTH-1:0] job_tbl_history_addr_reg;
  reg [`JOB_LEN*`META_MATCH_LEN_WIDTH-1:0] job_tbl_meta_match_len_reg;
  reg [`JOB_LEN-1:0] job_tbl_meta_match_can_ext_reg;


  // state machine
  localparam S_LOAD = 3'b001;
  localparam S_SEEK_MATCH_HEAD = 3'b010;
  localparam S_LAZY_MATCH = 3'b011;
  localparam S_LAZY_SUMMARY = 3'b100;
  localparam S_LIT_TAIL = 3'b101;
  localparam S_SEND_SEQ = 3'b110;
  reg [2:0] state_reg;

  // load part logic
  localparam LOAD_COUNT_LOG2 = `JOB_LEN_LOG2 - `HASH_ISSUE_WIDTH_LOG2;
  localparam MAX_LOAD_COUNT = 2 ** LOAD_COUNT_LOG2;
  reg [LOAD_COUNT_LOG2-1:0] load_counter_reg;
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
          if (i[LOAD_COUNT_LOG2-1:0] == load_counter_reg) begin
            job_tbl_history_valid_reg[i * `HASH_ISSUE_WIDTH +: `HASH_ISSUE_WIDTH] <= hash_batch_history_valid;
            job_tbl_history_addr_reg[i * `ADDR_WIDTH * `HASH_ISSUE_WIDTH +: `ADDR_WIDTH * `HASH_ISSUE_WIDTH] <= hash_batch_history_addr;
            job_tbl_meta_match_len_reg[i * `META_MATCH_LEN_WIDTH * `HASH_ISSUE_WIDTH +: `META_MATCH_LEN_WIDTH * `HASH_ISSUE_WIDTH] <= hash_batch_meta_match_len;
            job_tbl_meta_match_can_ext_reg[i * `HASH_ISSUE_WIDTH +: `HASH_ISSUE_WIDTH] <= hash_batch_meta_match_can_ext;
          end
        end
        load_counter_reg <= load_counter_reg + 1;
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
      if((match_head_ptr_reg < `JOB_LEN - 8) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 8] == 8'h00)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 4;
      end else if ((match_head_ptr_reg < `JOB_LEN - 4) && (job_tbl_history_valid_reg[match_head_ptr_reg +: 4] == 4'h0)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 2;
      end else if ((match_head_ptr_reg < `JOB_LEN - 1) && (job_tbl_history_valid_reg[match_head_ptr_reg] == 1'b0)) begin
        match_head_ptr_reg <= match_head_ptr_reg + 1;
      end
    end
  end

  // lazy match part logic
  localparam LAZY_MATCH_LEN_LOG2 = $clog2(`LAZY_MATCH_LEN);
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_valid_reg;
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_pending_reg;
  reg [`LAZY_MATCH_LEN-1:0] lazy_tbl_done_reg;
  reg [`LAZY_MATCH_LEN*`JOB_LEN_LOG2-1:0] lazy_tbl_idx_reg;
  reg [`LAZY_MATCH_LEN*`ADDR_WIDTH-1:0] lazy_tbl_head_addr_reg;
  reg [`LAZY_MATCH_LEN*`ADDR_WIDTH-1:0] lazy_tbl_history_addr_reg;
  reg [`LAZY_MATCH_LEN*`MATCH_LEN_WIDTH-1:0] lazy_tbl_match_len_reg;

  function automatic [`JOB_LEN_LOG2-1:0] match_head_relative_idx;
    input integer idx;
    begin
      match_head_relative_idx = match_head_ptr_reg + idx[`JOB_LEN_LOG2-1:0];
    end
  endfunction
  
  always @(posedge clk) begin
    if(state_reg == S_SEEK_MATCH_HEAD && job_tbl_history_valid_reg[match_head_ptr_reg]) begin
      for(integer i = 0; i < `LAZY_MATCH_LEN; i = i + 1) begin
        if({1'b0, match_head_ptr_reg} + i[`JOB_LEN_LOG2+1-1:0] < `JOB_LEN) begin
          lazy_tbl_valid_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)];
          lazy_tbl_pending_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)] && job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)];
          lazy_tbl_done_reg[i] <= job_tbl_history_valid_reg[match_head_relative_idx(i)] ? (!job_tbl_meta_match_can_ext_reg[match_head_relative_idx(i)]) : 1'b1;
          lazy_tbl_idx_reg[i * `JOB_LEN_LOG2 +: `JOB_LEN_LOG2] <= match_head_relative_idx(i);
          // TODO: lzc is hungry now
        end else begin
          lazy_tbl_valid_reg[i] <= 1'b0;
          lazy_tbl_pending_reg[i] <= 1'b0;
          lazy_tbl_done_reg[i] <= 1'b1;
          lazy_tbl_match_len_reg[i * `MATCH_LEN_WIDTH +: `MATCH_LEN_WIDTH] <= '0;
        end
      end
    end
  end


  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg <= S_LOAD;
    end else begin
      // 状态机的转换
      case (state_reg)
        S_LOAD: begin
          if(hash_batch_valid && (load_counter_reg == (MAX_LOAD_COUNT[LOAD_COUNT_LOG2-1:0]-1))) begin
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
          if (seq_ready) begin
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
