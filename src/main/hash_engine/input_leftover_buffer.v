`include "parameters.vh"

module input_leftover_buffer (
        input wire clk,
        input wire rst_n,

        input  wire input_valid,
        output wire input_ready,
        input  wire input_delim,
        input  wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,

        output wire output_valid,
        input  wire output_ready,
        output wire output_delim,
        output wire [`ADDR_WIDTH-1:0] output_head_addr,
        output wire [(`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8-1:0] output_data
    );

    /**
    * 功能描述
    * hash_engine 需要实现并行计算 HASH_ISSUE_WIDTH 个 hash 值
    * 每计算一个 hash 值需要覆盖 HASH_COVER_BYTES 个输入字节
    * 压缩引擎的输入位宽也是 HASH_ISSUE_WIDTH
    * 这就带来一个问题：每拍（这里并不精确，因为要考虑流水线握手，这里的每拍指的是每一组新数据）数据尾部的 HASH_COVER_BYTES-1 个 hash 值计算需要下一拍的数据参与
    * 需要 input_leftover_buffer 进行跨拍数据重组
    * - 跨拍数据重组的逻辑：后一拍数据的低比特位补齐前一拍数据的高比特位
    * input_leftover_buffer 同时还处理 input_delim 并维护 head_addr
    * 输入和输出都使用 valid 和 ready 握手
    * 输出数据规则
    *  - 第一拍输出 head_addr = 0, data = 0..19
    *  - 第二拍输出 head_addr = 16, data = 16..35
    *  - 第三拍输出 head_addr = 32, data = 32..51
    *  - ...
    *  - 第 n 拍输出 head_addr = (n-1)*16, data = (n-1)*16..(n-1)*16+19
    * delim 的处理方式
    *  - delim 表示一个数据块的结束，为了防止错误，边界处的数据不会被重组
    *  - 假设第 n 拍输入数据 delim 有效，那么第 n 拍的输出数据 delim 有效
    *  - 且第 n 拍输出不等待第 n+1 拍输入到来，后续的处理逻辑会忽略 delim 有效的数据的计算和 hash 访问
    *  - delim 不会影响 head_addr 的递增（head_addr只在复位时被重置为0）
    */

    localparam state_wait = 2'b0;
    localparam state_output = 2'b1;
    localparam state_flush_delim = 2'b10;

    reg [1:0] state_reg;
    reg [`HASH_ISSUE_WIDTH*8-1:0] data_reg;
    reg [`ADDR_WIDTH-1:0] head_addr_reg;

    assign input_ready = (state_reg == state_wait) || ((state_reg == state_output) && output_ready);
    assign output_valid = ((state_reg == state_output) && input_valid) || (state_reg == state_flush_delim);
    assign output_delim = input_delim || (state_reg == state_flush_delim);
    assign output_data = {input_data[(`META_HISTORY_LEN-1)*8-1:0], data_reg};
    assign output_head_addr = head_addr_reg;

    always @(posedge clk) begin
        if(!rst_n) begin
            state_reg <= state_wait;
            head_addr_reg <= 0;
        end
        else begin
            case(state_reg)
                state_wait: begin
                    if(input_valid) begin
                        data_reg <= input_data;
                        if(input_delim) begin
                            state_reg <= state_flush_delim;
                        end
                        else begin
                            state_reg <= state_output;
                        end
                    end
                end
                state_output: begin
                    if(output_valid && output_ready) begin
                        data_reg <= input_data;
                        head_addr_reg <= head_addr_reg + `HASH_ISSUE_WIDTH;
                        if(input_delim) begin
                            state_reg <= state_flush_delim;
                        end
                        else begin
                            state_reg <= state_output;
                        end
                    end
                end
                state_flush_delim: begin
                    if(output_ready) begin
                        head_addr_reg <= head_addr_reg + `HASH_ISSUE_WIDTH;
                        state_reg <= state_wait;
                    end
                end
                default: begin
                    state_reg <= state_wait;
                end
            endcase
        end
    end

endmodule
