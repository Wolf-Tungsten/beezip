`include "util.vh"
// SRAM 1 Port
module sram1p #(parameter WORD_SIZE = 8,
                    ADDR_SIZE = 4)
    (input wire clk,
     input wire rst_n,
     input wire write_enable,
     input wire [ADDR_SIZE-1:0] address,
     input wire [WORD_SIZE-1:0] write_data,
     input wire read_enable,
     output wire [WORD_SIZE-1:0] read_data);

    reg [WORD_SIZE-1:0] memory [0:(1<<ADDR_SIZE)-1];
    reg [WORD_SIZE-1:0] read_data_reg;

    always @(posedge clk) begin
        if (write_enable) begin
            memory[address] <= write_data;
        end
        else if (read_enable) begin
            read_data_reg <= memory[address];
        end
    end

    assign read_data = read_data_reg;

endmodule
