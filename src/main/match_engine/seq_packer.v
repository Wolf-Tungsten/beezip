`include "parameters.vh"

module seq_packer (
    input wire clk,
    input wire rst_n,

    input wire i_valid,
    input wire [`SEQ_LL_BITS-1:0] i_ll,
    input wire [`SEQ_ML_BITS-1:0] i_ml,
    input wire [`SEQ_OFFSET_BITS-1:0] i_offset,
    input wire i_eoj,
    input wire [`SEQ_ML_BITS-1:0] i_overlap_len,
    input wire i_delim,
    output wire i_ready,

    output wire o_valid,
    output wire [`SEQ_PACKET_SIZE-1:0] o_mask,
    output wire [`SEQ_LL_BITS*`SEQ_PACKET_SIZE-1:0] o_ll,
    output wire [`SEQ_ML_BITS*`SEQ_PACKET_SIZE-1:0] o_ml,
    output wire [`SEQ_OFFSET_BITS*`SEQ_PACKET_SIZE-1:0] o_offset,
    output wire [`SEQ_ML_BITS-1:0] o_overlap,
    output wire o_eoj,
    output wire o_delim,
    input wire o_ready
);

  wire fifo_o_valid;
  wire [`SEQ_LL_BITS-1:0] fifo_o_ll;
  wire [`SEQ_ML_BITS-1:0] fifo_o_ml;
  wire [`SEQ_OFFSET_BITS-1:0] fifo_o_offset;
  wire fifo_o_eoj;
  wire [`SEQ_ML_BITS-1:0] fifo_o_overlap_len;
  wire fifo_o_delim;
  wire fifo_o_ready;

  fifo #(
      .W($bits({i_ll, i_ml, i_offset, i_eoj, i_overlap_len, i_delim})),
      .DEPTH(`SEQ_FIFO_DEPTH)
  ) seq_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(i_valid),
      .input_payload({i_ll, i_ml, i_offset, i_eoj, i_overlap_len, i_delim}),
      .input_ready(i_ready),
      .output_valid(fifo_o_valid),
      .output_payload({
        fifo_o_ll, fifo_o_ml, fifo_o_offset, fifo_o_eoj, fifo_o_overlap_len, fifo_o_delim
      }),
      .output_ready(fifo_o_ready)
  );

  reg [`SEQ_PACKET_SIZE-1:0] mask_reg;
  reg [`SEQ_LL_BITS-1:0] ll_reg[0:`SEQ_PACKET_SIZE-1];
  reg [`SEQ_ML_BITS-1:0] ml_reg[0:`SEQ_PACKET_SIZE-1];
  reg [`SEQ_OFFSET_BITS-1:0] offset_reg[0:`SEQ_PACKET_SIZE-1];
  reg [`SEQ_ML_BITS-1:0] overlap_reg;
  reg eoj_reg;
  reg delim_reg;

  localparam S_LOAD = 1'b0, S_FLUSH = 1'b1;
  reg state_reg;
  reg [$clog2(`SEQ_PACKET_SIZE)-1:0] idx_reg;
  localparam IDX_BAR = (`SEQ_PACKET_SIZE - 1);
  always @(posedge clk) begin
    if (!rst_n) begin
      state_reg <= S_LOAD;
      idx_reg   <= 0;
      mask_reg  <= '0;
      eoj_reg   <= 0;
      delim_reg <= 0;
    end else begin
      case (state_reg)
        S_LOAD: begin
          if (fifo_o_valid) begin
            mask_reg[idx_reg] <= 1'b1;
            ll_reg[idx_reg] <= fifo_o_ll;
            ml_reg[idx_reg] <= fifo_o_ml;
            offset_reg[idx_reg] <= fifo_o_offset;
            overlap_reg <= fifo_o_overlap_len;
            eoj_reg <= fifo_o_eoj;
            delim_reg <= fifo_o_delim;
            if (idx_reg == IDX_BAR[$bits(idx_reg)-1:0] || fifo_o_eoj) begin
              state_reg <= S_FLUSH;
            end else begin
              idx_reg <= idx_reg + 1;
            end
          end
        end
        S_FLUSH: begin
          if (o_ready) begin
            state_reg <= S_LOAD;
            idx_reg   <= 0;
            mask_reg  <= '0;
            eoj_reg   <= 1'b0;
            delim_reg <= 1'b0;
          end
        end
      endcase
    end
  end
  
  assign fifo_o_ready = (state_reg == S_LOAD);
  assign o_valid = (state_reg == S_FLUSH);
  genvar i;
  generate
    for (i = 0; i < `SEQ_PACKET_SIZE; i = i + 1) begin
      assign o_mask[i] = mask_reg[i];
      assign o_ll[i*`SEQ_LL_BITS+:`SEQ_LL_BITS] = ll_reg[i];
      assign o_ml[i*`SEQ_ML_BITS+:`SEQ_ML_BITS] = ml_reg[i];
      assign o_offset[i*`SEQ_OFFSET_BITS+:`SEQ_OFFSET_BITS] = offset_reg[i];
    end
  endgenerate
  assign o_overlap = overlap_reg;
  assign o_eoj = eoj_reg;
  assign o_delim = delim_reg;

endmodule
