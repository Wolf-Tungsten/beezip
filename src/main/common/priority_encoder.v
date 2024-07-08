module priority_encoder #(parameter W=16)(
    input wire [W-1:0] input_vec,
    output reg output_valid,
    output wire [$clog2(W)-1:0] output_index
);

  // use while loop for non fixed loop length
  reg [$clog2(W)+1-1:0] comb_loop_index;
  assign output_index = comb_loop_index[$clog2(W)-1:0];
  always @(*) begin
    comb_loop_index = 0;
    output_valid = input_vec[comb_loop_index[$clog2(W)-1:0]];
    while ((!output_valid) && (comb_loop_index != W-1)) begin
      comb_loop_index = comb_loop_index + 1 ;
      output_valid = input_vec[comb_loop_index[$clog2(W)-1:0]];
    end
  end

endmodule