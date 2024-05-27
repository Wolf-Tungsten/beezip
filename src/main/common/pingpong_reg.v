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

    // reg
    reg head_ptr, tail_ptr;
    reg [1:0] count_reg;
    reg [W-1:0] buffer_reg[1:0];

    assign input_ready = count_reg < 2'b10;
    assign output_valid = count_reg > 2'b0;
    assign output_payload = buffer_reg[head_ptr];

    always @(posedge clk) begin
        if (!rst_n) begin
            head_ptr <= 1'b0;
            tail_ptr <= 1'b0;
            count_reg <= 2'b0;
        end
        else begin
            if (input_valid && input_ready) begin
                buffer_reg[tail_ptr] <= input_payload;
                tail_ptr <= ~tail_ptr;
            end
            if (output_valid && output_ready) begin
                head_ptr <= ~head_ptr;
            end
            if (input_valid && input_ready && output_valid && output_ready) begin
                count_reg <= count_reg;
            end
            else if (input_valid && input_ready) begin
                count_reg <= count_reg + 2'b1;
            end
            else if (output_valid && output_ready) begin
                count_reg <= count_reg - 2'b1;
            end
        end
    end
endmodule