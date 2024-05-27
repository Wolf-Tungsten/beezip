`include "parameters.vh"
`include "log.vh"
module hash_function
    (
        input wire clk,
        input wire rst_n,
        input wire [`HASH_COVER_BYTES*8-1:0] input_data,
        input wire stall,
        output wire [`HASH_BITS-1:0] hash_value
    );

    wire [63:0] prime = 64'hcf1bbcdcbb;
    localparam padding_zero = (64 - `HASH_COVER_BYTES*8);
    wire [63:0] raw_bytes = {input_data, {padding_zero{1'b0}}};
    wire [31:0] prime_l = prime[31:0];
    wire [31:0] prime_h = prime[63:32];
    wire [31:0] raw_bytes_l = raw_bytes[31:0];
    wire [31:0] raw_bytes_h = raw_bytes[63:32];

    reg [63:0] phl_reg;
    reg [63:0] pll_reg;
    reg [63:0] plh_reg;
    reg [63:0] prod_reg;

    assign hash_value = prod_reg[63 -: `HASH_BITS];

    always @(posedge clk) begin
        if(~stall) begin
            // stage 0
            phl_reg <= prime_h * raw_bytes_l;
            pll_reg <= prime_l * raw_bytes_l;
            plh_reg <= prime_l * raw_bytes_h;
            // stage 1
            prod_reg <= (phl_reg << 32) + pll_reg + (plh_reg << 32);
        end
    end
endmodule

module hash_compute
    (
        input wire clk,
        input wire rst_n,
        input wire input_valid,
        input wire [`ADDR_WIDTH-1:0] input_head_addr,
        input wire [(`HASH_ISSUE_WIDTH+`HASH_COVER_BYTES-1)*8-1:0] input_data,
        input wire input_delim,
        output wire input_ready,
        output wire output_valid,
        output wire [`ADDR_WIDTH-1:0] output_head_addr,
        output wire [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] output_hash_value_vec,
        output wire output_delim,
        input wire output_ready
    );

    localparam PAYLOAD_WIDTH = `ADDR_WIDTH + `HASH_BITS*`HASH_ISSUE_WIDTH + 1;

    reg valid_0_reg, valid_1_reg;
    reg [`ADDR_WIDTH-1:0] head_addr_0_reg, head_addr_1_reg;
    reg delim_0_reg, delim_1_reg;
    wire [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] hash_value_vec;
    wire payload_reg_ready;
    wire stall = ~payload_reg_ready;
    assign input_ready = payload_reg_ready;

    genvar i;
    generate
        for (i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
            hash_function hash_func (
                              .clk(clk),
                              .rst_n(rst_n),
                              .input_data(input_data[i*8 +: `HASH_COVER_BYTES*8]),
                              .stall(stall),
                              .hash_value(hash_value_vec[i*`HASH_BITS +: `HASH_BITS])
                          );
        end

        `ifdef HASH_VALUE_LOG
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
            always @(posedge clk) begin
                if(input_valid && input_ready) begin
                    $display("[HashCompute] input head_addr=%d data=0x%x", input_head_addr+i, input_data[i*8 +: `HASH_COVER_BYTES*8]);
                end
                if(output_valid && output_ready) begin
                    $display("[HashCompute] output head_addr=%d hv=0x%x", output_head_addr+i, output_hash_value_vec[i*`HASH_BITS +: `HASH_BITS]);
                end
            end
        end 
        `endif

        // for(i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
        //     always @(posedge clk) begin
        //         if(input_valid && input_ready) begin
        //             $display("[HashCompute] input addr=%d data=0x%x", input_head_addr+i, input_data[i*8 +: `HASH_COVER_BYTES*8]);
        //         end
        //         if(output_valid && output_ready) begin
        //             $display("[HashCompute] output addr=%d hv=0x%x", output_head_addr+i, output_hash_value_vec[i*`HASH_BITS +: `HASH_BITS]);
        //         end
        //     end
        // end
    endgenerate


    forward_reg #(.W(PAYLOAD_WIDTH))
                payload_reg (
                    .clk(clk),
                    .rst_n(rst_n),
                    .input_valid(valid_1_reg),
                    .input_payload({head_addr_1_reg, hash_value_vec, delim_1_reg}),
                    .input_ready(payload_reg_ready),
                    .output_valid(output_valid),
                    .output_payload({output_head_addr, output_hash_value_vec, output_delim}),
                    .output_ready(output_ready)
                );

    always @(posedge clk) begin
        if(~rst_n) begin
            valid_0_reg <= 1'b0;
            valid_1_reg <= 1'b0;
        end
        else begin
            if(~stall) begin
                valid_0_reg <= input_valid;
                valid_1_reg <= valid_0_reg;
                head_addr_0_reg <= input_head_addr;
                head_addr_1_reg <= head_addr_0_reg;
                delim_0_reg <= input_delim;
                delim_1_reg <= delim_0_reg;
            end
        end
    end
endmodule
