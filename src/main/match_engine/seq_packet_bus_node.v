`include "parameters.vh"
`include "log.vh"

module seq_packet_bus_node #(
    parameter FIRST = 1'b0,
    parameter SPBN_IDX = 0
) (
    input wire clk,
    input wire rst_n,

    input  wire i_token_valid,
    output wire i_token_ready,

    output wire o_token_valid,
    input  wire o_token_ready,

    input wire i_local_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] i_local_strb,
    input wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] i_local_ll,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] i_local_ml,
    input wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] i_local_offset,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] i_local_overlap,
    input wire [`SEQ_PACKET_SIZE-1:0] i_local_eoj,
    input wire [`SEQ_PACKET_SIZE-1:0] i_local_delim,
    output wire i_local_ready,

    input wire i_prev_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] i_prev_strb,
    input wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] i_prev_ll,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] i_prev_ml,
    input wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] i_prev_offset,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] i_prev_overlap,
    input wire [`SEQ_PACKET_SIZE-1:0] i_prev_eoj,
    input wire [`SEQ_PACKET_SIZE-1:0] i_prev_delim,
    output wire i_prev_ready,

    output wire o_next_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_next_strb,
    output wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] o_next_ll,
    output wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] o_next_ml,
    output wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] o_next_offset,
    output wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] o_next_overlap,
    output wire [`SEQ_PACKET_SIZE-1:0] o_next_eoj,
    output wire [`SEQ_PACKET_SIZE-1:0] o_next_delim,
    input wire o_next_ready
);

`ifdef SEQ_BUS_DEBUG_LOG
  localparam LOG = 1'b1;
`else
  localparam LOG = 1'b0;
`endif

  reg token_hold_reg;
  reg eoj_seen_reg;

  wire next_valid;
  wire [`SEQ_PACKET_SIZE-1:0] next_strb;
  wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] next_ll;
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] next_ml;
  wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] next_offset;
  wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] next_overlap;
  wire [`SEQ_PACKET_SIZE-1:0] next_eoj;
  wire [`SEQ_PACKET_SIZE-1:0] next_delim;
  wire next_ready;

  pingpong_reg #(
      .W($bits({next_strb, next_ll, next_ml, next_offset, next_overlap, next_eoj, next_delim}))
  ) spbn_buf (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(next_valid),
      .input_payload({
        next_strb, next_ll, next_ml, next_offset, next_overlap, next_eoj, next_delim
      }),
      .input_ready(next_ready),
      .output_valid(o_next_valid),
      .output_payload({
        o_next_strb, o_next_ll, o_next_ml, o_next_offset, o_next_overlap, o_next_eoj, o_next_delim
      }),
      .output_ready(o_next_ready)
  );

  always @(posedge clk) begin
    if (!rst_n) begin
      eoj_seen_reg   <= 1'b0;
      token_hold_reg <= FIRST;
    end else begin
      if (!token_hold_reg) begin
        token_hold_reg <= i_token_valid;
        if (LOG) begin
          if (i_token_valid) begin
            $display("[seq_packet_bus_node %0d @ %0t] token acquired", SPBN_IDX, $time);
          end
        end
      end else begin
        // 当前模块持有 token
        if (!eoj_seen_reg) begin
          // 还没收到 eoj
          if (next_valid && next_ready && |next_eoj) begin
            // 收到 eoj，则 seen 置 1
            eoj_seen_reg <= 1'b1;
            if (LOG) $display("[seq_packet_bus_node %0d @ %0t] get eoj", SPBN_IDX, $time);
          end
        end else begin
          if (o_token_ready) begin
            // 确保 token 传递成功
            eoj_seen_reg   <= 1'b0;
            token_hold_reg <= 1'b0;
            if (LOG) $display("[seq_packet_bus_node %0d @ %0t] token released", SPBN_IDX, $time);
          end
        end
      end
    end
  end

`ifdef SEQ_BUS_DEBUG_LOG
  always @(posedge clk) begin
    for (integer i = 0; i < `SEQ_PACKET_SIZE; i = i + 1) begin
      if (i_local_valid && i_local_ready) begin
        $display(
            "[seq_packet_bus_node %0d @ %0t] send seq on bus [%0d] strb=%0h, ll=%0d, ml=%0d, offset=%0d, overlap=%0d, eoj=%0d, delim=%0d",
            SPBN_IDX, $time, i, i_local_strb[i], i_local_ll[i*`SEQ_LL_BITS+:`SEQ_LL_BITS],
            i_local_ml[i*`SEQ_ML_BITS+:`SEQ_ML_BITS],
            i_local_offset[i*`SEQ_OFFSET_BITS+:`SEQ_OFFSET_BITS],
            i_local_overlap[i*`SEQ_ML_BITS+:`SEQ_ML_BITS], i_local_eoj[i], i_local_delim[i]);
      end
    end
  end
`endif

  // 当前节点持有 token 且已经收到 eoj 时，将 token 传递给下一个节点
  assign o_token_valid = token_hold_reg && eoj_seen_reg;
  // 只有不持有 token 时才能接收 token
  assign i_token_ready = !token_hold_reg;

  // 持有 token 且没有 eoj 时，将 i_local 传递给 o_next
  // 否则，将 i_prev 传递给 o_next
  wire sel_local = token_hold_reg && !eoj_seen_reg;

  assign next_valid    = sel_local ? i_local_valid : i_prev_valid;
  assign i_local_ready = sel_local ? next_ready : 1'b0;
  assign i_prev_ready  = sel_local ? 1'b0 : next_ready;

  assign next_strb     = sel_local ? i_local_strb : i_prev_strb;
  assign next_ll       = sel_local ? i_local_ll : i_prev_ll;
  assign next_ml       = sel_local ? i_local_ml : i_prev_ml;
  assign next_offset   = sel_local ? i_local_offset : i_prev_offset;
  assign next_overlap  = sel_local ? i_local_overlap : i_prev_overlap;
  assign next_eoj      = sel_local ? i_local_eoj : i_prev_eoj;
  assign next_delim    = sel_local ? i_local_delim : i_prev_delim;


endmodule
