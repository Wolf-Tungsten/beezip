module bubble_discard_layer #(parameter W = 8, N = 4, SW = 13) (
    input [N*W-1:0] data_in,
    input [N-1:0] strb_in,
    input [SW-1:0] side_in,
    output [N*W-1:0] data_out,
    output [N-1:0] strb_out,
    output [SW-1:0] side_out
);

    // 纯组合逻辑
    /* 交换结构
    in0 \           / mid0 ------------ out0
         [butterfly]
    in1 /           \ mid1 \           / out1
                            [butterfly]
    in2 \           / mid2 /           \ out2
         [butterfly]
    in3 /           \ mid3 \           / out3
                            [butterfly]
    in4 \           / mid4 /           \ out4
         [butterfly]
    in5 /           \ mid5 \            /out5
                            [butterfly]
    in6 \           / mid6 /            \out6
         [butterfly]
    in7 /           \ mid7 ------------- out7
    */
    // butterfly 的定义
    // module bubble_discard_butterfly #(parameter W = 8) (
    // input  [W-1:0] data_in_0,
    // input  [W-1:0] data_in_1,
    // input          strb_in_0,
    // input          strb_in_1,
    // output [W-1:0] data_out_0,
    // output [W-1:0] data_out_1,
    // output         strb_out_0,
    // output         strb_out_1
    // );

    // 中间信号 (位宽与输入输出相同)
    wire [N*W-1:0] mid_data;
    wire [N-1:0]   mid_strb;

    // 第一级 butterfly (N/2 个)
    genvar i;
    generate
        for (i = 0; i < N/2; i = i + 1) begin : gen_stage1
            bubble_discard_butterfly #( .W(W) ) u_butterfly_stage1 (
                .data_in_0 (data_in[i*2*W +: W]),
                .data_in_1 (data_in[(i*2+1)*W +: W]),
                .strb_in_0 (strb_in[i*2]),
                .strb_in_1 (strb_in[i*2+1]),
                .data_out_0(mid_data[i*2*W +: W]),
                .data_out_1(mid_data[(i*2+1)*W +: W]),
                .strb_out_0(mid_strb[i*2]),
                .strb_out_1(mid_strb[i*2+1])
            );
        end
    endgenerate

    // 第二级 butterfly (N/2 - 1 个)
    genvar j;
    generate
        for (j = 0; j < N/2 - 1; j = j + 1) begin : gen_stage2
            bubble_discard_butterfly #( .W(W) ) u_butterfly_stage2 (
                .data_in_0 (mid_data[(j*2+1)*W +: W]),
                .data_in_1 (mid_data[(j*2+2)*W +: W]),
                .strb_in_0 (mid_strb[j*2+1]),
                .strb_in_1 (mid_strb[j*2+2]),
                .data_out_0(data_out[(j*2+1)*W +: W]),
                .data_out_1(data_out[(j*2+2)*W +: W]),
                .strb_out_0(strb_out[j*2+1]),
                .strb_out_1(strb_out[j*2+2])
            );
        end
    endgenerate

    // 处理最上面和最下面的数据通路
    assign data_out[0*W +: W] = mid_data[0*W +: W];
    assign strb_out[0]        = mid_strb[0];
    assign data_out[(N-1)*W +: W] = mid_data[(N-1)*W +: W];
    assign strb_out[(N-1)]      = mid_strb[(N-1)];
    assign side_out = side_in; // side_in 直通
endmodule