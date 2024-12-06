`include "parameters.vh"
`include "util.vh"

module lazy_summary_pipeline (
    input wire clk,
    
    input wire i_match_done,
    input wire [`JOB_LEN_LOG2-1:0] i_match_head_ptr,
    input wire [`JOB_LEN_LOG2-1:0] i_seq_head_ptr,
    input wire i_delim,
    input wire [`LAZY_LEN-1:0] i_match_valid,
    input wire [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] i_match_len,
    input wire [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] i_offset,

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

    localparam GAIN_BITS = `MATCH_LEN_WIDTH + 2;

    // s0 计算 ll，offset_bits，不包含 offset_bits 的 gain
    reg s0_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s0_seq_head_ptr_reg;
    reg s0_delim_reg;
    reg [`LAZY_LEN-1:0] s0_match_valid_reg;
    reg [`LAZY_LEN*(`JOB_LEN_LOG2+1)-1:0] s0_ll_reg;
    reg [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] s0_match_len_reg;
    reg [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] s0_offset_reg;
    reg [`LAZY_LEN*`SEQ_OFFSET_BITS_LOG2-1:0] s0_offset_bits_reg;
    reg signed [`LAZY_LEN*GAIN_BITS-1:0] s0_gain_reg;

    wire [`LAZY_LEN * `SEQ_OFFSET_BITS_LOG2-1:0] reversed_offset_bits;
    wire [`LAZY_LEN * `SEQ_OFFSET_BITS_LOG2-1:0] s0_offset_bits;
    function  automatic  [`SEQ_OFFSET_BITS-1:0] reverse_offset (
        input [`SEQ_OFFSET_BITS-1:0] offset
    );
        integer i;
        for(i = 0; i < `SEQ_OFFSET_BITS; i = i + 1) begin
        reverse_offset[i] = offset[`SEQ_OFFSET_BITS-1-i];
        end
    endfunction
    genvar g_i;
    generate
        for(g_i = 0; g_i < `LAZY_LEN; g_i = g_i + 1) begin: OFFSET_BITS_GEN
        /* verilator lint_off PINCONNECTEMPTY */
        priority_encoder #(`SEQ_OFFSET_BITS) offset_bits_enc (
            .input_vec(reverse_offset(`VEC_SLICE(i_offset, g_i, `SEQ_OFFSET_BITS))),
            .output_valid(),
            .output_index(`VEC_SLICE(reversed_offset_bits, g_i, `SEQ_OFFSET_BITS_LOG2))
        );
        assign `VEC_SLICE(s0_offset_bits, g_i, `SEQ_OFFSET_BITS_LOG2) = `SEQ_OFFSET_BITS - `VEC_SLICE(reversed_offset_bits, g_i, `SEQ_OFFSET_BITS_LOG2);
        end
    endgenerate
    
    always @(posedge clk) begin
        s0_match_done_reg <= i_match_done;
        s0_seq_head_ptr_reg <= i_seq_head_ptr;
        s0_delim_reg <= i_delim;
        s0_match_valid_reg <= i_match_valid;
        s0_match_len_reg <= i_match_len;
        s0_offset_bits_reg <= s0_offset_bits;
        s0_offset_reg <= i_offset;
        for(integer i = 0; i < `LAZY_LEN; i = i + 1) begin
            `VEC_SLICE(s0_ll_reg, i, `JOB_LEN_LOG2+1) <= `ZERO_EXTEND(i_match_head_ptr, `JOB_LEN_LOG2+1) - `ZERO_EXTEND(i_seq_head_ptr, `JOB_LEN_LOG2+1) + i[`JOB_LEN_LOG2+1-1:0];
            `VEC_SLICE(s0_gain_reg, i, GAIN_BITS) <= `ZERO_EXTEND({`VEC_SLICE(i_match_len, i, `MATCH_LEN_WIDTH), 2'b0}, GAIN_BITS)
            + (GAIN_BITS)'(4 * (`LAZY_LEN - i)); // 匹配长度最小4, 4*4 最小为16； ml最大为1024, 最大4KB，12位，
        end
    end

    
    // s0 到 s1 计算完整的 gain、move_forward
    reg s1_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s1_seq_head_ptr_reg;
    reg s1_delim_reg;
    reg [`LAZY_LEN-1:0] s1_match_valid_reg;
    reg [`LAZY_LEN*(`JOB_LEN_LOG2+1)-1:0] s1_ll_reg;
    reg [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] s1_match_len_reg;
    reg [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] s1_offset_reg;
    reg [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] s1_move_forward_reg; 
    reg signed [`LAZY_LEN*GAIN_BITS-1:0] s1_gain_reg;

    always @(posedge clk) begin
        s1_match_done_reg <= s0_match_done_reg;
        s1_seq_head_ptr_reg <= s0_seq_head_ptr_reg;
        s1_delim_reg <= s0_delim_reg;
        s1_match_valid_reg <= s0_match_valid_reg;
        s1_match_len_reg <= s0_match_len_reg;
        s1_offset_reg <= s0_offset_reg;
        s1_ll_reg <= s0_ll_reg;
        for(integer i = 0; i < `LAZY_LEN; i = i + 1) begin
            `VEC_SLICE(s1_gain_reg, i, GAIN_BITS) <= s1_match_valid_reg[i] ? (`VEC_SLICE(s0_gain_reg, i, GAIN_BITS)
            - `ZERO_EXTEND(`VEC_SLICE(s0_offset_bits_reg, i, `SEQ_OFFSET_BITS_LOG2), GAIN_BITS)) : -`WINDOW_LOG;
            `VEC_SLICE(s1_move_forward_reg, i, `MATCH_LEN_WIDTH) <= `VEC_SLICE(s0_match_len_reg, i, `MATCH_LEN_WIDTH) + 
            `ZERO_EXTEND(`VEC_SLICE(s0_ll_reg, i, `JOB_LEN_LOG2+1), `MATCH_LEN_WIDTH); 
        end
    end

    localparam BEST_LAYER = $clog2(`LAZY_LEN);
    reg best_match_done_reg[BEST_LAYER-1:0];
    reg [`JOB_LEN_LOG2-1:0] best_seq_head_ptr_reg[BEST_LAYER-1:0];
    reg best_delim_reg[BEST_LAYER-1:0];
    reg best_match_valid_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];
    reg [`JOB_LEN_LOG2+1-1:0] best_ll_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];
    reg [`MATCH_LEN_WIDTH-1:0] best_match_len_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];
    reg [`SEQ_OFFSET_BITS-1:0] best_offset_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];
    reg signed [GAIN_BITS-1:0] best_gain_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];
    reg [`MATCH_LEN_WIDTH-1:0] best_move_forward_reg[BEST_LAYER-1:0][`LAZY_LEN-1:0];

    always @(posedge clk) begin
        best_match_done_reg[0] <= s1_match_done_reg;
        best_seq_head_ptr_reg[0] <= s1_seq_head_ptr_reg;
        best_delim_reg[0] <= s1_delim_reg;
        for(integer i = 0; i < `LAZY_LEN / 2; i = i + 1) begin
            best_match_valid_reg[0][i] = s1_match_valid_reg[i * 2] | s1_match_valid_reg[i * 2 + 1];
            if(`VEC_SLICE(s1_gain_reg, i * 2, GAIN_BITS) > `VEC_SLICE(s1_gain_reg, i * 2 + 1, GAIN_BITS)) begin //s1_gain_reg[i * 2] > s1_gain_reg[i * 2 + 1]
                best_ll_reg[0][i] = `VEC_SLICE(s1_ll_reg, i * 2, `JOB_LEN_LOG2+1);
                best_match_len_reg[0][i] = `VEC_SLICE(s1_match_len_reg, i * 2, `MATCH_LEN_WIDTH);
                best_offset_reg[0][i] = `VEC_SLICE(s1_offset_reg, i * 2, `SEQ_OFFSET_BITS);
                best_gain_reg[0][i] = `VEC_SLICE(s1_gain_reg, i * 2, GAIN_BITS);
                best_move_forward_reg[0][i] = `VEC_SLICE(s1_move_forward_reg, i * 2, `MATCH_LEN_WIDTH);
            end else begin
                best_ll_reg[0][i] = `VEC_SLICE(s1_ll_reg, i * 2 + 1, `JOB_LEN_LOG2+1);
                best_match_len_reg[0][i] = `VEC_SLICE(s1_match_len_reg, i * 2 + 1, `MATCH_LEN_WIDTH);
                best_offset_reg[0][i] = `VEC_SLICE(s1_offset_reg, i * 2 + 1, `SEQ_OFFSET_BITS);
                best_gain_reg[0][i] = `VEC_SLICE(s1_gain_reg, i * 2 + 1, GAIN_BITS);
                best_move_forward_reg[0][i] = `VEC_SLICE(s1_move_forward_reg, i * 2 + 1, `MATCH_LEN_WIDTH);
            end
        end
        for(integer layer = 1; layer < BEST_LAYER; layer = layer + 1) begin
            best_match_done_reg[layer] <= best_match_done_reg[layer-1];
            best_seq_head_ptr_reg[layer] <= best_seq_head_ptr_reg[layer-1];
            best_delim_reg[layer] <= best_delim_reg[layer-1];
            for(integer i = 0; i < `LAZY_LEN / (2**(layer+1)); i = i+1) begin
                best_match_valid_reg[layer][i] = best_match_valid_reg[layer-1][i * 2] | best_match_valid_reg[layer-1][i * 2 + 1];
                if(best_gain_reg[layer-1][i * 2] > best_gain_reg[layer-1][i * 2 + 1]) begin
                    best_ll_reg[layer][i] = best_ll_reg[layer-1][i * 2];
                    best_match_len_reg[layer][i] = best_match_len_reg[layer-1][i * 2];
                    best_offset_reg[layer][i] = best_offset_reg[layer-1][i * 2];
                    best_gain_reg[layer][i] = best_gain_reg[layer-1][i * 2];
                    best_move_forward_reg[layer][i] = best_move_forward_reg[layer-1][i * 2];
                end else begin
                    best_ll_reg[layer][i] = best_ll_reg[layer-1][i * 2 + 1];
                    best_match_len_reg[layer][i] = best_match_len_reg[layer-1][i * 2 + 1];
                    best_offset_reg[layer][i] = best_offset_reg[layer-1][i * 2 + 1];
                    best_gain_reg[layer][i] = best_gain_reg[layer-1][i * 2 + 1];
                    best_move_forward_reg[layer][i] = best_move_forward_reg[layer-1][i * 2 + 1];
                end
            end
        end
    end

    // best_reg[LAYER-1] 到 s3 计算 overlap、eoj
    reg s3_match_done_reg;
    reg [`JOB_LEN_LOG2-1:0] s3_seq_head_ptr_reg;
    reg [`JOB_LEN_LOG2+1-1:0] s3_ll_reg;
    reg [`MATCH_LEN_WIDTH-1:0] s3_ml_reg;
    reg [`SEQ_OFFSET_BITS-1:0] s3_offset_reg;
    reg s3_eoj_reg;
    reg [`SEQ_ML_BITS-1:0] s3_overlap_len_reg;
    reg s3_move_to_next_job_reg;
    reg [`JOB_LEN_LOG2-1:0] s3_move_forward_reg;
    reg s3_delim_reg;


    wire signed [`MATCH_LEN_WIDTH+1-1:0] s3_overlap_len;
    assign s3_overlap_len = best_move_forward_reg[BEST_LAYER-1][0] + `ZERO_EXTEND(best_seq_head_ptr_reg[BEST_LAYER-1], `MATCH_LEN_WIDTH) - `JOB_LEN;
    always @(posedge clk) begin
        s3_match_done_reg <= best_match_done_reg[BEST_LAYER-1];
        s3_seq_head_ptr_reg <= best_seq_head_ptr_reg[BEST_LAYER-1];
        s3_delim_reg <= best_delim_reg[BEST_LAYER-1];
        if (s3_overlap_len >= 0) begin
            if(best_delim_reg[BEST_LAYER-1]) begin
                s3_ll_reg <= `JOB_LEN - `ZERO_EXTEND(best_seq_head_ptr_reg[BEST_LAYER-1], `JOB_LEN_LOG2+1);
                s3_ml_reg <= '0;
                s3_offset_reg <= '0;
                s3_eoj_reg <= 1'b1;
                s3_overlap_len_reg <= '0;
                s3_move_to_next_job_reg <= 1'b1;
                s3_move_forward_reg <= '0;
            end else begin
                s3_ll_reg <= best_ll_reg[BEST_LAYER-1][0];
                s3_ml_reg <= best_match_len_reg[BEST_LAYER-1][0]; //s2_match_len_reg;
                s3_offset_reg <= best_offset_reg[BEST_LAYER-1][0]; //s2_offset_reg;
                s3_eoj_reg <= 1'b1;
                s3_overlap_len_reg <= s3_overlap_len[`SEQ_ML_BITS-1:0];
                s3_move_to_next_job_reg <= 1'b1;
                s3_move_forward_reg <= '0;
            end
        end else begin
            s3_ll_reg <= best_ll_reg[BEST_LAYER-1][0]; //s2_ll_reg;
            s3_ml_reg <= best_match_len_reg[BEST_LAYER-1][0]; //s2_match_len_reg;
            s3_offset_reg <= best_offset_reg[BEST_LAYER-1][0]; //s2_offset_reg;
            s3_eoj_reg <= 1'b0;
            s3_overlap_len_reg <= '0;
            s3_move_to_next_job_reg <= 1'b0;
            s3_move_forward_reg <= best_move_forward_reg[BEST_LAYER-1][0][`JOB_LEN_LOG2-1:0]; //s2_move_forward_reg;
        end
    end

    assign o_summary_done = s3_match_done_reg;
    assign o_seq_head_ptr = s3_seq_head_ptr_reg;
    assign o_summary_ll = `ZERO_EXTEND(s3_ll_reg, `SEQ_LL_BITS);
    assign o_summary_ml = s3_ml_reg;
    assign o_summary_offset = s3_offset_reg;
    assign o_summary_delim = s3_delim_reg;
    assign o_summary_eoj = s3_eoj_reg;
    assign o_summary_overlap_len = s3_overlap_len_reg;
    assign o_move_to_next_job = s3_move_to_next_job_reg;
    assign o_move_forward = s3_move_forward_reg;
    
endmodule