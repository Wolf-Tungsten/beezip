`include "parameters.vh"

module match_engine_top (
    input wire clk,
    input wire rst_n,

    input wire input_data_valid,
    output wire input_data_ready,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
    
    input wire input_hash_result_valid,
    output wire input_hash_result_ready,
    input wire input_hash_result_delim,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_hash_valid_vec,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,

    output wire output_valid,
    output wire [64*4-1:0] output_seq_quad,
    output wire output_delim,
    input wire output_ready
);

    

    wire idhrs_output_valid;
    wire [`ADDR_WIDTH-1:0] idhrs_output_head_addr;
    wire [`HASH_ISSUE_WIDTH*8-1:0] idhrs_output_data;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] idhrs_output_hash_valid_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] idhrs_output_history_addr_vec;
    wire idhrs_output_delim;
    wire idhrs_output_ready;
    

    input_data_hash_result_sync idhrs_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_data_valid(input_data_valid),
        .input_data(input_data),
        .input_data_ready(input_data_ready),

        .input_hash_result_valid(input_hash_result_valid),
        .input_hash_valid_vec(input_hash_valid_vec),
        .input_history_addr_vec(input_history_addr_vec),
        .input_delim(input_hash_result_delim),
        .input_hash_result_ready(input_hash_result_ready),

        .output_valid(idhrs_output_valid),
        .output_head_addr(idhrs_output_head_addr),
        .output_data(idhrs_output_data),
        .output_hash_valid_vec(idhrs_output_hash_valid_vec),
        .output_history_addr_vec(idhrs_output_history_addr_vec),
        .output_delim(idhrs_output_delim),
        .output_ready(idhrs_output_ready)
    );

    wire history_window_buffer_write_enable;
    wire [`MATCH_PE_NUM-1:0] head_window_buffer_write_enable;
    wire [`ADDR_WIDTH-1:0] window_buffer_write_addr;
    wire [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data;

    wire [`MATCH_PE_NUM-1:0] job_dispatcher_output_valid;
    wire [`ADDR_WIDTH-1:0] job_dispatcher_output_head_addr;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] job_dispatcher_output_hash_valid_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] job_dispatcher_output_history_addr_vec;
    wire [`MATCH_PE_NUM-1:0] job_dispatcher_output_ready;

    wire [`MATCH_PE_NUM-1:0] job_launch_valid;
    wire job_delim;
    wire [`MATCH_PE_NUM-1:0] job_launch_ready;

    job_dispatcher job_dispatcher_inst(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(idhrs_output_valid),
        .input_head_addr(idhrs_output_head_addr),
        .input_data(idhrs_output_data),
        .input_hash_valid_vec(idhrs_output_hash_valid_vec),
        .input_history_addr_vec(idhrs_output_history_addr_vec),
        .input_delim(idhrs_output_delim),
        .input_ready(idhrs_output_ready),

        // // head_window_buffer write port
        // output wire history_window_buffer_write_enable,
        // output wire [`MATCH_PE_NUM-1:0] head_window_buffer_write_enable,
        // output wire [`ADDR_WIDTH-1:0] window_buffer_write_addr,
        // output wire [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data,
        .history_window_buffer_write_enable(history_window_buffer_write_enable),
        .head_window_buffer_write_enable(head_window_buffer_write_enable),
        .window_buffer_write_addr(window_buffer_write_addr),
        .window_buffer_write_data(window_buffer_write_data),

        // // output hash result port
        // output wire [`MATCH_PE_NUM-1:0] output_valid,
        // output wire [`ADDR_WIDTH-1:0] output_head_addr,
        // output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_hash_valid_vec,
        // output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
        // input wire  [`MATCH_PE_NUM-1:0] output_ready,
        .output_valid(job_dispatcher_output_valid),
        .output_head_addr(job_dispatcher_output_head_addr),
        .output_hash_valid_vec(job_dispatcher_output_hash_valid_vec),
        .output_history_addr_vec(job_dispatcher_output_history_addr_vec),
        .output_ready(job_dispatcher_output_ready),

        // // job launch port
        // output wire [`MATCH_PE_NUM-1:0] job_launch_valid,
        // output wire job_delim,
        // input wire [`MATCH_PE_NUM-1:0] job_launch_ready
        .job_launch_valid(job_launch_valid),
        .job_delim(job_delim),
        .job_launch_ready(job_launch_ready)
    );

    wire [`MATCH_PE_NUM-1:0] commit_valid;
    wire [`MATCH_PE_NUM-1:0] commit_job_delim;
    wire [`MATCH_PE_NUM-1:0] commit_end_of_job;
    wire [`MATCH_PE_NUM-1:0] commit_has_overlap;
    wire [`MATCH_PE_NUM*(`JOB_LEN_LOG2+1)-1:0] commit_overlap_len;
    wire [`MATCH_PE_NUM*(`JOB_LEN_LOG2+1)-1:0] commit_lit_len;
    wire [`MATCH_PE_NUM*`ADDR_WIDTH-1:0] commit_match_start_addr;
    wire [`MATCH_PE_NUM*(`MAX_MATCH_LEN_LOG2+1)-1:0] commit_match_len;
    wire [`MATCH_PE_NUM*`ADDR_WIDTH-1:0] commit_history_addr;
    wire [`MATCH_PE_NUM-1:0] commit_ready;

    wire [`MATCH_PE_NUM-1:0] single_seq_valid;
    wire [`MATCH_PE_NUM*64-1:0] single_seq;
    wire [`MATCH_PE_NUM-1:0] single_seq_end_of_job;
    wire [`MATCH_PE_NUM-1:0] single_seq_delim;
    wire [`MATCH_PE_NUM-1:0] single_seq_ready;


    wire [`MATCH_PE_NUM-1:0] job_seq_valid;
    wire [`MATCH_PE_NUM*64*4-1:0] job_seq_quad;
    wire [`MATCH_PE_NUM-1:0] job_seq_end_of_job;
    wire [`MATCH_PE_NUM-1:0] job_seq_delim;
    wire [`MATCH_PE_NUM-1:0] job_seq_ready;

    wire [`MATCH_PE_NUM-1:0] job_seq_fifo_out_valid;
    wire [`MATCH_PE_NUM*64*4-1:0] job_seq_fifo_out;
    wire [`MATCH_PE_NUM-1:0] job_seq_fifo_out_end_of_job;
    wire [`MATCH_PE_NUM-1:0] job_seq_fifo_out_delim;
    wire [`MATCH_PE_NUM-1:0] job_seq_fifo_out_ready;

    genvar i;
    generate;
        for(i = 0; i < `MATCH_PE_NUM; i = i + 1) begin: match_pe_inst
            match_pe #(.MATCH_PE_IDX(i)) match_pe_inst (
                .clk(clk),
                .rst_n(rst_n),

                .input_hash_result_valid(job_dispatcher_output_valid[i]),
                .input_head_addr(job_dispatcher_output_head_addr),
                .input_hash_valid_vec(job_dispatcher_output_hash_valid_vec),
                .input_history_addr_vec(job_dispatcher_output_history_addr_vec),
                .input_hash_result_ready(job_dispatcher_output_ready[i]),

                .window_buffer_write_addr(window_buffer_write_addr),
                .window_buffer_write_data(window_buffer_write_data),
                .history_window_buffer_write_enable(history_window_buffer_write_enable),
                .head_window_buffer_write_enable(head_window_buffer_write_enable[i]),

                .job_launch_valid(job_launch_valid[i]),
                .job_delim(job_delim),
                .job_launch_ready(job_launch_ready[i]),

                // commit port
                .commit_valid(commit_valid[i]),
                .commit_job_delim(commit_job_delim[i]),
                .commit_end_of_job(commit_end_of_job[i]),
                .commit_has_overlap(commit_has_overlap[i]),
                .commit_overlap_len(commit_overlap_len[i*(`JOB_LEN_LOG2+1) +: (`JOB_LEN_LOG2+1)]),
                .commit_lit_len(commit_lit_len[i*(`JOB_LEN_LOG2+1) +: (`JOB_LEN_LOG2+1)]),
                .commit_match_start_addr(commit_match_start_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .commit_match_len(commit_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)]),
                .commit_history_addr(commit_history_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .commit_ready(commit_ready[i])
            );

            job_seq_pack job_seq_pack_inst(
                .clk(clk),
                .rst_n(rst_n),

                .input_valid(commit_valid[i]),
                .input_job_delim(commit_job_delim[i]),
                .input_end_of_job(commit_end_of_job[i]),
                .input_has_overlap(commit_has_overlap[i]),
                .input_overlap_len(commit_overlap_len[i*(`JOB_LEN_LOG2+1) +: (`JOB_LEN_LOG2+1)]),
                .input_lit_len(commit_lit_len[i*(`JOB_LEN_LOG2+1) +: (`JOB_LEN_LOG2+1)]),
                .input_match_start_addr(commit_match_start_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .input_match_len(commit_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)]),
                .input_history_addr(commit_history_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .input_ready(commit_ready[i]),

                .output_valid(single_seq_valid[i]),
                .output_seq(single_seq[i*64 +: 64]),
                .output_end_of_job(single_seq_end_of_job[i]),
                .output_delim(single_seq_delim[i]),
                .output_ready(single_seq_ready[i])
            );

            job_concat job_concat_inst(
                .clk(clk),
                .rst_n(rst_n),

                .input_valid(single_seq_valid[i]),
                .input_seq(single_seq[i*64 +: 64]),
                .input_end_of_job(single_seq_end_of_job[i]),
                .input_ready(single_seq_ready[i]),

                .output_valid(job_seq_valid[i]),
                .output_seq_quad(job_seq_quad[i*64*4 +: 64*4]),
                .output_end_of_job(job_seq_end_of_job[i]),
                .output_ready(job_seq_ready[i])
            );

            fifo #(.W(64*4+1), .DEPTH(`JOB_SEQ_FIFO_DEPTH)) job_seq_fifo(
                .clk(clk),
                .rst_n(rst_n),

                .input_valid(job_seq_valid[i]),
                .input_payload({job_seq_quad[i*64*4 +: 64*4], job_seq_end_of_job[i]}),
                .input_ready(job_seq_ready[i]),

                .output_valid(job_seq_fifo_out_valid[i]),
                .output_payload({job_seq_fifo_out[i*64*4 +: 64*4], job_seq_fifo_out_end_of_job[i]}),
                .output_ready(job_seq_fifo_out_ready[i])
            );
        end
    endgenerate

    job_collector job_collector_inst(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(job_seq_fifo_out_valid),
        .input_seq_quad(job_seq_fifo_out),
        .input_end_of_job(job_seq_fifo_out_end_of_job),
        .input_delim(job_seq_fifo_out_delim),
        .input_ready(job_seq_fifo_out_ready),


        .output_valid(output_valid),
        .output_seq_quad(output_seq_quad),
        .output_delim(output_delim),
        .output_ready(output_ready)
    );

endmodule