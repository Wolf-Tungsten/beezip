module mux1h #(parameter P_CNT=1, P_W=1)
(
    input wire [P_CNT*P_W-1:0] input_payload_vec,
    input wire [P_CNT-1:0] input_select_vec,
    output wire [P_W-1:0] output_payload
);

    wire [P_CNT*P_W-1:0] masked_input_payload_vec;
    genvar i, j;
    generate
        for(i=0; i < P_CNT; i = i + 1) begin : mux1h_mask_transpose
            for(j = 0; j < P_W; j = j + 1) begin
                assign masked_input_payload_vec[j*P_CNT + i] = input_payload_vec[i*P_W + j] & input_select_vec[i];
            end
        end
    endgenerate
    generate
        for(i=0; i < P_W; i = i + 1) begin : mux1h_sel_output
            assign output_payload[i] = |masked_input_payload_vec[i*P_CNT +: P_CNT];
        end
    endgenerate

endmodule