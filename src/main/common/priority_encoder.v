module priority_encoder #(parameter W=16)(
    input wire [W-1:0] input_vec,
    output reg output_valid,
    output reg [$clog2(W)-1:0] output_index
);

  // use while loop for non fixed loop length
  always @(*) begin
    output_index = {$clog2(W){1'b0}};
    output_valid = input_vec[output_index];
    while ((!output_valid) && (output_index!=(W-1))) begin
      output_index = output_index + 1 ;
      output_valid = input_vec[output_index];
    end
  end

endmodule