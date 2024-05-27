`include "parameters.vh"

module burst_launch (
        input wire clk,
        input wire rst_n,
        input wire input_valid,
        input wire [`MATCH_PU_NUM_LOG2-1:0] input_slot_idx,
        input wire input_is_burst,
        input wire [`ADDR_WIDTH-1:0] input_head_addr,
        input wire [`ADDR_WIDTH-1:0] input_history_addr,
        output wire input_ready,

        input wire [`ADDR_WIDTH-1:0] history_buffer_tail_addr,

        output wire output_valid,
        output wire [`MATCH_PU_NUM_LOG2-1:0] output_slot_idx,
        output wire output_is_burst,
        output wire [`ADDR_WIDTH-1:0] output_head_addr,
        output wire [`ADDR_WIDTH-1:0] output_head_buffer_addr,
        output wire [`ADDR_WIDTH-1:0] output_history_buffer_addr
    );


    reg [`MATCH_BURST_LEN_LOG2+1-1:0] burst_cnt_reg;
    reg [`ADDR_WIDTH-1:0] head_addr_reg;
    reg [`ADDR_WIDTH-1:0] head_buffer_addr_reg;
    reg [`ADDR_WIDTH-1:0] history_buffer_addr_reg;

    localparam state_single = 1'b0;
    localparam state_burst = 1'b1;

    reg state_reg;

    assign input_ready = (state_reg == state_single) ? 1'b1 : 1'b0;
    assign output_valid = (state_reg == state_single) ? input_valid : 1'b1;
    assign output_head_addr = (state_reg == state_single) ? input_head_addr : head_addr_reg;
    assign output_head_buffer_addr = (state_reg == state_single) ? (input_is_burst ? (input_head_addr + `MATCH_BURST_WIDTH) : input_head_addr) : head_buffer_addr_reg;
    assign output_history_buffer_addr = (state_reg == state_single) ? (input_is_burst ? (input_history_addr + `MATCH_BURST_WIDTH) : input_history_addr) : history_buffer_addr_reg;
    assign output_slot_idx = input_slot_idx;
    assign output_is_burst = input_is_burst;

    always @(posedge clk) begin
        if(~rst_n) begin
            state_reg <= `TD state_single;
        end
        else begin
            case (state_reg)
                state_single: begin
                    if(input_valid) begin
                        if (input_is_burst) begin
                            head_buffer_addr_reg <= `TD input_head_addr + 2 * `MATCH_BURST_WIDTH;
                            history_buffer_addr_reg <= `TD input_history_addr + 2 * `MATCH_BURST_WIDTH;
                            burst_cnt_reg <= `TD 2;
                            state_reg <= `TD state_burst;
                            head_addr_reg <= `TD input_head_addr;
                        end
                    end
                end
                state_burst: begin
                    burst_cnt_reg <= `TD burst_cnt_reg + 1;
                    head_buffer_addr_reg <= `TD head_buffer_addr_reg + `MATCH_BURST_WIDTH;
                    history_buffer_addr_reg <= `TD history_buffer_addr_reg + `MATCH_BURST_WIDTH;
                    if (burst_cnt_reg == `MATCH_BURST_LEN - 1) begin
                        state_reg <= `TD state_single;
                    end
                end
                default: begin
                    state_reg <= `TD state_single;
                end
            endcase
        end
    end

endmodule

module match_len_encoder_16 (
    input wire [15:0] compare_bitmask,
    output reg [4:0] match_len,
    output reg can_ext
    );

    wire [16:0] ecb = {1'b0, compare_bitmask};

    always @(*) begin
        can_ext = 1'b0;
        case(1'b0)
            ecb[0]: match_len = 5'd0;
            ecb[1]: match_len = 5'd1;
            ecb[2]: match_len = 5'd2;
            ecb[3]: match_len = 5'd3;
            ecb[4]: match_len = 5'd4;
            ecb[5]: match_len = 5'd5;
            ecb[6]: match_len = 5'd6;
            ecb[7]: match_len = 5'd7;
            ecb[8]: match_len = 5'd8;
            ecb[9]: match_len = 5'd9;
            ecb[10]: match_len = 5'd10;
            ecb[11]: match_len = 5'd11;
            ecb[12]: match_len = 5'd12;
            ecb[13]: match_len = 5'd13;
            ecb[14]: match_len = 5'd14;
            ecb[15]: match_len = 5'd15;
            ecb[16]: begin
                match_len = 5'd16;
                can_ext = 1'b1;
            end
            default: begin
                match_len = 5'd0;
                can_ext = 1'b0;
            end
        endcase
    end

endmodule

module burst_accumulate (
    input wire clk,
    input wire rst_n,
    input wire input_valid,
    input wire [`MATCH_PU_NUM_LOG2-1:0] input_slot_idx,
    input wire input_is_burst,
    input wire [`ADDR_WIDTH-1:0] input_head_addr,
    input wire [4:0] partial_match_len,
    input wire input_extp,
    input wire input_read_unsafe,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_addr,
    output wire [`MATCH_PU_NUM_LOG2-1:0] output_slot_idx,
    output wire [`MAX_MATCH_LEN_LOG2+1-1:0] output_match_len,
    output wire output_extp,
    output wire output_is_burst,
    output wire output_read_unsafe
);


    localparam state_normal = 1'b0;
    localparam state_accum = 1'b1;

    reg state_reg;

    reg [`MATCH_PU_NUM_LOG2-1:0] slot_idx_reg;
    reg extp_reg;
    reg read_unsafe_reg;
    reg [`ADDR_WIDTH-1:0] addr_reg;
    reg [`MAX_MATCH_LEN_LOG2+1-1:0] match_len_reg;
    reg [`MATCH_BURST_LEN_LOG2-1:0] burst_cnt_reg;

    assign output_valid = (state_reg == state_normal) ? (input_valid && !input_is_burst) : (burst_cnt_reg == `MATCH_BURST_LEN - 1);
    assign output_addr = (state_reg == state_normal) ? input_head_addr : addr_reg;
    assign output_slot_idx = (state_reg == state_normal) ? input_slot_idx : slot_idx_reg;
    assign output_match_len = (state_reg == state_normal) ? partial_match_len : match_len_reg + (extp_reg ? partial_match_len : 0);
    assign output_extp = (state_reg == state_normal) ? input_extp : 1'b0;
    assign output_read_unsafe = (state_reg == state_normal) ? input_read_unsafe : read_unsafe_reg;
    assign output_is_burst = (state_reg == state_normal) ? 1'b0 : 1'b1;

    always @(posedge clk) begin
        if(~rst_n) begin
            state_reg <= `TD state_normal;
        end
        else begin
            case (state_reg)
                state_normal: begin
                    if(input_valid && input_is_burst) begin
                        slot_idx_reg <= `TD input_slot_idx;
                        extp_reg <= `TD input_extp;
                        addr_reg <= `TD input_head_addr;
                        match_len_reg <= `TD partial_match_len;
                        burst_cnt_reg <= `TD 2;
                        read_unsafe_reg <= `TD input_read_unsafe;
                        state_reg <= `TD state_accum;
                    end
                end
                state_accum: begin
                    burst_cnt_reg <= `TD burst_cnt_reg + 1; // burst_2 is here
                    if(extp_reg) begin
                        match_len_reg <= `TD match_len_reg + partial_match_len;
                        extp_reg <= `TD input_extp;
                    end
                    if (burst_cnt_reg == `MATCH_BURST_LEN - 1) begin // when burst_3 is coming, flush it
                        state_reg <= `TD state_normal;
                        extp_reg <= `TD 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

module match_pu #(parameter HISTORY_SIZE_LOG2=`WINDOW_LOG, MATCH_PE_IDX = 0, MATCH_PU_IDX = 0) (
    input wire clk,
    input wire rst_n,

    input wire input_valid,
    input wire [`MATCH_PU_NUM_LOG2-1:0] input_slot_idx,
    input wire input_is_burst,
    input wire [`ADDR_WIDTH-1:0] input_head_addr,
    input wire [`ADDR_WIDTH-1:0] input_history_addr,
    output wire input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_addr,
    output wire [`MATCH_PU_NUM_LOG2-1:0] output_slot_idx,
    output wire [`MAX_MATCH_LEN_LOG2+1-1:0] output_match_len,
    output wire output_extp,
    output wire output_is_burst,
    output wire output_read_unsafe,

    input wire history_window_buffer_write_enable,
    input wire head_window_buffer_write_enable,
    input wire [`ADDR_WIDTH-1:0] window_buffer_write_addr,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data
);

    wire [`ADDR_WIDTH-1:0] history_buffer_tail_addr;

    wire burst_launch_output_valid;
    wire [`MATCH_PU_NUM_LOG2-1:0] burst_launch_output_slot_idx;
    wire burst_launch_output_is_burst;
    wire [`ADDR_WIDTH-1:0] burst_launch_output_head_addr;
    wire [`ADDR_WIDTH-1:0] burst_launch_output_head_buffer_addr;
    wire [`ADDR_WIDTH-1:0] burst_launch_output_history_buffer_addr;


    burst_launch burst_launch_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(input_valid),
        .input_slot_idx(input_slot_idx),
        .input_is_burst(input_is_burst),
        .input_head_addr(input_head_addr),
        .input_history_addr(input_history_addr),
        .input_ready(input_ready),

        .output_valid(burst_launch_output_valid),
        .output_slot_idx(burst_launch_output_slot_idx),
        .output_is_burst(burst_launch_output_is_burst),
        .output_head_addr(burst_launch_output_head_addr),
        .output_head_buffer_addr(burst_launch_output_head_buffer_addr),
        .output_history_buffer_addr(burst_launch_output_history_buffer_addr)
    );

    wire [`HASH_ISSUE_WIDTH*8-1:0] head_buffer_read_data;
    wire [`HASH_ISSUE_WIDTH*8-1:0] history_buffer_read_data;
    wire history_buffer_read_unsafe;
    window_buffer #(.WIDTH_BYTES(`HASH_ISSUE_WIDTH), .SIZE_BYTES_LOG2(`JOB_LEN_LOG2+1)) head_buffer (
        .clk(clk),
        .rst_n(rst_n),

        .write_enable(head_window_buffer_write_enable),
        .write_address(window_buffer_write_addr),
        .write_data(window_buffer_write_data),

        .read_enable(burst_launch_output_valid),
        .read_address(burst_launch_output_head_buffer_addr),
        .read_data(head_buffer_read_data)
    );

    window_buffer #(.WIDTH_BYTES(`HASH_ISSUE_WIDTH), .SIZE_BYTES_LOG2(HISTORY_SIZE_LOG2)) history_buffer (
        .clk(clk),
        .rst_n(rst_n),

        .write_enable(history_window_buffer_write_enable),
        .write_address(window_buffer_write_addr),
        .write_data(window_buffer_write_data),

        .read_enable(burst_launch_output_valid),
        .read_address(burst_launch_output_history_buffer_addr),
        .read_data(history_buffer_read_data),
        .read_unsafe(history_buffer_read_unsafe)

    );

    reg in_reading_valid_reg;
    reg [`MATCH_PU_NUM_LOG2-1:0] in_reading_slot_idx_reg;
    reg in_reading_is_burst_reg;
    reg [`ADDR_WIDTH-1:0] in_reading_head_addr_reg;

    reg after_read_valid_reg;
    reg [`MATCH_PU_NUM_LOG2-1:0] after_read_slot_idx_reg;
    reg after_read_is_burst_reg;
    reg [`ADDR_WIDTH-1:0] after_read_head_addr_reg;
    reg after_read_is_unsafe_reg;
    reg [`HASH_ISSUE_WIDTH-1:0] after_read_compare_bitmask;

    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            in_reading_valid_reg <= `TD 1'b0;
            after_read_valid_reg <= `TD 1'b0;
        end else begin
            
            in_reading_valid_reg <= `TD burst_launch_output_valid;
            in_reading_slot_idx_reg <= `TD burst_launch_output_slot_idx;
            in_reading_is_burst_reg <= `TD burst_launch_output_is_burst;
            in_reading_head_addr_reg <= `TD burst_launch_output_head_addr;

            after_read_valid_reg <= `TD in_reading_valid_reg;
            after_read_slot_idx_reg <= `TD in_reading_slot_idx_reg;
            after_read_is_burst_reg <= `TD in_reading_is_burst_reg;
            after_read_head_addr_reg <= `TD in_reading_head_addr_reg;
            after_read_is_unsafe_reg <= `TD history_buffer_read_unsafe;
            for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
                after_read_compare_bitmask[i] <= `TD (head_buffer_read_data[i*8 +: 8] == history_buffer_read_data[i*8 +: 8]) && !history_buffer_read_unsafe;
            end
        end
    end

    wire [4:0] encoder_match_len;
    wire encoder_can_ext;
    match_len_encoder_16 match_len_encoder_inst(
        .compare_bitmask(after_read_compare_bitmask),
        .match_len(encoder_match_len),
        .can_ext(encoder_can_ext)
    );

    reg after_ml_encoder_valid_reg;
    reg [`MATCH_PU_NUM_LOG2-1:0] after_ml_encoder_slot_idx_reg;
    reg after_ml_encoder_is_burst_reg;
    reg [`ADDR_WIDTH-1:0] after_ml_encoder_head_addr_reg;
    reg [4:0] after_ml_encoder_match_len_reg;
    reg after_ml_encoder_can_ext_reg;
    reg after_ml_encoder_read_unsafe_reg;

    always @(posedge clk) begin
        if (~rst_n) begin
            after_ml_encoder_valid_reg <= `TD 1'b0;
        end else begin
            after_ml_encoder_valid_reg <= `TD after_read_valid_reg;
            after_ml_encoder_slot_idx_reg <= `TD after_read_slot_idx_reg;
            after_ml_encoder_is_burst_reg <= `TD after_read_is_burst_reg;
            after_ml_encoder_head_addr_reg <= `TD after_read_head_addr_reg;
            after_ml_encoder_match_len_reg <= `TD encoder_match_len;
            after_ml_encoder_can_ext_reg <= `TD encoder_can_ext;
            after_ml_encoder_read_unsafe_reg <= `TD after_read_is_unsafe_reg;
        end
    end

    burst_accumulate burst_accumulate_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(after_ml_encoder_valid_reg),
        .input_slot_idx(after_ml_encoder_slot_idx_reg),
        .input_is_burst(after_ml_encoder_is_burst_reg),
        .input_head_addr(after_ml_encoder_head_addr_reg),
        .partial_match_len(after_ml_encoder_match_len_reg),
        .input_extp(after_ml_encoder_can_ext_reg),
        .input_read_unsafe(after_ml_encoder_read_unsafe_reg),

        .output_valid(output_valid),
        .output_addr(output_addr),
        .output_slot_idx(output_slot_idx),
        .output_match_len(output_match_len),
        .output_extp(output_extp),
        .output_is_burst(output_is_burst),
        .output_read_unsafe(output_read_unsafe)
    );

endmodule