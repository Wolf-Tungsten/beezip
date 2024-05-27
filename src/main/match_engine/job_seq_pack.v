`include "parameters.vh"
`include "log.vh"
module job_seq_pack (
        input wire clk,
        input wire rst_n,

        input wire input_valid,
        input wire input_job_delim,
        input wire input_end_of_job,
        input wire input_has_overlap,
        input wire [`JOB_LEN_LOG2+1-1:0] input_overlap_len,
        input wire [(`JOB_LEN_LOG2+1)-1:0] input_lit_len,
        input wire [`ADDR_WIDTH-1:0] input_match_start_addr,
        input wire [(`MAX_MATCH_LEN_LOG2+1)-1:0] input_match_len,
        input wire [`ADDR_WIDTH-1:0] input_history_addr,
        output wire input_ready,

        output wire output_valid,
        output wire [63:0] output_seq,
        output wire output_end_of_job,
        output wire output_delim,
        input wire output_ready
    );

    wire seq_valid = 1'b1;
    wire seq_delim = input_end_of_job && input_job_delim;
    wire seq_end_of_job = input_end_of_job;
    wire seq_has_overlap = input_has_overlap;
    wire [3:0] seq_reserved = 4'b0;
    wire [7:0] seq_overlap_len = input_overlap_len;
    wire [15:0] seq_lit_len = input_lit_len;
    wire [23:0] seq_offset = input_match_start_addr - input_history_addr;
    wire [7:0] seq_match_len = input_match_len;

    wire [63:0] input_seq = {seq_match_len, seq_offset, seq_lit_len, seq_overlap_len, seq_reserved, seq_has_overlap, seq_end_of_job, seq_delim, seq_valid};

    assign input_ready = output_ready;
    assign output_valid = input_valid;
    assign output_seq = input_seq;
    assign output_end_of_job = seq_end_of_job;
    assign output_delim = seq_delim;

endmodule