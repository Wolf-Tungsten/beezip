module priority_encoder #(parameter [31:0] W = 16)(
    input wire [W-1:0] input_vec,
    output reg output_valid,
    output reg [$clog2(W)-1:0] output_index
);
  integer i;
  always @(*) begin
    output_valid = 0; // 默认无有效位
    output_index = 0; // 默认索引为 0
    for (i = W-1; i >= 0; i = i - 1) begin
      if (input_vec[i]) begin
        output_valid = 1;
        output_index = i[$clog2(W)-1:0];
      end
    end
  end
endmodule
