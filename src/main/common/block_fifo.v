`include "util.vh"

module block_fifo #(
    parameter integer BUF_DEPTH = 16, // FIFO 深度，以 W 位数据为单位 (总共可以存储 BUF_DEPTH * W bits 数据)
    parameter integer W = 32,  // 数据位宽 (bits)
    parameter [$clog2(BUF_DEPTH)+1-1:0] 
    N = 4  // 数据块大小 (W 位数据的数量), 一次最多输入/输出 N 个 W 位数据

) (
    input wire clk,
    input wire rst_n,

    // Input Data Interface (Valid-Ready Handshake)
    input wire i_valid,  // 输入 Valid 信号，指示 i_data 和 i_strb 有效
    output wire i_ready,  // 输入 Ready 信号，指示 mimo_fifo 准备好接收数据
    input wire [N*W-1:0] i_data,  // 输入数据，一次最多 N 个 W 位数据
    input wire [$clog2(N)+1-1:0] i_count,  // 输入数据从低位开始有几个有效？

    // Input Flush，在非空时强制输出剩余数据并清空 FIFO
    input  wire        i_flush,                 // 输入 Flush 信号，强制 FIFO 输出剩余数据并清空 (高有效)

    // Output Interface (Valid-Ready Handshake)
    output reg o_valid,  // 输出 Valid 信号，指示 o_data 和 o_strb 有效
    input wire o_ready,  // 输出 Ready 信号，指示下游模块准备好接收数据
    output reg [N*W-1:0] o_data,  // 输出数据，一次最多 N 个 W 位数据
    output reg [N-1:0] o_strb,                  // 输出 Strobe 信号，指示 o_data 中哪些 W 位数据是有效的 (bit 0 for word 0, bit 1 for word 1, etc.)
    output reg        o_last,                  // 输出 Last 信号，指示这是 Flush 操作的最后一个输出数据 (可选，如果需要指示 Flush 完成)

    // Status Signals (Optional, for monitoring and debugging)
    output wire [$clog2(BUF_DEPTH)+1-1:0] fifo_count
);

  localparam COUNT_WIDTH = $clog2(BUF_DEPTH) + 1;
  localparam PTR_WIDTH = $clog2(BUF_DEPTH);

  reg [W-1:0] data_mem_reg[0:BUF_DEPTH-1];  // 用于存储每个数据块的数据
  reg [COUNT_WIDTH-1:0] counter_reg;
  reg [PTR_WIDTH-1:0] i_ptr_reg;
  reg [PTR_WIDTH-1:0] o_ptr_reg;

  //------------------------------------------------------------------------------
  assign fifo_count = counter_reg;
  assign i_ready = !i_flush & counter_reg <= BUF_DEPTH[COUNT_WIDTH-1:0] - N;

  //------------------------------------------------------------------------------
  // 指针读写更新
  wire i_fire = i_valid & i_ready;
  wire o_fire = o_valid & o_ready;
  always @(posedge clk) begin
    if (~rst_n) begin
      counter_reg <= 0;
      i_ptr_reg   <= 0;
      o_ptr_reg   <= 0;
    end else begin
      if (i_flush) begin
        if (counter_reg > N) begin
          if (o_ready) begin
            o_ptr_reg   <= o_ptr_reg + N[PTR_WIDTH-1:0];
            counter_reg <= counter_reg - N;
          end
        end else if (counter_reg > 0) begin
          if (o_ready) begin
            o_ptr_reg   <= o_ptr_reg + counter_reg[PTR_WIDTH-1:0];
            counter_reg <= 0;
          end
        end
      end else begin
        if (i_fire & o_fire) begin
          o_ptr_reg   <= o_ptr_reg + N[PTR_WIDTH-1:0];
          i_ptr_reg   <= i_ptr_reg + `ZERO_EXTEND(i_count, PTR_WIDTH);
          counter_reg <= counter_reg + `ZERO_EXTEND(i_count, COUNT_WIDTH) - N;
        end else if (i_fire) begin
          i_ptr_reg   <= i_ptr_reg + `ZERO_EXTEND(i_count, PTR_WIDTH);
          counter_reg <= counter_reg + `ZERO_EXTEND(i_count, COUNT_WIDTH);
        end else if (o_fire) begin
          o_ptr_reg   <= o_ptr_reg + N[PTR_WIDTH-1:0];
          counter_reg <= counter_reg - N;
        end
      end
    end
  end

  // 数据写入 (优化后的版本)
  always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
      if (i_fire) begin
        for (integer j = 0; j < N; j = j + 1) begin
          if (j < i_count) begin
            data_mem_reg[i_ptr_reg + j[PTR_WIDTH-1:0]] <= i_data[j*W+:W];
          end
        end
      end
    end
  end

  // 数据读取
  always @(posedge clk) begin
    if(!rst_n) begin
      o_valid <= 1'b0;
    end else begin
      o_last  <= i_flush & (counter_reg <= N);
      o_valid <= (counter_reg >= N) | (i_flush & (counter_reg > 0));
      for (integer i = 0; i < N; i = i + 1) begin
          o_data[i*W+:W] = data_mem_reg[o_ptr_reg+i[PTR_WIDTH-1:0]];
          o_strb[i] = i < counter_reg;
      end
    end
  end


endmodule
