`include "parameters.vh"
`include "util.vh"

module handle_gap_process (

    input wire [`SEQ_LL_BITS-1:0] buf_seq_ll,
    input wire [`SEQ_ML_BITS-1:0] buf_seq_ml,
    input wire [`SEQ_OFFSET_BITS-1:0] buf_seq_offset,
    input wire [`SEQ_LL_BITS-1:0] buf_seq_len,
    input wire [`SEQ_ML_BITS-1:0] buf_seq_overlap,

    input wire [`SEQ_LL_BITS-1:0] next_seq_ll,
    input wire [`SEQ_ML_BITS-1:0] next_seq_ml,
    input wire [`SEQ_OFFSET_BITS-1:0] next_seq_offset,
    input wire [`SEQ_LL_BITS-1:0] next_seq_len,
    input wire next_seq_eoj,
    input wire next_seq_delim,
    input wire [`SEQ_ML_BITS-1:0] next_seq_overlap,
    input wire next_seq_ll_gte_mml,
    input wire next_seq_gap_gt_0,
    input wire next_seq_gap_overlap_eq_0,
    input wire next_seq_0_lt_overlap_lt_job_len,
    input wire next_seq_job_len_lte_overlap,

    output reg [`SEQ_LL_BITS-1:0] next_buf_seq_ll,
    output reg [`SEQ_ML_BITS-1:0] next_buf_seq_ml,
    output reg [`SEQ_OFFSET_BITS-1:0] next_buf_seq_offset,
    output reg [`SEQ_LL_BITS-1:0] next_buf_seq_len,
    output reg [`SEQ_ML_BITS-1:0] next_buf_seq_overlap,
    output reg next_buf_delim,

    output reg turn_to_empty,
    output reg turn_to_normal,
    output reg turn_to_flush,
    output reg turn_to_handle_gap,
    output reg turn_to_handle_overlap,
    output reg turn_to_skip_next_job
);

    always @(*) begin
        next_buf_seq_ll = next_seq_ll + buf_seq_ll;
        next_buf_seq_ml = next_seq_ml;
        next_buf_seq_offset = next_seq_offset;
        next_buf_seq_len = next_seq_len + buf_seq_ll;
        next_buf_seq_overlap = next_seq_overlap;
        next_buf_delim = next_seq_delim;
        turn_to_empty = '0;
        turn_to_normal = '0;
        turn_to_flush = '0;
        turn_to_handle_gap = '0;
        turn_to_skip_next_job = '0;

        if(next_seq_eoj) begin
            if(next_seq_delim) begin
                turn_to_flush = 1'b1;
            end else begin
                case(1'b1) 
                    next_seq_gap_gt_0: begin
                        turn_to_handle_gap = 1'b1;
                    end
                    next_seq_gap_overlap_eq_0: begin
                        turn_to_normal = 1'b1;
                    end
                    next_seq_0_lt_overlap_lt_job_len: begin
                        turn_to_handle_overlap = 1'b1; 
                    end
                    next_seq_job_len_lte_overlap: begin
                        turn_to_skip_next_job = 1'b1;  
                    end
                endcase
            end
        end else begin
            turn_to_normal = 1'b1;
        end

    end
    
endmodule
