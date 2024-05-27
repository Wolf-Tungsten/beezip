`include "parameters.vh"

module window_buffer #(parameter WIDTH_BYTES=8, SIZE_BYTES_LOG2=15) (
    input wire clk,
    input wire rst_n,

    input wire write_enable,
    input wire [`ADDR_WIDTH-1:0] write_address,
    input wire [WIDTH_BYTES*8-1:0] write_data,

    input wire read_enable,
    input wire [`ADDR_WIDTH-1:0] read_address,
    output wire read_unsafe,
    output wire [WIDTH_BYTES*8-1:0] read_data,

    output wire [`ADDR_WIDTH-1:0] head_address,
    output wire [`ADDR_WIDTH-1:0] tail_address
);

    localparam SIZE_BYTES = 2**SIZE_BYTES_LOG2;
    localparam ADDR_UNALIGNED_PART = $clog2(WIDTH_BYTES);

    reg [`ADDR_WIDTH-1:0] head_address_reg;
    assign head_address = write_enable ? write_address : head_address_reg;
    assign tail_address = (head_address <= SIZE_BYTES) ? 0 : head_address - SIZE_BYTES + 2 * WIDTH_BYTES;

    reg read_unsafe_reg;
    assign read_unsafe = read_unsafe_reg;

    wire [SIZE_BYTES_LOG2-1:0] aligned_write_address = {write_address[SIZE_BYTES_LOG2-1:ADDR_UNALIGNED_PART], {ADDR_UNALIGNED_PART{1'b0}}};

    always @(posedge clk) begin
        if(~rst_n) begin
            head_address_reg <= 0;
        end else begin
            if(write_enable) begin
                head_address_reg <= write_address;
            end
            if(read_enable) begin
                read_unsafe_reg <= (read_address <= tail_address) || (read_address >= head_address_reg);
            end
        end
    end

    unaligned_mem #(.WIDTH_BYTES(WIDTH_BYTES), .SIZE_BYTES_LOG2(SIZE_BYTES_LOG2)) unaligned_mem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(write_enable),
        .write_address(aligned_write_address),
        .write_data(write_data),
        .read_enable(read_enable),
        .read_address(read_address[SIZE_BYTES_LOG2-1:0]),
        .read_data(read_data)
    );
endmodule