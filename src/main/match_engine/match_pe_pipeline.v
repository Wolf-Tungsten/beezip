`include "parameters.vh"
`include "util.vh"

module match_pe_pipeline #(parameter SCOREBOARD_ENTRY_INDEX=2, NBPIPE=3) (
    input wire clk,
    input wire rst_n,

    input wire i_valid,
    input wire [SCOREBOARD_ENTRY_INDEX-1:0] i_idx,
    input wire i_last,
    input wire [`ADDR_WIDTH-1:0] i_head_addr,
    input wire [`ADDR_WIDTH-1:0] i_history_addr,

    output wire o_valid,
    output wire o_last,
    output wire [SCOREBOARD_ENTRY_INDEX-1:0] o_idx,
    output wire [`MAX_MATCH_LEN_LOG2:0] o_match_len,

    input wire [`ADDR_WIDTH-1:0] i_write_addr,
    input wire [`MATCH_PE_WIDTH*8-1:0] i_write_data,
    input wire i_write_enable
);
    // 流水线结构
    // in-|window_buffer[reg*(NB+1)]|-|comparator|-[reg]-|match_len_encoder|-[reg]-out
    wire hist_buf_read_unsafe, head_buf_read_unsafe;
    wire [`MATCH_PE_WIDTH*8-1:0] hist_buf_read_data, head_buf_read_data;

    window_buffer #(.SIZE_BYTES_LOG2(`MATCH_PE_DEPTH_LOG2), .NBPIPE(NBPIPE)) history_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(i_write_enable),
        .write_address(i_write_addr),
        .write_data(i_write_data),

        .read_enable(i_valid),
        .read_address(i_history_addr),
        .read_unsafe(hist_buf_read_unsafe),
        .read_data(hist_buf_read_data)
    );

    window_buffer #(.SIZE_BYTES_LOG2(`MAX_MATCH_LEN_LOG2), .NBPIPE(NBPIPE)) head_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(1'b1),
        .write_address(i_write_addr),
        .write_data(i_write_data),

        .read_enable(i_valid),
        .read_address(i_head_addr),
        .read_unsafe(head_buf_read_unsafe),
        .read_data(head_buf_read_data)
    );


    reg [`MATCH_PE_WIDTH-1:0] bytewise_compare_result_reg;
    integer i;
    always @(posedge clk) begin
        for(i = 0; i < `MATCH_PE_WIDTH; i = i+1) begin
            bytewise_compare_result_reg[i] <= (hist_buf_read_data[i*8+:8] == head_buf_read_data[i*8+:8]) && !hist_buf_read_unsafe && !head_buf_read_unsafe;
        end
    end

    // 和 比较器 对齐的移位寄存器
    wire valid_after_comparator;
    wire last_after_comparator;
    wire [$bits(i_idx)-1:0] idx_after_comparator;
    dff #(.W($bits({i_valid, i_last, i_idx})), .EN(0), .RST(1), .RST_V(0), .PIPE_DEPTH(NBPIPE+1+1), .RETIMING(0)) comparator_shift_reg (
        .clk(clk),
        .rst_n(rst_n),
        .d({i_valid, i_last, i_idx}),
        .en(1'b1),
        .q({valid_after_comparator, last_after_comparator, idx_after_comparator})
    );

    wire [`MAX_MATCH_LEN_LOG2:0] match_len;
    wire can_ext;
    match_len_encoder #(.MASK_WIDTH(`MATCH_PE_WIDTH), .MATCH_LEN_WIDTH(`MAX_MATCH_LEN_LOG2+1)) mle_inst (
        .compare_bitmask(bytewise_compare_result_reg),
        .match_len(match_len),
        .can_ext(can_ext)
    );
    
    // 和 匹配长度编码器 对齐的移位寄存器, 包含 valid, last, idx, match_len, 输出连接到输出端口
    // 分为两个 dff 只有 valid 需要 reset，其他不需要
    // 除了 valid 信号的，不需要 reset
    dff #(.W($bits({last_after_comparator, idx_after_comparator, match_len})), .EN(0), .RST(0), .RST_V(0), .PIPE_DEPTH(1), .RETIMING(0)) mle_reg (
        .clk(clk),
        .rst_n(rst_n),
        .d({last_after_comparator, idx_after_comparator, match_len}),
        .en(1'b1),
        .q({o_last, o_idx, o_match_len})
    );
    // valid 需要 reset
    dff #(.W(1), .EN(0), .RST(1), .RST_V(0), .PIPE_DEPTH(1), .RETIMING(0)) mle_valid_reg (
        .clk(clk),
        .rst_n(rst_n),
        .d(valid_after_comparator),
        .en(1'b1),
        .q(o_valid)
    );

endmodule