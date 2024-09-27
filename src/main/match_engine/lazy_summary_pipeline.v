`include "parameters.vh"
`include "util.vh"

module lazy_summary_pipeline (
    input wire clk,
    
    input wire i_match_done,
    input wire [`JOB_LEN_LOG2-1:0] i_match_head_ptr,
    input wire [`JOB_LEN_LOG2-1:0] i_seq_head_ptr,
    input wire i_delim,
    input wire [`LAZY_MATCH_LEN-1:0] i_match_valid,
    input wire [`LAZY_MATCH_LEN*`MATCH_LEN_WIDTH-1:0] i_match_len,
    input wire [`LAZY_MATCH_LEN*`SEQ_OFFSET_BITS-1:0] i_offset,
    input wire [`LAZY_MATCH_LEN*`SEQ_OFFSET_BITS_LOG2-1:0] i_offset_bits,

    output wire o_summary_done,
    output wire [`JOB_LEN_LOG2-1:0] o_seq_head_ptr,
    output wire [`SEQ_LL_BITS-1:0] o_summary_ll,
    output wire [`SEQ_ML_BITS-1:0] o_summary_ml,
    output wire [`SEQ_OFFSET_BITS-1:0] o_summary_offset,
    output wire o_summary_delim,
    output wire o_summary_eoj,
    output wire [`SEQ_ML_BITS-1:0] o_summary_overlap_len,
    output wire o_move_to_next_job,
    output wire [`JOB_LEN_LOG2-1:0] o_move_forward
);

    localparam GAIN_BITS = 32;
    
    // 输入到 s1 计算 ll、gain
    reg s1_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s1_seq_head_ptr_reg;
    reg s1_delim_reg;
    reg [`LAZY_MATCH_LEN-1:0] s1_match_valid_reg;
    reg [`LAZY_MATCH_LEN*`JOB_LEN_LOG2-1:0] s1_ll_reg;
    reg [`LAZY_MATCH_LEN*`MATCH_LEN_WIDTH-1:0] s1_match_len_reg;
    reg [`LAZY_MATCH_LEN*`SEQ_OFFSET_BITS-1:0] s1_offset_reg;
    reg [`LAZY_MATCH_LEN*(`MATCH_LEN_WIDTH+1)-1:0] s1_move_forward_reg; 
    reg signed [`LAZY_MATCH_LEN*GAIN_BITS-1:0] s1_gain_reg;

    always @(posedge clk) begin
        s1_match_done_reg <= i_match_done;
        s1_seq_head_ptr_reg <= i_seq_head_ptr;
        s1_delim_reg <= i_delim;
        s1_match_valid_reg <= i_match_valid;
        s1_match_len_reg <= i_match_len;
        s1_offset_reg <= i_offset;
        for(integer i = 0; i < `LAZY_MATCH_LEN; i = i + 1) begin
            `VEC_SLICE(s1_gain_reg, i, GAIN_BITS) <= `ZERO_EXTEND({`VEC_SLICE(i_match_len, i, `MATCH_LEN_WIDTH), 2'b0}, GAIN_BITS)
            + {4 * (`LAZY_MATCH_LEN - i)}[GAIN_BITS-1:0] 
            - `ZERO_EXTEND(`VEC_SLICE(i_offset_bits, i, `SEQ_OFFSET_BITS_LOG2), GAIN_BITS);
            `VEC_SLICE(s1_ll_reg, i, `JOB_LEN_LOG2) <= i_match_head_ptr - i_seq_head_ptr + i[`JOB_LEN_LOG2-1:0];
            `VEC_SLICE(s1_move_forward_reg, i, `MATCH_LEN_WIDTH+1) <= `VEC_SLICE(i_match_len, i, `MATCH_LEN_WIDTH) + 
            `ZERO_EXTEND({i_match_head_ptr - i_seq_head_ptr + i[`JOB_LEN_LOG2-1:0]}, `MATCH_LEN_WIDTH+1); 
        end
    end

    // s1 到 s2 选择最佳匹配
    reg best_valid;
    reg [`JOB_LEN_LOG2-1:0] best_ll;
    reg [`MATCH_LEN_WIDTH-1:0] best_ml;
    reg [`SEQ_OFFSET_BITS-1:0] best_offset;
    reg signed [GAIN_BITS-1:0] best_gain;
    reg [`MATCH_LEN_WIDTH+1-1:0] best_move_forward;
    always @(*) begin
        best_valid = s1_match_valid_reg[0];
        best_ll = `VEC_SLICE(s1_ll_reg, 0, `JOB_LEN_LOG2);
        best_ml = `VEC_SLICE(s1_match_len_reg, 0, `MATCH_LEN_WIDTH);
        best_offset = `VEC_SLICE(s1_offset_reg, 0, `SEQ_OFFSET_BITS);
        best_gain = `VEC_SLICE(s1_gain_reg, 0, GAIN_BITS);
        best_move_forward = `VEC_SLICE(s1_move_forward_reg, 0, `MATCH_LEN_WIDTH+1);
        for(integer i = 1; i < `LAZY_MATCH_LEN; i = i + 1) begin
            if(s1_match_valid_reg[i]) begin
                if(~best_valid | (`VEC_SLICE(s1_gain_reg, i, GAIN_BITS) > best_gain)) begin
                    best_valid = 1'b1;
                    best_ll = `VEC_SLICE(s1_ll_reg, i, `JOB_LEN_LOG2);
                    best_ml = `VEC_SLICE(s1_match_len_reg, i, `MATCH_LEN_WIDTH);
                    best_offset = `VEC_SLICE(s1_offset_reg, i, `SEQ_OFFSET_BITS);
                    best_gain = `VEC_SLICE(s1_gain_reg, i, GAIN_BITS);
                    best_move_forward = `VEC_SLICE(s1_move_forward_reg, i, `MATCH_LEN_WIDTH+1);
                end
            end
        end
    end

    reg s2_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s2_seq_head_ptr_reg;
    reg [`JOB_LEN_LOG2-1:0] s2_ll_reg;
    reg s2_delim_reg;
    reg [`MATCH_LEN_WIDTH-1:0] s2_match_len_reg;
    reg [`SEQ_OFFSET_BITS-1:0] s2_offset_reg;
    reg [`MATCH_LEN_WIDTH+1-1:0] s2_move_forward_reg;
    always @(posedge clk) begin
        s2_match_done_reg <= s1_match_done_reg;
        s2_seq_head_ptr_reg <= s1_seq_head_ptr_reg;
        s2_ll_reg <= best_ll;
        s2_delim_reg <= s1_delim_reg;
        s2_match_len_reg <= best_ml;
        s2_offset_reg <= best_offset;
        s2_move_forward_reg <= best_move_forward;
    end

    // s2 到 s3 计算 overlap、eoj
    reg s3_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s3_seq_head_ptr_reg;
    reg [`JOB_LEN_LOG2-1:0] s3_ll_reg;
    reg [`MATCH_LEN_WIDTH-1:0] s3_ml_reg;
    reg [`SEQ_OFFSET_BITS-1:0] s3_offset_reg;
    reg s3_eoj_reg;
    reg [`SEQ_ML_BITS-1:0] s3_overlap_len_reg;
    reg s3_move_to_next_job_reg;
    reg [`JOB_LEN_LOG2-1:0] s3_move_forward_reg;
    reg s3_delim_reg;


    wire signed [`MATCH_LEN_WIDTH+2-1:0] s3_overlap_len;
    assign s3_overlap_len = s2_move_forward_reg + `ZERO_EXTEND(s2_seq_head_ptr_reg, `MATCH_LEN_WIDTH+1) - `JOB_LEN;
    always @(posedge clk) begin
        s3_match_done_reg <= s2_match_done_reg;
        s3_seq_head_ptr_reg <= s2_seq_head_ptr_reg;
        s3_delim_reg <= s2_delim_reg;
        if (s3_overlap_len >= 0) begin
            if(s2_delim_reg) begin
                s3_ll_reg <= `JOB_LEN - s2_seq_head_ptr_reg;
                s3_ml_reg <= '0;
                s3_offset_reg <= '0;
                s3_eoj_reg <= 1'b1;
                s3_overlap_len_reg <= '0;
                s3_move_to_next_job_reg <= 1'b1;
                s3_move_forward_reg <= '0;
            end else begin
                s3_ll_reg <= s2_ll_reg;
                s3_ml_reg <= s2_match_len_reg;
                s3_offset_reg <= s2_offset_reg;
                s3_eoj_reg <= 1'b1;
                s3_overlap_len_reg <= s3_overlap_len[`SEQ_ML_BITS-1:0];
                s3_move_to_next_job_reg <= 1'b1;
                s3_move_forward_reg <= '0;
            end
        end else begin
            s3_ll_reg <= s2_ll_reg;
            s3_ml_reg <= s2_match_len_reg;
            s3_offset_reg <= s2_offset_reg;
            s3_eoj_reg <= 1'b0;
            s3_overlap_len_reg <= '0;
            s3_move_to_next_job_reg <= 1'b0;
            s3_move_forward_reg <= s2_move_forward_reg[`JOB_LEN_LOG2-1:0];
        end
    end

    assign o_summary_done = s3_match_done_reg;
    assign o_seq_head_ptr = s3_seq_head_ptr_reg;
    assign o_summary_ll = `ZERO_EXTEND(s3_ll_reg, `SEQ_LL_BITS);
    assign o_summary_ml = s3_ml_reg;
    assign o_summary_offset = s3_offset_reg;
    assign o_summary_delim = s2_delim_reg;
    assign o_summary_eoj = s3_eoj_reg;
    assign o_summary_overlap_len = s3_overlap_len_reg;
    assign o_move_to_next_job = s3_move_to_next_job_reg;
    assign o_move_forward = s3_move_forward_reg;
    
endmodule