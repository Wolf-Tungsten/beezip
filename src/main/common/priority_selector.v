// transform input vec into a 1-hot output vec
// input vec may have zero or more bits set
// if there are 1 or more multiple bits set, the lowest bit is selected and set in output
// if there is no bits set, no bit is set in output
module priority_selector#(parameter W=16)
(
    input wire [W-1:0] input_vec,
    output wire [W-1:0] output_vec
);

    assign output_vec[0] = input_vec[0];
    genvar i;
    generate
        for(i=1; i < W; i = i + 1) begin : priority_selector_mask_transpose
            assign output_vec[i] = input_vec[i] & ~(|input_vec[i-1:0]);
        end
    endgenerate
    

endmodule