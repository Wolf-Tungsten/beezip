module pingpong_reg #(parameter W=8)
(
    input wire clk,
    input wire rst_n,

    input  wire         input_valid,
    output wire         input_ready,
    input  wire [W-1:0] input_payload,
    
    output wire         output_valid,
    input  wire         output_ready,
    output wire [W-1:0] output_payload
    
);

    handshake_slice_reg #(.W(W), .DEPTH(1)) internal_handshake_reg (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_payload(input_payload),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .output_payload(output_payload)
    );
endmodule