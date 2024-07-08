`include "parameters.vh"

module window_buffer #(parameter SIZE_BYTES_LOG2=15, NBPIPE=3) (
    input wire clk,
    input wire rst_n,

    input wire write_enable,
    input wire [`ADDR_WIDTH-1:0] write_address,
    input wire [`MATCH_PE_WIDTH*8-1:0] write_data,

    input wire read_enable,
    input wire [`ADDR_WIDTH-1:0] read_address,
    output wire read_unsafe,
    output wire [`MATCH_PE_WIDTH*8-1:0] read_data

);

    localparam SIZE_BYTES = 2**SIZE_BYTES_LOG2;
    localparam ADDR_UNALIGNED_PART = `MATCH_PE_WIDTH_LOG2;
    localparam TAIL_BAR = SIZE_BYTES - `MATCH_PE_WIDTH;
    wire [SIZE_BYTES_LOG2-1:0] tail_bar = TAIL_BAR;

    wire [SIZE_BYTES_LOG2-1:0] read_address_lo, write_address_lo;
    wire [`ADDR_WIDTH-SIZE_BYTES_LOG2-1:0] read_address_hi, write_address_hi;
    assign {read_address_hi, read_address_lo} = read_address;
    assign {write_address_hi, write_address_lo} = write_address;

    reg has_two_range_reg;
    reg [`ADDR_WIDTH-SIZE_BYTES_LOG2-1:0] range_0_hi_reg, range_1_hi_reg;
    reg [SIZE_BYTES_LOG2-1:0] latest_write_address_lo_reg;
    always @(posedge clk) begin
        if(!rst_n) begin
            has_two_range_reg <= 1'b0;
            range_0_hi_reg <= 0;
            range_1_hi_reg <= 0;
            latest_write_address_lo_reg <= 0;
        end else begin
            if(write_enable) begin
                latest_write_address_lo_reg <= write_address_lo;
                if(write_address_lo == 0) begin
                    has_two_range_reg <= 1'b1;
                    range_1_hi_reg <= range_0_hi_reg;
                    range_0_hi_reg <= write_address_hi;
                end else if (write_address_lo == tail_bar) begin
                    has_two_range_reg <= 1'b0;
                end
            end
        end
    end

    reg read_unsafe_internal;
    wire [`ADDR_WIDTH-1:0] range_0_start, range_0_end, range_1_start, range_1_end;
    wire [SIZE_BYTES_LOG2-1:0] latest_write_address_lo_plus_match_pe_width = latest_write_address_lo_reg + `MATCH_PE_WIDTH;
    assign range_0_start = {range_0_hi_reg, {SIZE_BYTES_LOG2{1'b0}}};
    assign range_0_end = {range_0_hi_reg, has_two_range_reg ? latest_write_address_lo_reg : tail_bar};
    assign range_1_start = {range_1_hi_reg, latest_write_address_lo_plus_match_pe_width};
    assign range_1_end = {range_1_hi_reg, tail_bar};
    always @(*) begin
        read_unsafe_internal = 1'b0;
        if(has_two_range_reg) begin
            read_unsafe_internal = (read_address >= range_0_start && read_address <= range_0_end) || 
                                   (read_address >= range_1_start && read_address <= range_1_end);
        end else begin
            read_unsafe_internal = (read_address >= range_0_start && read_address <= range_0_end);
        end
    end
    
    reg read_unsafe_reg[NBPIPE+1-1:0];
    integer i;
    always @(posedge clk) begin
        read_unsafe_reg[0] <= read_unsafe_internal;
        for(i=1; i < NBPIPE+1; i=i+1) begin
            read_unsafe_reg[i] <= read_unsafe_reg[i-1];
        end
    end

    assign read_unsafe = read_unsafe_reg[NBPIPE];
    

    wire [SIZE_BYTES_LOG2-1:0] aligned_write_address = {write_address[SIZE_BYTES_LOG2-1:ADDR_UNALIGNED_PART], {ADDR_UNALIGNED_PART{1'b0}}};

    unaligned_mem #(.WIDTH_BYTES(`MATCH_PE_WIDTH), .SIZE_BYTES_LOG2(SIZE_BYTES_LOG2), .NBPIPE(NBPIPE)) unaligned_mem_inst (
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