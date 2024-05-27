`include "parameters.vh"

module hash_pe_request_serializer(
        input wire clk,
        input wire rst_n,

        input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num, 

        input wire input_valid,
        input wire [`ADDR_WIDTH-1:0] input_head_addr,
        input wire [`HASH_ISSUE_WIDTH-1:0] input_mask_vec,
        input wire [(`HASH_BITS-`NUM_HASH_PE_LOG2)*`HASH_ISSUE_WIDTH-1:0] input_hash_value_vec,
        input wire input_delim,
        output reg input_ready,

        output reg output_valid,
        output reg [`ADDR_WIDTH-1:0] output_addr,
        output reg [`HASH_BITS-`NUM_HASH_PE_LOG2-1:0] output_hash_value,
        output reg output_delim,
        input wire output_ready
    );

    wire p_rst_n;
    dff #(.W(1), .RST(0), .EN(0)) rst_n_reg(
        .clk(clk),
        .d(rst_n),
        .q(p_rst_n)
    );
    reg [`HASH_BITS-`NUM_HASH_PE_LOG2-1:0] input_hash_value_arr [0:`HASH_ISSUE_WIDTH-1];
    reg [`HASH_ISSUE_WIDTH-1:0] buffer_mask_vec_reg_d;
    wire [`HASH_ISSUE_WIDTH-1:0] buffer_mask_vec_reg_q;
    reg buffer_mask_vec_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH), .EN(1), .RST(1)) buffer_mask_vec_reg (
            .clk(clk), .rst_n(p_rst_n),
            .en(buffer_mask_vec_reg_en),
            .d(buffer_mask_vec_reg_d),
            .q(buffer_mask_vec_reg_q)
        );
    reg [(`HASH_BITS-`NUM_HASH_PE_LOG2)*`HASH_ISSUE_WIDTH-1:0] buffer_hash_value_arr_reg_d;
    wire [(`HASH_BITS-`NUM_HASH_PE_LOG2)*`HASH_ISSUE_WIDTH-1:0] buffer_hash_value_arr_reg_q;
    reg buffer_hash_value_arr_reg_en;
    dff #(.W((`HASH_BITS-`NUM_HASH_PE_LOG2)*`HASH_ISSUE_WIDTH), .EN(1)) buffer_hash_value_arr_reg (
            .clk(clk), .rst_n(p_rst_n),
            .en(buffer_hash_value_arr_reg_en),
            .d(buffer_hash_value_arr_reg_d),
            .q(buffer_hash_value_arr_reg_q)
        );
    reg [`ADDR_WIDTH-1:0] buffer_head_addr_reg_d;
    wire [`ADDR_WIDTH-1:0] buffer_head_addr_reg_q;
    reg buffer_head_addr_reg_en;
    dff #(.W(`ADDR_WIDTH), .EN(1)) buffer_head_addr_reg (
            .clk(clk), .rst_n(p_rst_n),
            .en(buffer_head_addr_reg_en),
            .d(buffer_head_addr_reg_d),
            .q(buffer_head_addr_reg_q)
        );
    reg buffer_delim_reg_d;
    wire buffer_delim_reg_q;
    reg buffer_delim_reg_en;
    dff #(.W(1), .EN(1)) buffer_delim_reg (
            .clk(clk), .rst_n(p_rst_n),
            .en(buffer_delim_reg_en),
            .d(buffer_delim_reg_d),
            .q(buffer_delim_reg_q)
        );
    reg [`HASH_ISSUE_WIDTH_LOG2+1-1:0] counter_reg_d;
    wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] counter_reg_q;
    reg counter_reg_en;
    dff #(.W(`HASH_ISSUE_WIDTH_LOG2+1), .EN(1), .RST(1)) counter_reg (
            .clk(clk), .rst_n(p_rst_n),
            .en(counter_reg_en),
            .d(counter_reg_d),
            .q(counter_reg_q)
        );

    wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] input_valid_count, buffer_valid_count;
    pop_count #(.W(`HASH_ISSUE_WIDTH)) input_valid_count_inst (
                  .input_vec(input_mask_vec),
                  .output_count(input_valid_count)
              );
    pop_count #(.W(`HASH_ISSUE_WIDTH)) buffer_valid_count_inst (
                  .input_vec(buffer_mask_vec_reg_q),
                  .output_count(buffer_valid_count)
              );
    wire [`HASH_ISSUE_WIDTH_LOG2-1:0] input_valid_sel, buffer_valid_sel;
    wire tile_off_valid_0, tile_off_valid_1;
    priority_encoder #(.W(`HASH_ISSUE_WIDTH)) input_valid_enc_inst (
                         .input_vec(input_mask_vec),
                         .output_index(input_valid_sel),
                         .output_valid(tile_off_valid_0)
                     );
    priority_encoder #(.W(`HASH_ISSUE_WIDTH)) buffer_valid_enc_inst (
                         .input_vec(buffer_mask_vec_reg_q),
                         .output_index(buffer_valid_sel),
                         .output_valid(tile_off_valid_1)
                     );


    localparam NORMAL = 0,
               FLUSH = 1;

    reg [1:0] state_reg, next_state;
    always @(posedge clk) begin
        if(!p_rst_n) begin
            state_reg <= 2'b0;
            state_reg[NORMAL] <= 1'b1;
        end
        else begin
            state_reg <= next_state;
        end
    end

    always @(*) begin: hprs_fsm_logic
        integer i;
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
            input_hash_value_arr[i] = input_hash_value_vec[i*(`HASH_BITS-`NUM_HASH_PE_LOG2)+:`HASH_BITS-`NUM_HASH_PE_LOG2];
        end
        next_state = 2'b0;
        input_ready = 1'b0;
        output_valid = 1'b0;
        output_hash_value = input_hash_value_arr[0];
        output_addr = input_head_addr;
        output_delim = input_delim;
        buffer_hash_value_arr_reg_d = 0;
        buffer_mask_vec_reg_d = 0;
        buffer_head_addr_reg_d = 0;
        buffer_delim_reg_d = 0;
        buffer_hash_value_arr_reg_en = 1'b0;
        buffer_mask_vec_reg_en = 1'b0;
        buffer_head_addr_reg_en = 1'b0;
        buffer_delim_reg_en = 1'b0;
        counter_reg_d = 0;
        counter_reg_en = 1'b0;
        case(1'b1)
            state_reg[NORMAL]: begin
                input_ready = 1'b1;
                if(input_valid && input_valid_count > 0) begin
                    output_valid = 1'b1;
                    output_hash_value = input_hash_value_arr[input_valid_sel];
                    output_addr = input_head_addr + input_valid_sel;
                    output_delim = input_delim;
                    if(output_ready) begin
                        // output not blocked
                        if(input_valid_count > 1 && cfg_max_queued_req_num > 1) begin
                            // multiple valid requests, output the first one, write the rest into buffer
                            buffer_hash_value_arr_reg_en = 1'b1;
                            buffer_mask_vec_reg_en = 1'b1;
                            buffer_head_addr_reg_en = 1'b1;
                            buffer_delim_reg_en = 1'b1;
                            buffer_delim_reg_d = input_delim;
                            buffer_head_addr_reg_d = input_head_addr;
                            counter_reg_d = 1;
                            counter_reg_en = 1'b1;
                            for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
                                buffer_hash_value_arr_reg_d[i * (`HASH_BITS-`NUM_HASH_PE_LOG2) +: `HASH_BITS-`NUM_HASH_PE_LOG2] = input_hash_value_arr[i];
                                buffer_mask_vec_reg_d[i] = input_mask_vec[i] && (i != input_valid_sel); // skip the first one
                            end
                            next_state[FLUSH] = 1'b1;
                        end
                        else begin
                            // only one valid request, no need to write into buffer
                            next_state[NORMAL] = 1'b1;
                        end
                    end
                    else begin
                        // no output, write all into buffer
                        buffer_hash_value_arr_reg_en = 1'b1;
                        buffer_mask_vec_reg_en = 1'b1;
                        buffer_head_addr_reg_en = 1'b1;
                        buffer_head_addr_reg_d = input_head_addr;
                        buffer_delim_reg_en = 1'b1;
                        buffer_delim_reg_d = input_delim;
                        counter_reg_d = 0;
                        counter_reg_en = 1'b1;
                        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
                            buffer_hash_value_arr_reg_d[i * (`HASH_BITS-`NUM_HASH_PE_LOG2) +: `HASH_BITS-`NUM_HASH_PE_LOG2] = input_hash_value_arr[i];
                            buffer_mask_vec_reg_d[i] = input_mask_vec[i];
                        end
                        next_state[FLUSH] = 1'b1;
                    end
                end else begin
                    next_state[NORMAL] = 1'b1;
                end
            end
            state_reg[FLUSH]: begin
                output_valid = 1'b1;
                output_addr = buffer_head_addr_reg_q + buffer_valid_sel;
                output_hash_value = buffer_hash_value_arr_reg_q[buffer_valid_sel * (`HASH_BITS-`NUM_HASH_PE_LOG2) +: `HASH_BITS-`NUM_HASH_PE_LOG2];
                output_delim = buffer_delim_reg_q;
                if(output_ready) begin
                    if(buffer_valid_count > 1 && counter_reg_q + 1 < cfg_max_queued_req_num) begin
                        counter_reg_d = counter_reg_q + 1;
                        counter_reg_en = 1;
                        // buffer is not cleared
                        next_state[FLUSH] = 1'b1;
                        // update mask vec reg
                        buffer_mask_vec_reg_en = 1'b1;
                        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
                            buffer_mask_vec_reg_d[i] = buffer_mask_vec_reg_q[i] && (i != buffer_valid_sel);
                        end
                    end
                    else begin
                        next_state[NORMAL] = 1'b1;
                    end
                end else begin
                    next_state[FLUSH] = 1'b1;
                end
            end
            default: begin
                next_state[NORMAL] = 1'b1;
            end
        endcase
    end
endmodule