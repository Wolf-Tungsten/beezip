`include "parameters.vh"
`include "log.vh"

module match_pe #(parameter MATCH_PE_IDX=0) (

    input wire clk,
    input wire rst_n,

    input wire input_hash_result_valid,
    input wire [`ADDR_WIDTH-1:0] input_head_addr,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_hash_valid_vec,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
    output wire input_hash_result_ready,

    input wire [`ADDR_WIDTH-1:0] window_buffer_write_addr,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data,
    input wire history_window_buffer_write_enable,
    input wire head_window_buffer_write_enable,

    input wire job_launch_valid,
    input wire job_delim,
    output wire job_launch_ready,

    output wire commit_valid,
    output wire commit_job_delim,
    output wire commit_end_of_job,
    output wire commit_has_overlap,
    output wire [`JOB_LEN_LOG2+1-1:0] commit_overlap_len,
    output wire [`JOB_LEN_LOG2+1-1:0] commit_lit_len,
    output wire [`ADDR_WIDTH-1:0] commit_match_start_addr,
    output wire [`MAX_MATCH_LEN_LOG2+1-1:0] commit_match_len,
    output wire [`ADDR_WIDTH-1:0] commit_history_addr,
    input wire commit_ready
);

    reg [`ADDR_WIDTH-1:0] window_buffer_write_addr_reg;
    reg [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data_reg;
    reg history_window_buffer_write_enable_reg;
    reg head_window_buffer_write_enable_reg;

    always @(posedge clk) begin
        if (~rst_n) begin
            history_window_buffer_write_enable_reg <= `TD 0;
            head_window_buffer_write_enable_reg <= `TD 0;
        end else begin
            history_window_buffer_write_enable_reg <= `TD history_window_buffer_write_enable;
            head_window_buffer_write_enable_reg <= `TD head_window_buffer_write_enable;
            window_buffer_write_addr_reg <= `TD window_buffer_write_addr;
            window_buffer_write_data_reg <= `TD window_buffer_write_data;
        end
    end

    wire [`MATCH_PU_NUM-1:0] pu_req_valid;
    wire [`ADDR_WIDTH-1:0] pu_req_head_addr;
    wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] pu_req_hist_addr;
    wire [`MATCH_PU_NUM-1:0] pu_req_is_ext;
    wire [`MATCH_PU_NUM-1:0] pu_req_ready;

    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] slot_resp_valid;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`TABLE_ADDR_TAG_BITS-1:0] slot_resp_addr_tag;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*(`MAX_MATCH_LEN_LOG2+1)-1:0] slot_resp_match_len;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] slot_resp_extp;

    intra_pe_coordinator #(.MATCH_PE_IDX(MATCH_PE_IDX)) intra_pe_coordinator_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_hash_result_valid(input_hash_result_valid),
        .input_head_addr(input_head_addr),
        .input_hash_valid_vec(input_hash_valid_vec),
        .input_history_addr_vec(input_history_addr_vec),
        .input_hash_result_ready(input_hash_result_ready),

        .job_launch_valid(job_launch_valid),
        .job_delim(job_delim),
        .job_launch_ready(job_launch_ready),

        .pu_req_valid(pu_req_valid),
        .pu_req_head_addr(pu_req_head_addr),
        .pu_req_hist_addr(pu_req_hist_addr),
        .pu_req_is_ext(pu_req_is_ext),
        .pu_req_ready(pu_req_ready),

        .slot_resp_valid(slot_resp_valid),
        .slot_resp_addr_tag(slot_resp_addr_tag),
        .slot_resp_match_len(slot_resp_match_len),
        .slot_resp_extp(slot_resp_extp),

        .commit_valid(commit_valid),
        .commit_job_delim(commit_job_delim),
        .commit_end_of_job(commit_end_of_job),
        .commit_has_overlap(commit_has_overlap),
        .commit_overlap_len(commit_overlap_len),
        .commit_lit_len(commit_lit_len),
        .commit_match_start_addr(commit_match_start_addr),
        .commit_match_len(commit_match_len),
        .commit_history_addr(commit_history_addr),
        .commit_ready(commit_ready)
    );

    wire [`MATCH_PU_NUM-1:0] sn_output_valid;
    wire [`MATCH_PU_NUM*`MATCH_PU_NUM_LOG2-1:0] sn_output_slot_idx;
    wire [`MATCH_PU_NUM-1:0] sn_output_is_ext;
    wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] sn_output_head_addr;
    wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] sn_output_hist_addr;
    wire [`MATCH_PU_NUM-1:0] sn_output_ready;

    switch_network #(.SWITCH_IDX_WIDTH(`MATCH_PU_NUM_LOG2)) switch_network_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid_0(pu_req_valid[0]),
        .input_is_ext_0(pu_req_is_ext[0]),
        .input_head_addr_0(pu_req_head_addr),
        .input_history_addr_0(pu_req_hist_addr[0 +: `ADDR_WIDTH]),
        .input_ready_0(pu_req_ready[0]),

        .input_valid_1(pu_req_valid[1]),
        .input_is_ext_1(pu_req_is_ext[1]),
        .input_head_addr_1(pu_req_head_addr),
        .input_history_addr_1(pu_req_hist_addr[1*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .input_ready_1(pu_req_ready[1]),

        .input_valid_2(pu_req_valid[2]),
        .input_is_ext_2(pu_req_is_ext[2]),
        .input_head_addr_2(pu_req_head_addr),
        .input_history_addr_2(pu_req_hist_addr[2*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .input_ready_2(pu_req_ready[2]),

        .input_valid_3(pu_req_valid[3]),
        .input_is_ext_3(pu_req_is_ext[3]),
        .input_head_addr_3(pu_req_head_addr),
        .input_history_addr_3(pu_req_hist_addr[3*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .input_ready_3(pu_req_ready[3]),

        .output_valid_0(sn_output_valid[0]),
        .output_slot_idx_0(sn_output_slot_idx[0 +: `MATCH_PU_NUM_LOG2]),
        .output_is_ext_0(sn_output_is_ext[0]),
        .output_head_addr_0(sn_output_head_addr[0 +: `ADDR_WIDTH]),
        .output_history_addr_0(sn_output_hist_addr[0 +: `ADDR_WIDTH]),
        .output_ready_0(sn_output_ready[0]),

        .output_valid_1(sn_output_valid[1]),
        .output_slot_idx_1(sn_output_slot_idx[1*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_is_ext_1(sn_output_is_ext[1]),
        .output_head_addr_1(sn_output_head_addr[1*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_history_addr_1(sn_output_hist_addr[1*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_ready_1(sn_output_ready[1]),

        .output_valid_2(sn_output_valid[2]),
        .output_slot_idx_2(sn_output_slot_idx[2*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_is_ext_2(sn_output_is_ext[2]),
        .output_head_addr_2(sn_output_head_addr[2*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_history_addr_2(sn_output_hist_addr[2*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_ready_2(sn_output_ready[2]),

        .output_valid_3(sn_output_valid[3]),
        .output_slot_idx_3(sn_output_slot_idx[3*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_is_ext_3(sn_output_is_ext[3]),
        .output_head_addr_3(sn_output_head_addr[3*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_history_addr_3(sn_output_hist_addr[3*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .output_ready_3(sn_output_ready[3])
    );


    wire [`MATCH_PU_NUM-1:0] pu_resp_bus_valid;
    wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] pu_resp_bus_addr;
    wire [`MATCH_PU_NUM*`MATCH_PU_NUM_LOG2-1:0] pu_resp_bus_slot_idx;
    wire [`MATCH_PU_NUM*(`MAX_MATCH_LEN_LOG2+1)-1:0] pu_resp_bus_match_len;
    wire [`MATCH_PU_NUM-1:0] pu_resp_bus_extp;
    wire [`MATCH_PU_NUM-1:0] pu_resp_bus_is_burst;
    wire [`MATCH_PU_NUM-1:0] pu_resp_bus_read_unsafe;


    match_pu_result_bus match_pu_result_bus_inst(
        .clk(clk),
        .rst_n(rst_n),

        .pu_resp_bus_valid(pu_resp_bus_valid),
        .pu_resp_bus_addr(pu_resp_bus_addr),
        .pu_resp_bus_slot_idx(pu_resp_bus_slot_idx),
        .pu_resp_bus_match_len(pu_resp_bus_match_len),
        .pu_resp_bus_extp(pu_resp_bus_extp),

        .slot_resp_valid(slot_resp_valid),
        .slot_resp_addr_tag(slot_resp_addr_tag),
        .slot_resp_match_len(slot_resp_match_len), 
        .slot_resp_extp(slot_resp_extp)
    );

    localparam [`MATCH_PU_NUM * 8 - 1:0] PU_SIZE_LOG2= {8'd`MATCH_PU_3_SIZE_LOG2, 8'd`MATCH_PU_2_SIZE_LOG2, 8'd`MATCH_PU_1_SIZE_LOG2, 8'd`MATCH_PU_0_SIZE_LOG2};
    genvar i;
    generate;
        for(i = 0; i < `MATCH_PU_NUM; i = i + 1)begin: construct_match_pu
            match_pu #(.HISTORY_SIZE_LOG2(PU_SIZE_LOG2[i*8 +: 8]), 
            .MATCH_PE_IDX(MATCH_PE_IDX), .MATCH_PU_IDX(i)) match_pu_inst (
                .clk(clk),
                .rst_n(rst_n),

                .input_valid(sn_output_valid[i]),
                .input_slot_idx(sn_output_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
                .input_is_burst(sn_output_is_ext[i]),
                .input_head_addr(sn_output_head_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .input_history_addr(sn_output_hist_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .input_ready(sn_output_ready[i]),

                .history_window_buffer_write_enable(history_window_buffer_write_enable_reg),
                .head_window_buffer_write_enable(head_window_buffer_write_enable_reg),
                .window_buffer_write_addr(window_buffer_write_addr_reg),
                .window_buffer_write_data(window_buffer_write_data_reg),

                // connect result bus
                .output_valid(pu_resp_bus_valid[i]),
                .output_addr(pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .output_slot_idx(pu_resp_bus_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
                .output_match_len(pu_resp_bus_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)]),
                .output_extp(pu_resp_bus_extp[i]),
                .output_is_burst(pu_resp_bus_is_burst[i]),
                .output_read_unsafe(pu_resp_bus_read_unsafe[i])
            );
        end
    endgenerate

    always @(posedge clk) begin
        `ifdef MATCH_PU_LOG
            integer i;
            for(i = 0; i < `MATCH_PU_NUM; i = i + 1) begin
                if(pu_req_valid[i] && pu_req_ready[i]) begin
                    $display("[SwitchNetwork] PE %d SN port %d recv req head_addr=%d, history_addr=%d, is_ext=%d", MATCH_PE_IDX, i, pu_req_head_addr, pu_req_hist_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH], pu_req_is_ext[i]);
                end
            end
            for(i = 0; i < `MATCH_PU_NUM; i = i + 1) begin
                if(sn_output_valid[i] && sn_output_ready[i]) begin
                    $display("[MatchPU-Req] PE %d PU %d recv req slot_idx=%d, head_addr=%d, history_addr=%d, is_ext=%d", MATCH_PE_IDX, i,sn_output_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2], sn_output_head_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH], sn_output_hist_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH], sn_output_is_ext[i]);
                end
            end
            for(i = 0; i < `MATCH_PU_NUM; i = i + 1) begin
                if(pu_resp_bus_valid[i]) begin
                    if(pu_resp_bus_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)] == 0) begin
                        if(pu_resp_bus_read_unsafe[i]) begin
                            $display("[MatchPU-Resp] PE %d PU %d send resp slot_idx=%d, head_addr=%d,  unsafe read", MATCH_PE_IDX, i, pu_resp_bus_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2], pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]);
                        end else if (pu_resp_bus_is_burst[i]) begin
                            $display("[MatchPU-Resp] PE %d PU %d send resp slot_idx=%d, head_addr=%d,  burst read", MATCH_PE_IDX, i, pu_resp_bus_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2], pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]); 
                        end else begin
                            if(pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH] != 21676 && 
                            pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH] != 28667) begin
                                $display("[MatchPU-Resp] !!! PE %d PU %d send resp head_addr=%d, slot_idx=%d, match_len=%d, extp=%d", MATCH_PE_IDX, i, pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH], pu_resp_bus_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2], pu_resp_bus_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)], pu_resp_bus_extp[i]);
                                //$finish;
                            end
                        end
                    end else begin
                        $display("[MatchPU-Resp] PE %d PU %d send resp slot_idx=%d, head_addr=%d,  match_len=%d, extp=%d", MATCH_PE_IDX, i, pu_resp_bus_slot_idx[i*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2], pu_resp_bus_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH],  pu_resp_bus_match_len[i*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)], pu_resp_bus_extp[i]);
                    end
                end
            end
        `endif
    end

endmodule