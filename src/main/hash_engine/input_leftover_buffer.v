`include "parameters.vh"

module input_leftover_buffer (
        input wire clk,
        input wire rst_n,

        input  wire input_valid,
        output wire input_ready,
        input  wire input_delim,
        input  wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,

        output wire output_valid,
        input  wire output_ready,
        output wire output_delim,
        output wire [`ADDR_WIDTH-1:0] output_head_addr,
        output wire [(`HASH_ISSUE_WIDTH+`HASH_COVER_BYTES-1)*8-1:0] output_data
    );

    /**
    * Function Description
    * hash_engine compute HASH_ISSUE_WIDTH hash values parallel
    * each hash value takes HASH_COVER_BYTES into consideration
    * the input of hash engine is HASH_ISSUE_WIDTH
    * input_leftover_buffer regroup the input data
    * input_leftover_buffer trace head_addr
    * example
    *  - head_addr = 0, data = 0..19
    *  - head_addr = 16, data = 16..35
    *  - head_addr = 32, data = 32..51
    *  - ...
    *  - head_addr = (n-1)*16, data = (n-1)*16..(n-1)*16+19
    */

    localparam state_wait = 2'b0;
    localparam state_output = 2'b1;
    localparam state_flush_delim = 2'b10;

    reg [1:0] state_reg;
    reg [`HASH_ISSUE_WIDTH*8-1:0] data_reg;
    reg [`ADDR_WIDTH-1:0] head_addr_reg;

    assign input_ready = (state_reg == state_wait) || ((state_reg == state_output) && output_ready);
    assign output_valid = ((state_reg == state_output) && input_valid) || (state_reg == state_flush_delim);
    assign output_delim = input_delim || (state_reg == state_flush_delim);
    assign output_data = {input_data[(`HASH_COVER_BYTES-1)*8-1:0], data_reg};
    assign output_head_addr = head_addr_reg;

    always @(posedge clk) begin
        if(!rst_n) begin
            state_reg <= state_wait;
            head_addr_reg <= 0;
        end
        else begin
            case(state_reg)
                state_wait: begin
                    if(input_valid) begin
                        data_reg <= input_data;
                        if(input_delim) begin
                            state_reg <= state_flush_delim;
                        end
                        else begin
                            state_reg <= state_output;
                        end
                    end
                end
                state_output: begin
                    if(output_valid && output_ready) begin
                        data_reg <= input_data;
                        head_addr_reg <= head_addr_reg + `HASH_ISSUE_WIDTH;
                        if(input_delim) begin
                            state_reg <= state_flush_delim;
                        end
                        else begin
                            state_reg <= state_output;
                        end
                    end
                end
                state_flush_delim: begin
                    if(output_ready) begin
                        head_addr_reg <= head_addr_reg + `HASH_ISSUE_WIDTH;
                        state_reg <= state_wait;
                    end
                end
                default: begin
                    state_reg <= state_wait;
                end
            endcase
        end
    end

endmodule
