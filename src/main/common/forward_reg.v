module forward_reg #(parameter W = 8)
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

    reg buffer_full_reg;
    reg [W-1:0] buffer_reg;

    assign input_ready = (~buffer_full_reg) || output_ready;
    assign output_valid = buffer_full_reg;
    assign output_payload = buffer_reg;

    always @(posedge clk) begin
        if (~rst_n) begin
            buffer_full_reg <= 1'b0;
        end else begin
            if(~buffer_full_reg) begin
                if(input_valid) begin
                    buffer_reg <= input_payload;
                    buffer_full_reg <= 1'b1;
                end
            end else begin
                if(input_valid && output_ready) begin
                    buffer_reg <= input_payload;
                end else if (!input_valid && output_ready) begin
                    buffer_full_reg <= 1'b0;
                end
            end
        end
    end
endmodule