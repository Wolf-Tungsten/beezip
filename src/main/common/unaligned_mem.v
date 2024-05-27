`default_nettype none
`include "util.vh"

module unaligned_mem #(parameter WIDTH_BYTES=8, SIZE_BYTES_LOG2=15) (
    input wire clk,
    input wire rst_n,
    // 对齐写入
    input wire write_enable,
    input wire [SIZE_BYTES_LOG2-1:0] write_address,
    input wire [WIDTH_BYTES*8-1:0] write_data,
    // 非对齐读取
    input wire read_enable,
    input wire [SIZE_BYTES_LOG2-1:0] read_address,
    output wire [WIDTH_BYTES*8-1:0] read_data
);

    localparam BANK_WIDTH_BITS = WIDTH_BYTES * 8;
    localparam ADDR_UNALIGNED_PART = $clog2(WIDTH_BYTES);
    localparam BANK_ADDR_SIZE = SIZE_BYTES_LOG2 - ADDR_UNALIGNED_PART - 1; // 拆分到两个 bank 里，所以单个 bank 的地址空间减半


    reg bank_read_sel_reg;
    reg [ADDR_UNALIGNED_PART-1:0] read_shift_bytes_reg;

    wire bank_lo_read_enable, bank_hi_read_enable, bank_lo_write_enable, bank_hi_write_enable;
    wire [BANK_ADDR_SIZE-1:0] bank_lo_read_addr, bank_hi_read_addr, bank_lo_write_addr, bank_hi_write_addr;
    wire [BANK_WIDTH_BITS-1:0] bank_lo_read_data, bank_hi_read_data, bank_lo_write_data, bank_hi_write_data;
    wire bank_read_sel, bank_write_sel; // sel: data head in lo=0. in hi=1
    wire [ADDR_UNALIGNED_PART-1:0] read_shift_bytes;
    wire [BANK_ADDR_SIZE-1:0] bank_read_addr_base, bank_write_addr_base;
    wire [BANK_WIDTH_BITS*2-1:0] bank_read_data_concat;

    // bank 排布
    //            bank_hi                           bank_lo
    // ｜15｜14｜13｜12｜11｜10｜09｜08｜   ｜07｜06｜05｜04｜03｜02｜01｜00｜
    assign {bank_read_addr_base, bank_read_sel, read_shift_bytes} = read_address;
    assign bank_lo_read_enable = read_enable;
    assign bank_hi_read_enable = read_enable;
    assign bank_lo_read_addr = bank_read_addr_base + bank_read_sel;
    assign bank_hi_read_addr = bank_read_addr_base;
    assign bank_read_data_concat = bank_read_sel_reg ? {bank_lo_read_data, bank_hi_read_data} : {bank_hi_read_data, bank_lo_read_data};
    assign read_data = bank_read_data_concat >> ({read_shift_bytes_reg, 3'b0});
    always @(posedge clk) begin
        if (~rst_n) begin
            bank_read_sel_reg <= `TD 0;
            read_shift_bytes_reg <= `TD 0;
        end else begin
            if(read_enable) begin
                bank_read_sel_reg <= `TD bank_read_sel;
                read_shift_bytes_reg <= `TD read_shift_bytes;
            end
        end
    end
    assign {bank_write_addr_base, bank_write_sel} = write_address[SIZE_BYTES_LOG2-1:ADDR_UNALIGNED_PART];
    assign bank_lo_write_enable = write_enable & ~bank_write_sel;
    assign bank_hi_write_enable = write_enable & bank_write_sel;
    assign bank_lo_write_addr = bank_write_addr_base;
    assign bank_hi_write_addr = bank_write_addr_base;
    assign bank_lo_write_data = write_data;
    assign bank_hi_write_data = write_data;

    sram_1r1w #(.WORD_SIZE(BANK_WIDTH_BITS), .ADDR_SIZE(BANK_ADDR_SIZE)) bank_lo (
                  .clk(clk),
                  .rst_n(rst_n),
                  .write_enable(bank_lo_write_enable),
                  .write_address(bank_lo_write_addr),
                  .write_data(bank_lo_write_data),
                  .read_enable(bank_lo_read_enable),
                  .read_address(bank_lo_read_addr),
                  .read_data(bank_lo_read_data)
              );
    sram_1r1w #(.WORD_SIZE(BANK_WIDTH_BITS), .ADDR_SIZE(BANK_ADDR_SIZE)) bank_hi (
                  .clk(clk),
                  .rst_n(rst_n),
                  .write_enable(bank_hi_write_enable),
                  .write_address(bank_hi_write_addr),
                  .write_data(bank_hi_write_data),
                  .read_enable(bank_hi_read_enable),
                  .read_address(bank_hi_read_addr),
                  .read_data(bank_hi_read_data)
              );

endmodule