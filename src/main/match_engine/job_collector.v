`include "parameters.vh"
`include "log.vh"

module job_collector (
    input wire clk,
    input wire rst_n,

    input wire [`MATCH_PE_NUM-1:0] input_valid,
    input wire [`MATCH_PE_NUM*64*4-1:0] input_seq_quad,
    input wire [`MATCH_PE_NUM-1:0] input_end_of_job,
    input wire [`MATCH_PE_NUM-1:0] input_delim,
    output wire [`MATCH_PE_NUM-1:0] input_ready,


    output wire output_valid,
    output wire [64*4-1:0] output_seq_quad,
    output wire output_delim,
    input wire output_ready
);

    reg [`MATCH_PE_NUM_LOG2-1:0] sel_reg;
    reg [`MATCH_PE_NUM-1:0] sel_mask_reg;
    wire input_valid_arr [`MATCH_PE_NUM-1:0];
    wire input_end_of_job_arr [`MATCH_PE_NUM-1:0];
    wire input_delim_arr [`MATCH_PE_NUM-1:0];
    wire [64*4-1:0] input_seq_arr [`MATCH_PE_NUM-1:0];

    genvar i;
    generate
        for (i = 0; i < `MATCH_PE_NUM; i = i + 1) begin: gen_job_collector
            assign input_valid_arr[i] = input_valid[i];
            assign input_end_of_job_arr[i] = input_end_of_job[i];
            assign input_delim_arr[i] = input_delim[i];
            assign input_seq_arr[i] = input_seq_quad[i*64*4 +: 64*4];
        end
    endgenerate

    assign output_valid = input_valid_arr[sel_reg];
    assign output_seq_quad = input_seq_arr[sel_reg];
    assign output_delim = input_delim_arr[sel_reg];
    assign input_ready = sel_mask_reg & {`MATCH_PE_NUM{output_ready}};


    always @(posedge clk) begin
        if (~rst_n) begin
            sel_reg <= `TD 0;
            sel_mask_reg <= `TD {{`MATCH_PE_NUM-1{1'b0}}, 1'b1};
        end else begin
            if(output_valid && output_ready && input_end_of_job_arr[sel_reg]) begin
                sel_reg <= `TD sel_reg + 1;
                sel_mask_reg <= `TD {sel_mask_reg[`MATCH_PE_NUM-2:0], sel_mask_reg[`MATCH_PE_NUM-1]};
            end
        end
    end

endmodule