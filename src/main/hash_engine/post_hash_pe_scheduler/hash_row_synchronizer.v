`include "parameters.vh"

/**

状态寄存器
1. counter
2. row_valid

数据寄存器
1. history_valid_vec
2. history_addr_vec

*/

module hash_row_synchronizer (
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num,

    input wire input_valid,
    input wire [`ADDR_WIDTH-1:0] input_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] input_row_valid,
    input wire [`HASH_ISSUE_WIDTH-1:0] input_history_valid,
    input wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] input_history_addr,
    input wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] input_meta_match_len,
    input wire [`HASH_ISSUE_WIDTH-1:0] input_meta_match_can_ext,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
    input wire input_delim,
    output reg input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] output_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire output_delim,
    input wire output_ready
);

  localparam S_RECV = 0;
  localparam S_FLUSH = 1;

  reg [1:0] state_reg_d, next_state;
  wire [1:0] state_reg_q;
  reg state_reg_en;
  dff #(
      .W(2),
      .RST(1),
      .EN(1),
      .RST_V(2'b01)
  ) state_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(state_reg_en),
      .d(state_reg_d),
      .q(state_reg_q)
  );

  reg [`HASH_ISSUE_WIDTH_LOG2+1-1:0] trans_cnt_reg_d;
  wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] trans_cnt_reg_q;
  reg trans_cnt_reg_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH_LOG2 + 1),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) trans_cnt_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(trans_cnt_reg_en),
      .d(trans_cnt_reg_d),
      .q(trans_cnt_reg_q)
  );

  reg [`HASH_ISSUE_WIDTH-1:0] row_valid_reg_d;
  wire [`HASH_ISSUE_WIDTH-1:0] row_valid_reg_q;
  reg row_valid_reg_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) row_valid_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(row_valid_reg_en),
      .d(row_valid_reg_d),
      .q(row_valid_reg_q)
  );

  reg [`HASH_ISSUE_WIDTH-1:0] history_valid_reg_d;
  wire [`HASH_ISSUE_WIDTH-1:0] history_valid_reg_q;
  reg history_valid_reg_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) history_valid_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(history_valid_reg_en),
      .d(history_valid_reg_d),
      .q(history_valid_reg_q)
  );

  reg [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] history_addr_reg_d;
  wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] history_addr_reg_q;
  reg history_addr_reg_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH * `ADDR_WIDTH),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) history_addr_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(history_addr_reg_en),
      .d(history_addr_reg_d),
      .q(history_addr_reg_q)
  );

  reg [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] meta_match_len_d;
  wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] meta_match_len_q;
  reg meta_match_len_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH * `META_MATCH_LEN_WIDTH),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) meta_match_len_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(meta_match_len_en),
      .d(meta_match_len_d),
      .q(meta_match_len_q)
  );

  reg [`HASH_ISSUE_WIDTH-1:0] meta_match_can_ext_d;
  wire [`HASH_ISSUE_WIDTH-1:0] meta_match_can_ext_q;
  reg meta_match_can_ext_en;
  dff #(
      .W(`HASH_ISSUE_WIDTH),
      .RST(1),
      .EN(1),
      .RST_V(0)
  ) meta_match_can_ext_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(meta_match_can_ext_en),
      .d(meta_match_can_ext_d),
      .q(meta_match_can_ext_q)
  );

  reg [`ADDR_WIDTH+1+`HASH_ISSUE_WIDTH*8-1:0] head_addr_data_delim_reg_d;
  wire [`ADDR_WIDTH+1+`HASH_ISSUE_WIDTH*8-1:0] head_addr_data_delim_reg_q;
  reg head_addr_data_delim_reg_en;
  dff #(
      .W  (`ADDR_WIDTH + 1 + `HASH_ISSUE_WIDTH * 8),
      .RST(1),
      .EN (1)
  ) head_addr_data_delim_reg (
      .clk(clk),
      .rst_n(rst_n),
      .en(head_addr_data_delim_reg_en),
      .d(head_addr_data_delim_reg_d),
      .q(head_addr_data_delim_reg_q)
  );

  reg stage_reg_valid;
  reg [`ADDR_WIDTH-1:0] stage_reg_head_addr;
  reg [`HASH_ISSUE_WIDTH-1:0] stage_reg_row_valid;
  reg [`HASH_ISSUE_WIDTH-1:0] stage_reg_history_valid;
  reg [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] stage_reg_history_addr;
  reg [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] stage_reg_meta_match_len;
  reg [`HASH_ISSUE_WIDTH-1:0] stage_reg_meta_match_can_ext;
  reg [`HASH_ISSUE_WIDTH*8-1:0] stage_reg_data;
  reg stage_reg_delim;
  wire stage_reg_ready;

  // intermediate logics
  reg [`HASH_ISSUE_WIDTH-1:0] combined_row_valid;
  reg [`HASH_ISSUE_WIDTH-1:0] combined_history_valid;
  reg [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] combined_history_addr;
  reg [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] combined_meta_match_len;
  reg [`HASH_ISSUE_WIDTH-1:0] combined_meta_match_can_ext;
  reg need_flush;
  reg [`HASH_ISSUE_WIDTH-1:0] combined_real_row_valid, flush_real_row_valid;

  always @(*) begin : hrs_fsm_logic
    integer i;
    for (i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
      combined_row_valid[i] = row_valid_reg_q[i] | input_row_valid[i];
      combined_history_valid[i] = history_valid_reg_q[i] | (input_row_valid[i] & input_history_valid[i]);
      combined_history_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH] = history_addr_reg_q[i*`ADDR_WIDTH +: `ADDR_WIDTH] | ({(`ADDR_WIDTH){input_row_valid[i]}} & input_history_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]);
      combined_meta_match_len[i*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] = meta_match_len_q[i*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] | ({(`META_MATCH_LEN_WIDTH){input_row_valid[i]}} & input_meta_match_len[i*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH]);
      combined_meta_match_can_ext[i] = meta_match_can_ext_q[i] | (input_row_valid[i] & input_meta_match_can_ext[i]);
      combined_real_row_valid[i] = combined_history_valid[i];
      flush_real_row_valid[i] = history_valid_reg_q[i];
    end
    need_flush = (trans_cnt_reg_q + 1 >= cfg_max_queued_req_num) | (&combined_row_valid);
    // avoid latch, give default value
    next_state = 2'b0;
    state_reg_en = 1'b0;
    row_valid_reg_d = combined_row_valid;
    row_valid_reg_en = 1'b0;
    trans_cnt_reg_d = trans_cnt_reg_q + 1'b1;
    trans_cnt_reg_en = 1'b0;
    history_valid_reg_d = combined_history_valid;
    history_valid_reg_en = 1'b0;
    history_addr_reg_d = combined_history_addr;
    history_addr_reg_en = 1'b0;
    meta_match_len_d = combined_meta_match_len;
    meta_match_len_en = 1'b0;
    meta_match_can_ext_d = combined_meta_match_can_ext;
    meta_match_can_ext_en = 1'b0;
    head_addr_data_delim_reg_d = {input_head_addr, input_data, input_delim};
    head_addr_data_delim_reg_en = 1'b0;
    stage_reg_valid = 1'b0;
    stage_reg_head_addr = input_head_addr;
    stage_reg_row_valid = combined_real_row_valid;
    stage_reg_history_valid = combined_history_valid;
    stage_reg_history_addr = combined_history_addr;
    stage_reg_meta_match_len = combined_meta_match_len;
    stage_reg_meta_match_can_ext = combined_meta_match_can_ext;
    stage_reg_data = input_data;
    stage_reg_delim = input_delim;
    input_ready = 1'b0;
    // state machine
    case (1'b1)
      state_reg_q[S_RECV]: begin
        input_ready = 1'b1;
        if (input_valid) begin
          if (need_flush) begin
            stage_reg_valid = 1'b1;
            if (stage_reg_ready) begin
              // 握手成功，清空 buffer 和计数器
              row_valid_reg_d = '0;
              row_valid_reg_en = 1'b1;
              trans_cnt_reg_d = '0;
              trans_cnt_reg_en = 1'b1;
              history_valid_reg_d = '0;
              history_valid_reg_en = 1'b1;
              history_addr_reg_d = '0;
              history_addr_reg_en = 1'b1;
              meta_match_len_d = '0;
              meta_match_len_en = 1'b1;
              meta_match_can_ext_d = '0;
              meta_match_can_ext_en = 1'b1;
            end else begin
              // 握手不成功，保存当前请求，切换到 flush 状态
              row_valid_reg_en = 1'b1;
              trans_cnt_reg_en = 1'b1;
              history_valid_reg_en = 1'b1;
              history_addr_reg_en = 1'b1;
              meta_match_len_en = 1'b1;
              meta_match_can_ext_en = 1'b1;
              head_addr_data_delim_reg_en = 1'b1;
              next_state[S_FLUSH] = 1'b1;
              state_reg_en = 1'b1;
            end
          end else begin
            // 保存当前请求到 buffer 中
            row_valid_reg_en = 1'b1;
            history_valid_reg_en = 1'b1;
            history_addr_reg_en = 1'b1;
            meta_match_len_en = 1'b1;
            meta_match_can_ext_en = 1'b1;
            trans_cnt_reg_en = 1'b1;
            head_addr_data_delim_reg_en = 1'b1;
          end
        end
      end
      state_reg_q[S_FLUSH]: begin
        // 从 buffer 输出
        stage_reg_valid = 1'b1;
        {stage_reg_head_addr, stage_reg_data, stage_reg_delim} = head_addr_data_delim_reg_q;
        stage_reg_row_valid = flush_real_row_valid;
        stage_reg_history_valid = history_valid_reg_q;
        stage_reg_history_addr = history_addr_reg_q;
        stage_reg_meta_match_can_ext = meta_match_can_ext_q;
        stage_reg_meta_match_len = meta_match_len_q;
        
        if (stage_reg_ready) begin
          // 清空 buffer 和计数器，返回 recv 状态
          row_valid_reg_d = '0;
          row_valid_reg_en = 1'b1;
          trans_cnt_reg_d = '0;
          trans_cnt_reg_en = 1'b1;
          history_valid_reg_d = '0;
          history_valid_reg_en = 1'b1;
          history_addr_reg_d = '0;
          history_addr_reg_en = 1'b1;
          meta_match_len_d = '0;
          meta_match_len_en = 1'b1;
          meta_match_can_ext_d = '0;
          meta_match_can_ext_en = 1'b1;
          next_state[S_RECV] = 1'b1;
          state_reg_en = 1'b1;
        end
      end
      default: begin
        next_state[S_RECV] = 1'b1;
        state_reg_en = 1'b1;
      end
    endcase
    state_reg_d = next_state;
  end

  always @(posedge clk) begin
    if (~rst_n) begin
    end else begin
      if (stage_reg_valid & stage_reg_ready) begin
        integer i;
        for (i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
          if (stage_reg_history_valid[i]) begin
            $display(
                "[hash_row_synchronizer @ %0t] output head_addr=%0d, history_valid=%0d, history_addr=%0d, meta_match_len=%0d, meta_match_can_ext=%0d, delim=%0d, data=%0d",
                $time, stage_reg_head_addr + i[`ADDR_WIDTH-1:0], stage_reg_history_valid[i],
                stage_reg_history_addr[i*`ADDR_WIDTH+:`ADDR_WIDTH],
                stage_reg_meta_match_len[i*`META_MATCH_LEN_WIDTH+:`META_MATCH_LEN_WIDTH],
                stage_reg_meta_match_can_ext[i], stage_reg_delim, stage_reg_data[i*8+:8]);
          end
        end
      end
    end
  end

  forward_reg #(
      .W(`ADDR_WIDTH+`HASH_ISSUE_WIDTH*((1+`ADDR_WIDTH+`META_MATCH_LEN_WIDTH+1))+1+`HASH_ISSUE_WIDTH*8)
  ) stage_reg (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(stage_reg_valid),
      .input_payload({
        stage_reg_head_addr,
        //stage_reg_row_valid, 
        stage_reg_history_valid,
        stage_reg_history_addr,
        stage_reg_meta_match_len,
        stage_reg_meta_match_can_ext,
        stage_reg_data,
        stage_reg_delim
      }),
      .input_ready(stage_reg_ready),

      .output_valid(output_valid),
      .output_payload({
        output_head_addr,
        output_history_valid,
        output_history_addr,
        output_meta_match_len,
        output_meta_match_can_ext,
        output_data,
        output_delim
      }),
      .output_ready(output_ready)
  );
endmodule
