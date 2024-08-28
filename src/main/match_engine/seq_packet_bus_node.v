`include "parameters.vh"

module seq_packet_bus_node #(
    parameter FIRST = 1'b0
) (
    input wire clk,
    input wire rst_n,

    input  wire i_token_valid,
    output wire i_token_ready,

    output wire o_token_valid,
    input  wire o_token_ready,

    input wire local_i_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] local_i_mask,
    input wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] local_i_ll,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] local_i_ml,
    input wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] local_i_offset,
    input wire [`SEQ_ML_BITS-1:0] local_i_overlap,
    input wire local_i_eoj,
    input wire local_i_delim,
    output wire local_i_ready,

    input wire bus_i_valid,
    input wire [`SEQ_PACKET_SIZE-1:0] bus_i_mask,
    input wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] bus_i_ll,
    input wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] bus_i_ml,
    input wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] bus_i_offset,
    input wire [`SEQ_ML_BITS-1:0] bus_i_overlap,
    input wire bus_i_eoj,
    input wire bus_i_delim,
    output wire bus_i_ready,

    output wire bus_o_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] bus_o_mask,
    output wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] bus_o_ll,
    output wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] bus_o_ml,
    output wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] bus_o_offset,
    output wire [`SEQ_ML_BITS-1:0] bus_o_overlap,
    output wire bus_o_eoj,
    output wire bus_o_delim,
    input wire bus_o_ready
);

  reg token_hold_reg;
  reg eoj_seen_reg;

  always @(posedge clk) begin
    if (!rst_n) begin
      eoj_seen_reg   <= 1'b0;
      token_hold_reg <= FIRST;
    end else begin
      if (!token_hold_reg) begin
        token_hold_reg <= i_token_valid;
      end else begin
        // 当前模块持有 token
        if (!eoj_seen_reg) begin
          // 还没收到 eoj
          if (bus_o_valid && bus_o_ready && bus_o_eoj) begin
            // 收到 eoj，则 seen 置 1
            eoj_seen_reg <= 1'b1;
          end
        end else begin
          if (o_token_ready) begin
            // 确保 token 传递成功
            eoj_seen_reg   <= 1'b0;
            token_hold_reg <= 1'b0;
          end
        end
      end
    end
  end

  // 当前节点持有 token 且已经收到 eoj 时，将 token 传递给下一个节点
  assign o_token_valid = token_hold_reg && eoj_seen_reg;
  // 只有不持有 token 时才能接收 token
  assign i_token_ready = !token_hold_reg;

  // 持有 token 且没有 eoj 时，将 local_i 传递给 bus_o
  // 否则，将 bus_i 传递给 bus_o
  wire sel_local = token_hold_reg && !eoj_seen_reg;

  assign bus_o_valid   = sel_local ? local_i_valid : bus_i_valid;
  assign local_i_ready = sel_local ? bus_o_ready : 1'b0;
  assign bus_i_ready   = sel_local ? 1'b0 : bus_o_ready;

  assign bus_o_mask    = sel_local ? local_i_mask : bus_i_mask;
  assign bus_o_ll      = sel_local ? local_i_ll : bus_i_ll;
  assign bus_o_ml      = sel_local ? local_i_ml : bus_i_ml;
  assign bus_o_offset  = sel_local ? local_i_offset : bus_i_offset;
  assign bus_o_overlap = sel_local ? local_i_overlap : bus_i_overlap;
  assign bus_o_eoj     = sel_local ? local_i_eoj : bus_i_eoj;
  assign bus_o_delim   = sel_local ? local_i_delim : bus_i_delim;


endmodule
