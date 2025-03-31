module bubble_discard_butterfly #(parameter W = 8) (
    input  [W-1:0] data_in_0,
    input  [W-1:0] data_in_1,
    input          strb_in_0,
    input          strb_in_1,
    output [W-1:0] data_out_0,
    output [W-1:0] data_out_1,
    output         strb_out_0,
    output         strb_out_1
);

    // 内部信号声明
    reg [W-1:0] data_out_0_reg;
    reg [W-1:0] data_out_1_reg;
    reg         strb_out_0_reg;
    reg         strb_out_1_reg;

    // 组合逻辑
    always @(*) begin
        data_out_0_reg = (strb_in_0 == 1'b1) ? data_in_0 : ((strb_in_1 == 1'b1) ? data_in_1 : {W{1'b0}});
        data_out_1_reg = (strb_in_0 == 1'b1 && strb_in_1 == 1'b1) ? data_in_1 : {W{1'b0}};

        strb_out_0_reg = (strb_in_0 == 1'b1) ? 1'b1 : ((strb_in_1 == 1'b1) ? 1'b1 : 1'b0);
        strb_out_1_reg = (strb_in_0 == 1'b1 && strb_in_1 == 1'b1) ? 1'b1 : 1'b0;
    end

    // 将寄存器连接到输出
    assign data_out_0 = data_out_0_reg;
    assign data_out_1 = data_out_1_reg;
    assign strb_out_0 = strb_out_0_reg;
    assign strb_out_1 = strb_out_1_reg;

endmodule