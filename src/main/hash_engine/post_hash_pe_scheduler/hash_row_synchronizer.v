`include "parameters.vh"


module hash_row_synchronizer (
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num, 

    input wire input_valid,
    input wire [`ADDR_WIDTH-1:0] input_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] input_row_valid,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_history_valid_vec,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec, 
    input wire input_delim,
    output reg input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_row_valid,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_history_valid_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec, 
    output wire output_delim,
    input wire output_ready
);

    localparam S_RECV = 0;
    localparam S_FLUSH = 1;

    reg [1:0] state_reg_d, next_state;
    wire [1:0] state_reg_q;
    reg state_reg_en;
    dff #(.W(2), .RST(1), .EN(1), .RST_V(2'b01)) state_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(state_reg_en),
        .d(state_reg_d),
        .q(state_reg_q)
    );
    
    reg [`HASH_ISSUE_WIDTH_LOG2+1-1:0] trans_cnt_reg_d;
    wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] trans_cnt_reg_q;
    reg trans_cnt_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH_LOG2+1), .RST(1), .EN(1), .RST_V(0)) trans_cnt_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(trans_cnt_reg_en),
        .d(trans_cnt_reg_d),
        .q(trans_cnt_reg_q)
    );

    reg [`HASH_ISSUE_WIDTH-1:0] row_valid_reg_d;
    wire [`HASH_ISSUE_WIDTH-1:0] row_valid_reg_q;
    reg row_valid_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH), .RST(1), .EN(1), .RST_V(0)) row_valid_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(row_valid_reg_en),
        .d(row_valid_reg_d),
        .q(row_valid_reg_q)
    );

    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] history_valid_vec_reg_d;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] history_valid_vec_reg_q;
    reg history_valid_vec_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH*`ROW_SIZE), .RST(1), .EN(1), .RST_V(0)) history_valid_vec_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(history_valid_vec_reg_en),
        .d(history_valid_vec_reg_d),
        .q(history_valid_vec_reg_q)
    );

    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] history_addr_vec_reg_d;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] history_addr_vec_reg_q;
    reg history_addr_vec_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH), .RST(1), .EN(1), .RST_V(0)) history_addr_vec_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(history_addr_vec_reg_en),
        .d(history_addr_vec_reg_d),
        .q(history_addr_vec_reg_q)
    );

    reg [`ADDR_WIDTH+1-1:0] head_addr_delim_reg_d;
    wire [`ADDR_WIDTH+1-1:0] head_addr_delim_reg_q;
    reg head_addr_delim_reg_en;
    dff #(.W(`ADDR_WIDTH+1), .RST(1), .EN(1)) head_addr_delim_reg (
        .clk(clk),
        .rst_n(rst_n),
        .en(head_addr_delim_reg_en),
        .d(head_addr_delim_reg_d),
        .q(head_addr_delim_reg_q)
    );

    reg stage_reg_valid;
    reg [`ADDR_WIDTH-1:0] stage_reg_head_addr;
    reg [`HASH_ISSUE_WIDTH-1:0] stage_reg_row_valid;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] stage_reg_history_valid_vec;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] stage_reg_history_addr_vec;
    reg stage_reg_delim;
    wire stage_reg_ready;

    // intermediate logics
    reg [`HASH_ISSUE_WIDTH-1:0] combined_row_valid;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] combined_history_valid_vec;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] combined_history_addr_vec;
    reg need_flush;
    reg [`HASH_ISSUE_WIDTH-1:0] combined_real_row_valid, flush_real_row_valid;

    always @(*) begin: hrs_fsm_logic
        integer i;
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1)begin
            combined_row_valid[i] = row_valid_reg_q[i] | input_row_valid[i];
            combined_history_valid_vec[i*`ROW_SIZE +: `ROW_SIZE] = history_valid_vec_reg_q[i*`ROW_SIZE +: `ROW_SIZE] | ({`ROW_SIZE{input_row_valid[i]}} & input_history_valid_vec[i*`ROW_SIZE +: `ROW_SIZE]);
            combined_history_addr_vec[i*`ROW_SIZE*`ADDR_WIDTH +: `ROW_SIZE*`ADDR_WIDTH] = history_addr_vec_reg_q[i*`ROW_SIZE*`ADDR_WIDTH +: `ROW_SIZE*`ADDR_WIDTH] | ({(`ROW_SIZE * `ADDR_WIDTH){input_row_valid[i]}} & input_history_addr_vec[i*`ROW_SIZE*`ADDR_WIDTH +: `ROW_SIZE*`ADDR_WIDTH]);
            combined_real_row_valid[i] = |combined_history_valid_vec[i*`ROW_SIZE +: `ROW_SIZE];
            flush_real_row_valid[i] = |history_valid_vec_reg_q[i*`ROW_SIZE +: `ROW_SIZE];
        end
        need_flush = (trans_cnt_reg_q + 1 >= cfg_max_queued_req_num) | (&combined_row_valid);
        // avoid latch, give default value
        next_state = 2'b0;
        state_reg_en = 1'b0;
        row_valid_reg_d = combined_row_valid;
        row_valid_reg_en = 1'b0;
        trans_cnt_reg_d = trans_cnt_reg_q + 1'b1;
        trans_cnt_reg_en = 1'b0;
        history_valid_vec_reg_d = combined_history_valid_vec;
        history_valid_vec_reg_en = 1'b0;
        history_addr_vec_reg_d = combined_history_addr_vec;
        history_addr_vec_reg_en = 1'b0;
        head_addr_delim_reg_d = {input_head_addr, input_delim};
        head_addr_delim_reg_en = 1'b0;
        stage_reg_valid = 1'b0;
        stage_reg_head_addr = input_head_addr;
        stage_reg_row_valid = combined_real_row_valid;
        stage_reg_history_valid_vec = combined_history_valid_vec;
        stage_reg_history_addr_vec = combined_history_addr_vec;
        stage_reg_delim = input_delim;
        input_ready = 1'b0;
        // state machine
        case(1'b1)
            state_reg_q[S_RECV]: begin
                input_ready = 1'b1;
                if(input_valid) begin
                    if(need_flush) begin
                        stage_reg_valid = 1'b1;
                        if(stage_reg_ready) begin
                            // handshake, clear buffer and counter
                            row_valid_reg_d = 0;
                            row_valid_reg_en = 1'b1;
                            trans_cnt_reg_d = 0;
                            trans_cnt_reg_en = 1'b1;
                            history_valid_vec_reg_d = 0;
                            history_valid_vec_reg_en = 1'b1;
                            history_addr_vec_reg_d = 0;
                            history_addr_vec_reg_en = 1'b1;
                        end else begin
                            // no handshake, switch to flush state
                            row_valid_reg_en = 1'b1;
                            trans_cnt_reg_en = 1'b1;
                            history_valid_vec_reg_en = 1'b1;
                            history_addr_vec_reg_en = 1'b1;
                            head_addr_delim_reg_en = 1'b1;
                            next_state[S_FLUSH] = 1'b1;
                            state_reg_en = 1'b1;
                        end
                    end else begin
                        // save input payload into buffer
                        row_valid_reg_en = 1'b1;
                        history_valid_vec_reg_en = 1'b1;
                        history_addr_vec_reg_en = 1'b1;
                        trans_cnt_reg_en = 1'b1;
                        head_addr_delim_reg_en = 1'b1;
                    end
                end
            end
            state_reg_q[S_FLUSH]: begin
                // take buffer as output
                stage_reg_valid = 1'b1;
                { stage_reg_head_addr, stage_reg_delim } = head_addr_delim_reg_q;
                stage_reg_row_valid = flush_real_row_valid;
                stage_reg_history_valid_vec = history_valid_vec_reg_q;
                stage_reg_history_addr_vec = history_addr_vec_reg_q;
                if(stage_reg_ready) begin
                    // flush buffer and return to recv state
                    row_valid_reg_d = 0;
                    row_valid_reg_en = 1'b1;
                    trans_cnt_reg_d = 0;
                    trans_cnt_reg_en = 1'b1;
                    history_valid_vec_reg_d = 0;
                    history_valid_vec_reg_en = 1'b1;
                    history_addr_vec_reg_d = 0;
                    history_addr_vec_reg_en = 1'b1;
                    next_state[S_RECV] = 1'b1;
                    state_reg_en = 1'b1;
                end
            end
            default: begin
                next_state[S_RECV] = 1'b1;
                state_reg_en = 1'b1;
            end
        endcase
        state_reg_d = next_state;
    end

    forward_reg #(.W(`ADDR_WIDTH+`HASH_ISSUE_WIDTH*(1+`ROW_SIZE*(1+`ADDR_WIDTH))+1)) stage_reg (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(stage_reg_valid),
        .input_payload({stage_reg_head_addr, stage_reg_row_valid, stage_reg_history_valid_vec, stage_reg_history_addr_vec, stage_reg_delim}),
        .input_ready(stage_reg_ready),

        .output_valid(output_valid),
        .output_payload({output_head_addr, output_row_valid, output_history_valid_vec, output_history_addr_vec, output_delim}),
        .output_ready(output_ready)
    );
endmodule