module pop_count #(parameter W=16)
(
    input wire [W-1:0] input_vec,
    output reg [$clog2(W)+1-1:0] output_count
);

    integer i;
    always @(*) begin
        output_count = 0;
        for(i=0; i < W; i=i+1) begin
            output_count = output_count + input_vec[i];
        end
    end
endmodule
