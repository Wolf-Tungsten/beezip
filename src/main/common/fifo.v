
module fifo #(parameter DEPTH = 4, W = 8) (
    input wire clk,
    input wire rst_n,
    input wire input_valid,
    input wire [W-1:0] input_payload,
    output wire input_ready,
    output wire output_valid,
    output wire [W-1:0] output_payload,
    input wire output_ready 
);

localparam ADDR_WIDTH = $clog2(DEPTH);
localparam COUNT_WIDTH = $clog2(DEPTH)+1;

reg [W-1:0] buffer_reg [DEPTH-1:0];
reg [ADDR_WIDTH-1:0] head_ptr_reg, tail_ptr_reg;
reg [COUNT_WIDTH-1:0] count_reg;

assign input_ready = count_reg <= (DEPTH - 1);
assign output_valid = count_reg > 0;
assign output_payload = buffer_reg[head_ptr_reg];

always @(posedge clk) begin
    if (~rst_n) begin
        head_ptr_reg <= `TD 0;
        tail_ptr_reg <= `TD 0;
        count_reg <= `TD 0;
    end else begin
        if (input_valid && input_ready) begin
            buffer_reg[tail_ptr_reg] <= `TD input_payload;
            tail_ptr_reg <= `TD tail_ptr_reg + 1;
        end
        if (output_valid && output_ready) begin
            head_ptr_reg <= `TD head_ptr_reg + 1;
        end
        if (input_valid && input_ready && output_valid && output_ready) begin
            count_reg <= `TD count_reg;
        end else if (input_valid && input_ready) begin
            count_reg <= `TD count_reg + 1;
        end else if (output_valid && output_ready) begin
            count_reg <= `TD count_reg - 1;
        end
    end
end
endmodule