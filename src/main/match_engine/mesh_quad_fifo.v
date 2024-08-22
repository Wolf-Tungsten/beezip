module mesh_quad_fifo #(
    parameter W = 8,
    X_SIZE = 4,
    Y_SIZE = 4,
    BUFFER_DEPTH = 4
) (
  input wire clk,
  input wire rst_n,
  input wire i_valid_0,
  i_valid_1,
  i_valid_2,
  i_valid_3,
  input wire [$clog2(X_SIZE)-1:0] i_dst_x_0,
  i_dst_x_1,
  i_dst_x_2,
  i_dst_x_3,
  input wire [$clog2(Y_SIZE)-1:0] i_dst_y_0,
  i_dst_y_1,
  i_dst_y_2,
  i_dst_y_3,
  input wire [W-1:0] i_payload_0,
  i_payload_1,
  i_payload_2,
  i_payload_3,
  output wire i_ready,
  output reg o_valid,
  output reg [$clog2(X_SIZE)-1:0] o_dst_x,
  output reg [$clog2(Y_SIZE)-1:0] o_dst_y,
  output reg [W-1:0] o_payload,
  input wire o_ready
);

  localparam FIFO_W = $bits(i_valid_0) + $bits(i_dst_x_0) + $bits(i_dst_y_0) + $bits(i_payload_0);
  wire fifo_i_valid = i_valid_0 | i_valid_1 | i_valid_2 | i_valid_3;
  wire [FIFO_W*4-1:0] fifo_i_payload = {
    i_payload_3,
    i_dst_y_3,
    i_dst_x_3,
    i_valid_3,
    i_payload_2,
    i_dst_y_2,
    i_dst_x_2,
    i_valid_2,
    i_payload_1,
    i_dst_y_1,
    i_dst_x_1,
    i_valid_1,
    i_payload_0,
    i_dst_y_0,
    i_dst_x_0,
    i_valid_0
  };
  wire fifo_o_valid;
  reg fifo_o_ready;
  wire [FIFO_W*4-1:0] fifo_o_payload;

  fifo #(
      .DEPTH(BUFFER_DEPTH),
      .W(FIFO_W * 4)
  ) fifo_quad_inst (
      .clk(clk),
      .rst_n(rst_n),
      .input_valid(fifo_i_valid),
      .input_payload(fifo_i_payload),
      .input_ready(i_ready),
      .output_valid(fifo_o_valid),
      .output_payload(fifo_o_payload),
      .output_ready(fifo_o_ready)
  );

  // 将fifo_o_payload拆分成4个部分
  wire fifo_o_valid_0, fifo_o_valid_1, fifo_o_valid_2, fifo_o_valid_3;
  wire [$clog2(X_SIZE)-1:0] fifo_o_dst_x_0, fifo_o_dst_x_1, fifo_o_dst_x_2, fifo_o_dst_x_3;
  wire [$clog2(Y_SIZE)-1:0] fifo_o_dst_y_0, fifo_o_dst_y_1, fifo_o_dst_y_2, fifo_o_dst_y_3;
  wire [W-1:0] fifo_o_payload_0, fifo_o_payload_1, fifo_o_payload_2, fifo_o_payload_3;
  assign {fifo_o_payload_3, fifo_o_dst_y_3, fifo_o_dst_x_3, fifo_o_valid_3,
            fifo_o_payload_2, fifo_o_dst_y_2, fifo_o_dst_x_2, fifo_o_valid_2,
            fifo_o_payload_1, fifo_o_dst_y_1, fifo_o_dst_x_1, fifo_o_valid_1,
            fifo_o_payload_0, fifo_o_dst_y_0, fifo_o_dst_x_0, fifo_o_valid_0} = fifo_o_payload;


  localparam S0 = 1'b0;
  localparam S1 = 1'b1;
  reg state_reg;
  reg [3:0] state_mask_reg;

  wire [3:0] fifo_o_mask = {fifo_o_valid_3, fifo_o_valid_2, fifo_o_valid_1, fifo_o_valid_0};
  wire [3:0] sel_mask = (state_reg == S0) ? fifo_o_mask : state_mask_reg;
  reg [3:0] sel_mask_oh;

  // 输出状态机
  always @(posedge clk) begin
    if (~rst_n) begin
      state_reg <= S0;
    end else begin
      case (state_reg)
        S0: begin
          if (fifo_o_valid && o_ready) begin
            if (|(fifo_o_mask & ~sel_mask_oh)) begin
              // 不止一个输出有效
              state_reg <= S1;
              state_mask_reg <= fifo_o_mask & ~sel_mask_oh;
            end
          end
        end
        S1: begin
          if (o_ready) begin
            if (|(state_mask_reg & ~sel_mask_oh)) begin
              // 还有输出没有被选中
              state_mask_reg <= state_mask_reg & ~sel_mask_oh;
            end else begin
              state_reg <= S0;
            end
          end
        end
      endcase
    end
  end

  // 处理握手信号
  always @(*) begin
    o_valid = 1'b0;
    fifo_o_ready = 1'b0;
    if (state_reg == S0) begin
      o_valid = fifo_o_valid;
      if (|(fifo_o_mask & ~sel_mask_oh)) begin
        // 不止当前一个输出
        fifo_o_ready = 1'b0;
      end else begin
        // 只有一个输出
        fifo_o_ready = o_ready;
      end
    end else if (state_reg == S1) begin
      o_valid = 1'b1;
      if (|(state_mask_reg & ~sel_mask_oh)) begin
        fifo_o_ready = 1'b0;
      end else begin
        fifo_o_ready = o_ready;
      end
    end
  end

  // 处理输出信号
  always @(*) begin
    casez (sel_mask)
      4'b???1: begin
        o_dst_x = fifo_o_dst_x_0;
        o_dst_y = fifo_o_dst_y_0;
        o_payload = fifo_o_payload_0;
        sel_mask_oh = 4'b0001;
      end
      4'b??10: begin
        o_dst_x = fifo_o_dst_x_1;
        o_dst_y = fifo_o_dst_y_1;
        o_payload = fifo_o_payload_1;
        sel_mask_oh = 4'b0010;
      end
      4'b?100: begin
        o_dst_x = fifo_o_dst_x_2;
        o_dst_y = fifo_o_dst_y_2;
        o_payload = fifo_o_payload_2;
        sel_mask_oh = 4'b0100;
      end
      4'b1000: begin
        o_dst_x = fifo_o_dst_x_3;
        o_dst_y = fifo_o_dst_y_3;
        o_payload = fifo_o_payload_3;
        sel_mask_oh = 4'b1000;
      end
      default: begin
        o_dst_x = '0;
        o_dst_y = '0;
        o_payload = '0;
        sel_mask_oh = '0;
      end
    endcase
  end

endmodule
