`include "util.vh"
// SRAM 1-Read 1-Write
module sram_1r1w #(parameter WORD_SIZE = 8,
                     ADDR_SIZE = 4)
  (input wire clk,
   input wire rst_n,
   input wire write_enable,
   input wire [ADDR_SIZE-1:0] write_address,
   input wire [WORD_SIZE-1:0] write_data,
   input wire read_enable,
   input wire [ADDR_SIZE-1:0] read_address,
   output wire [WORD_SIZE-1:0] read_data);

  reg [WORD_SIZE-1:0] memory [0:(1<<ADDR_SIZE)-1];
  reg [ADDR_SIZE-1:0] read_addr_reg;

  always @(posedge clk)
    begin
      if (!rst_n) begin
         //$display("WORD = %0d, ADDR COUNT = %0d", WORD_SIZE, 2**ADDR_SIZE);
      end else
        begin
          if (write_enable)
            begin
              memory[write_address] <= `TD write_data;
            end
          if (read_enable)
            begin
              read_addr_reg <= `TD read_address;
            end
        end
    end

  assign read_data = memory[read_addr_reg];

endmodule
