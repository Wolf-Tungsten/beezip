`include "parameters.vh"
`default_nettype none

module job_concat (
        input wire clk,
        input wire rst_n,

        input wire input_valid,
        input wire input_end_of_job,
        input wire [63:0] input_seq,
        output wire input_ready,

        output wire output_valid,
        output wire output_end_of_job,
        output wire [4*64-1:0] output_seq_quad,
        input wire output_ready
    );

    // input seq_quad may has bubble, eliminate the bubble according to each seq's valid(lowest bits)
    // when there is a input_delim, flush the remain part of the seq_quad
    // and output the seq_count

    reg [1:0] seq_count_reg;
    reg [64*4-1:0] seq_quad_reg;
    reg end_of_job_reg;

    localparam state_input = 1'b0;
    localparam state_output = 1'b1;
    reg state_reg;


    assign input_ready = (state_reg == state_input);
    assign output_valid = (state_reg == state_output);
    assign output_seq_quad = seq_quad_reg;
    assign output_end_of_job = end_of_job_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= state_input;
            seq_count_reg <= 2'b0;
            seq_quad_reg <= 64'b0;
            end_of_job_reg <= 1'b0;
        end
        else begin
            if (state_reg == state_input) begin
                if (input_valid) begin
                    end_of_job_reg <= input_end_of_job;
                    seq_count_reg <= seq_count_reg + 1;
                    if(seq_count_reg == 2'b00) begin
                        seq_quad_reg[63:0] <= input_seq;
                        if (input_end_of_job) begin
                            state_reg <= state_output;
                        end
                    end
                    else if (seq_count_reg == 2'b01) begin
                        seq_quad_reg[127:64] <= input_seq;
                        if (input_end_of_job) begin
                            state_reg <= state_output;
                        end
                    end
                    else if (seq_count_reg == 2'b10) begin
                        seq_quad_reg[191:128] <= input_seq;
                        if (input_end_of_job) begin
                            state_reg <= state_output;
                        end
                    end
                    else if (seq_count_reg == 2'b11) begin
                        seq_quad_reg[255:192] <= input_seq;
                        state_reg <= state_output;
                    end
                end
            end
            else begin
                if (output_ready) begin
                    seq_count_reg <= 2'b0;
                    state_reg <= state_input;
                    seq_quad_reg <= 0;
                end
            end
        end
    end
endmodule
