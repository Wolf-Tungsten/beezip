`include "parameters.vh"
`include "util.vh"

module handle_overlap_process (

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
    
    output reg output_seq_valid,
    output reg [`SEQ_LL_BITS-1:0] output_seq_ll,
    output reg [`SEQ_ML_BITS-1:0] output_seq_ml,
    output reg [`SEQ_OFFSET_BITS-1:0] output_seq_offset,

    output reg next_buf_seq_valid,
    output reg [`SEQ_LL_BITS-1:0] next_buf_seq_ll,
    output reg [`SEQ_ML_BITS-1:0] next_buf_seq_ml,
    output reg [`SEQ_OFFSET_BITS-1:0] next_buf_seq_offset,
    output reg [`SEQ_LL_BITS-1:0] next_buf_seq_len,
    output reg [`SEQ_ML_BITS-1:0] next_buf_seq_overlap,
    output reg next_buf_delim,

    output reg buf_update,
    output reg turn_to_empty,
    output reg turn_to_normal,
    output reg turn_to_flush,
    output reg turn_to_handle_gap,
    output reg turn_to_handle_overlap,
    output reg turn_to_skip_next_job
);

    // case1: seq.overlap <= nextSeq.ll
    wire case1 = `ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS) <= next_seq_ll;
    // case2: nextSeq.ll >= MIN_MATCH_LEN, overlap >= nextSeq.ll, overlap <= nextSeq.ll + nextSeq.ml
    wire case2 = next_seq_ll_gte_mml && 
    (`ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS) >= next_seq_ll) && 
    (`ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS) <= next_seq_len);
    // case3: overlap >= nextSeq.ll + nextSeq.ml
    wire case3 = `ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS) >= next_seq_len;

    always @(*) begin
        output_seq_valid = '0;
        output_seq_ll = '0;
        output_seq_ml = '0;
        output_seq_offset = '0;
        next_buf_seq_valid = '0;
        next_buf_seq_ll = '0;
        next_buf_seq_ml = '0;
        next_buf_seq_offset = '0;
        next_buf_seq_len = '0;
        next_buf_seq_overlap = '0;
        next_buf_delim = '0;
        turn_to_empty = '0;
        turn_to_normal = '0;
        turn_to_flush = '0;
        turn_to_handle_gap = '0;
        turn_to_handle_overlap = '0;
        turn_to_skip_next_job = '0;
        buf_update = '0;

        if(next_seq_eoj) begin
            if(next_seq_delim) begin
                // buf 中的 seq 全部作为 ll 合并到新输入的 seq，写入 buf
                buf_update = 1'b1;
                next_buf_seq_valid = 1'b1;
                next_buf_seq_ll = next_seq_ll + buf_seq_len;
                next_buf_seq_ml = next_seq_ml;
                next_buf_seq_offset = next_seq_offset;
                next_buf_delim = 1'b1;
                // 转到 flush 状态
                turn_to_flush = 1'b1;
            end else begin
                case(1'b1) 
                    next_seq_gap_gt_0: begin
                        // buf 中的 seq 正常输出
                        output_seq_valid = 1'b1;
                        output_seq_ll = buf_seq_ll;
                        output_seq_ml = buf_seq_ml;
                        output_seq_offset = buf_seq_offset;
                        // 新输入的 seq 修剪 ll，然后放入 buf
                        buf_update = 1'b1;
                        next_buf_seq_valid = 1'b1;
                        next_buf_seq_ll = next_seq_ll - `ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS);
                        next_buf_seq_ml = next_seq_ml;
                        next_buf_seq_offset = next_seq_offset;
                        // 接下来处理 gap
                        turn_to_handle_gap = 1'b1;
                    end
                    next_seq_gap_overlap_eq_0: begin
                        case(1'b1)
                            case1: begin
                                // buf 中的 seq 正常输出
                                output_seq_valid = 1'b1;
                                output_seq_ll = buf_seq_ll;
                                output_seq_ml = buf_seq_ml;
                                output_seq_offset = buf_seq_offset;
                                // 新输入的 seq 修剪 ll，然后放入 buf
                                buf_update = 1'b1;
                                next_buf_seq_valid = 1'b1;
                                next_buf_seq_ll = next_seq_ll - `ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS);
                                next_buf_seq_ml = next_seq_ml;
                                next_buf_seq_offset = next_seq_offset;
                                // 转到 normal 状态
                                turn_to_normal = 1'b1;
                            end
                            case2: begin
                                // buf 中的 seq 修剪 ml，然后输出
                                output_seq_valid = 1'b1;
                                output_seq_ll = buf_seq_ll;
                                output_seq_ml = buf_seq_ml - (buf_seq_overlap - next_seq_ll[`SEQ_ML_BITS-1:0]);
                                output_seq_offset = buf_seq_offset;
                                // 新输入的 seq ll 置为 0，然后放入buf
                                buf_update = 1'b1;
                                next_buf_seq_valid = 1'b1;
                                next_buf_seq_ll = '0;
                                next_buf_seq_ml = next_seq_ml;
                                next_buf_seq_offset = next_seq_offset;
                                // 转到 normal 状态
                                turn_to_normal = 1'b1; 
                            end
                            case3: begin
                                // buf 中的 seq 修剪 ml，然后输出
                                output_seq_valid = 1'b1;
                                output_seq_ll = buf_seq_ll;
                                output_seq_ml = buf_seq_ml - (buf_seq_overlap - next_seq_len[`SEQ_ML_BITS-1:0]);
                                output_seq_offset = buf_seq_offset;
                                // 新输入的 seq 被完全覆盖，不放入 buf
                                // 转到 empty 状态
                                turn_to_empty = 1'b1;
                            end
                            default: begin
                                // buf 中的 seq 全部作为 ll 合并到新输入的 seq，写入 buf
                                buf_update = 1'b1;
                                next_buf_seq_valid = 1'b1;
                                next_buf_seq_ll = next_seq_ll + buf_seq_len;
                                next_buf_seq_ml = next_seq_ml;
                                next_buf_seq_offset = next_seq_offset;
                                // 转到 normal 状态
                                turn_to_normal = 1'b1;
                            end
                        endcase
                    end
                    next_seq_0_lt_overlap_lt_job_len: begin
                        // buf 中的 seq 全部作为 ll 合并到新输入的 seq，写入 buf
                        buf_update = 1'b1;
                        next_buf_seq_valid = 1'b1;
                        next_buf_seq_ll = next_seq_ll + buf_seq_len;
                        next_buf_seq_ml = next_seq_ml;
                        next_buf_seq_offset = next_seq_offset;
                        next_buf_seq_len = next_seq_len + buf_seq_len;
                        next_buf_seq_overlap = next_seq_overlap;
                        // 转到 handle overlap 状态
                        turn_to_handle_overlap = 1'b1; 
                    end
                    next_seq_job_len_lte_overlap: begin
                       // buf 中的 seq 全部作为 ll 合并到新输入的 seq，写入 buf
                        buf_update = 1'b1;
                        next_buf_seq_valid = 1'b1;
                        next_buf_seq_ll = next_seq_ll + buf_seq_len;
                        next_buf_seq_ml = next_seq_ml;
                        next_buf_seq_offset = next_seq_offset;
                        next_buf_seq_len = next_seq_len + buf_seq_len;
                        next_buf_seq_overlap = next_seq_overlap;
                        // 转到 skip next job 状态
                        turn_to_skip_next_job = 1'b1;  
                    end
                endcase
            end
        end else begin
            // next_seq 是正常 seq
            case (1'b1)
                case1: begin
                    // buf 中 seq 正常输出
                    output_seq_valid = 1'b1;
                    output_seq_ll = buf_seq_ll;
                    output_seq_ml = buf_seq_ml;
                    output_seq_offset = buf_seq_offset;
                    // 新输入的 seq 放入 buf
                    buf_update = 1'b1;
                    next_buf_seq_valid = 1'b1;
                    next_buf_seq_ll = next_seq_ll - `ZERO_EXTEND(buf_seq_overlap, `SEQ_LL_BITS);
                    next_buf_seq_ml = next_seq_ml;
                    next_buf_seq_offset = next_seq_offset;
                    // 转到 normal 状态
                    turn_to_normal = 1'b1;
                end
                case2: begin
                    // buf 中的 seq 修剪 ml，然后输出
                    output_seq_valid = 1'b1;
                    output_seq_ll = buf_seq_ll;
                    output_seq_ml = buf_seq_ml - (buf_seq_overlap - next_seq_ll[`SEQ_ML_BITS-1:0]);
                    output_seq_offset = buf_seq_offset;
                    // 新输入的 seq ll 置为 0，然后放入buf
                    buf_update = 1'b1;
                    next_buf_seq_valid = 1'b1;
                    next_buf_seq_ll = '0;
                    next_buf_seq_ml = next_seq_ml;
                    next_buf_seq_offset = next_seq_offset;
                    // 转到 normal 状态
                    turn_to_normal = 1'b1;
                end
                case3: begin
                    // 新输入的 seq 被完全覆盖，buf中原有seq修剪后放入 buf
                    // 转到 empty 状态
                    buf_update = 1'b1; // 仍然要写入 seq packet 的其他部分
                    next_buf_seq_valid = 1'b1;
                    next_buf_seq_ll = buf_seq_ll;
                    next_buf_seq_ml = buf_seq_ml - (buf_seq_overlap - next_seq_len[`SEQ_ML_BITS-1:0]);
                    next_buf_seq_offset = buf_seq_offset;
                    turn_to_normal = 1'b1;
                end
                default: begin
                    // buf 中的 seq 全部作为 ll 合并到新输入的 seq，写入 buf
                    buf_update = 1'b1;
                    next_buf_seq_valid = 1'b1;
                    next_buf_seq_ll = next_seq_ll + buf_seq_len;
                    next_buf_seq_ml = next_seq_ml;
                    next_buf_seq_offset = next_seq_offset;
                    // 转到 normal 状态
                    turn_to_normal = 1'b1;
                end
            endcase
        end

    end
    
endmodule