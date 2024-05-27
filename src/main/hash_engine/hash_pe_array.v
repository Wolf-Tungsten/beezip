`include "parameters.vh"
`include "log.vh"

module hash_pe_array(
        input wire clk,
        input wire rst_n,

        input wire input_valid,
        input wire [`NUM_HASH_PE-1:0] input_mask,
        input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_addr_vec,
        input wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] input_hash_value_vec,
        input wire [`NUM_HASH_PE-1:0] input_delim_vec,
        output wire input_ready,

        output wire output_valid,
        output wire [`NUM_HASH_PE-1:0] output_mask,
        output wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] output_addr_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE-1:0] output_history_valid_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
        output wire [`NUM_HASH_PE-1:0] output_delim_vec,
        input wire output_ready
    );

    wire p_rst_n;
    dff #(.W(1), .RST(0), .EN(0)) rst_n_reg(
        .clk(clk),
        .d(rst_n),
        .q(p_rst_n)
    );

    localparam BANK_NUM = `NUM_HASH_PE * `ROW_SIZE;
    localparam BANK_WORD_SIZE = 1 + `HASH_TAG_BITS + `ADDR_WIDTH;
    localparam BANK_ADDR_SIZE = `HASH_BANK_ROW_LOG2;

    reg [BANK_NUM-1:0] bank_read_enable;
    reg [BANK_NUM*BANK_ADDR_SIZE-1:0] bank_read_address;
    wire [BANK_NUM*BANK_WORD_SIZE-1:0] bank_read_data;
    reg [BANK_NUM-1:0] bank_write_enable;
    reg [BANK_NUM*BANK_ADDR_SIZE-1:0] bank_write_address;
    reg [BANK_NUM*BANK_WORD_SIZE-1:0] bank_write_data;
    sram_1r1w #(.ADDR_SIZE(BANK_ADDR_SIZE), .WORD_SIZE(BANK_WORD_SIZE)) sram_bank [BANK_NUM-1:0] (
                  .clk(clk),
                  .rst_n(p_rst_n),

                  .read_enable(bank_read_enable),
                  .read_address(bank_read_address),
                  .read_data(bank_read_data),

                  .write_enable(bank_write_enable),
                  .write_address(bank_write_address),
                  .write_data(bank_write_data)
              );

    //  >>> bank init control logic begin
    reg init_flag_reg_d, init_flag_reg_en;
    wire init_flag_reg_q;
    dff #(.W(1), .RST(1), .EN(1)) init_flag_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(init_flag_reg_en),
            .d(init_flag_reg_d),
            .q(init_flag_reg_q)
        );

    reg [BANK_ADDR_SIZE-1:0] init_addr_reg_d;
    reg init_addr_reg_en;
    wire [BANK_ADDR_SIZE-1:0] init_addr_reg_q;
    dff #(.W(BANK_ADDR_SIZE), .RST(1), .EN(1)) init_addr_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(init_addr_reg_en),
            .d(init_addr_reg_d),
            .q(init_addr_reg_q)
        );

    always @(*) begin
        init_flag_reg_d = 1'b1;
        init_flag_reg_en = 1'b0;
        init_addr_reg_d = init_addr_reg_q + 1;
        init_addr_reg_en = 1'b0;
        if(!init_flag_reg_q) begin
            init_addr_reg_en = 1'b1; // increment
            if(init_addr_reg_q == (1 << BANK_ADDR_SIZE) - 1) begin
                init_flag_reg_en = 1'b1; // mark init done
            end
        end
    end
    // end of bank init control logic <<<

    wire handshake_buffer_ready;

    // >>> bank read/write pipeline
    wire pipeline_enable = handshake_buffer_ready && init_flag_reg_q;
    assign input_ready = pipeline_enable;

    wire read_stage_valid_reg_q;
    dff #(.W(1), .RST(1), .EN(1)) read_stage_valid_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(input_valid),
            .q(read_stage_valid_reg_q)
        );
    wire write_stage_valid_reg_q;
    dff #(.W(1), .RST(1), .EN(1)) write_stage_valid_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(read_stage_valid_reg_q),
            .q(write_stage_valid_reg_q)
        );

    wire [`NUM_HASH_PE-1:
          0] read_stage_mask_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(1), .EN(1)) read_stage_mask_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(input_mask),
            .q(read_stage_mask_reg_q)
        );
    wire [`NUM_HASH_PE-1:
          0] write_stage_mask_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(1), .EN(1)) write_stage_mask_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(read_stage_mask_reg_q),
            .q(write_stage_mask_reg_q)
        );

    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:
          0] read_stage_addr_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*`ADDR_WIDTH), .RST(0), .EN(1)) read_stage_addr_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_addr_vec),
            .q(read_stage_addr_vec_reg_q)
        );
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:
          0] write_stage_addr_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*`ADDR_WIDTH), .RST(0), .EN(1)) write_stage_addr_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(read_stage_addr_vec_reg_q),
            .q(write_stage_addr_vec_reg_q)
        );

    wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:
          0] read_stage_hash_value_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)), .RST(0), .EN(1)) read_stage_hash_value_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_hash_value_vec),
            .q(read_stage_hash_value_vec_reg_q)
        );
    wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:
          0] write_stage_hash_value_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)), .RST(0), .EN(1)) write_stage_hash_value_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(read_stage_hash_value_vec_reg_q),
            .q(write_stage_hash_value_vec_reg_q)
        );

    wire [`NUM_HASH_PE-1:
          0] read_stage_delim_vec_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(0), .EN(1)) read_stage_delim_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_delim_vec),
            .q(read_stage_delim_vec_reg_q)
        );
    wire [`NUM_HASH_PE-1:
          0] write_stage_delim_vec_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(0), .EN(1)) write_stage_delim_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(read_stage_delim_vec_reg_q),
            .q(write_stage_delim_vec_reg_q)
        );


    wire [BANK_NUM*BANK_WORD_SIZE-1:
          0] bank_read_data_reg_q;
    reg [BANK_NUM*BANK_WORD_SIZE-1:
         0] bank_read_data_reg_d;
    dff #(.W(BANK_NUM*BANK_WORD_SIZE), .RST(0), .EN(1)) bank_read_data_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(bank_read_data_reg_d),
            .q(bank_read_data_reg_q)
        );
    // end of bank read/write pipeline <<<

    // conflict handle logic start here
    reg [`NUM_HASH_PE-1:
         0] row_read_write_addr_conflict;
    always @(*) begin: row_read_write_addr_conflict_logic
        integer row;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            row_read_write_addr_conflict[row] = 1'b0;
            if(input_valid && input_mask[row] && write_stage_valid_reg_q && write_stage_mask_reg_q[row]) begin
                if(input_hash_value_vec[row*(`HASH_BITS-`NUM_HASH_PE_LOG2)+`HASH_TAG_BITS +: BANK_ADDR_SIZE]
                        == write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2)+`HASH_TAG_BITS +: BANK_ADDR_SIZE]) begin
                    row_read_write_addr_conflict[row] = 1'b1;
                end
            end
        end
    end

    wire [`NUM_HASH_PE-1:0] prev_write_enable_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(1), .EN(1)) prev_write_enable_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d({`NUM_HASH_PE{write_stage_valid_reg_q}} & write_stage_mask_reg_q),
            .q(prev_write_enable_reg_q)
        );

    reg [`NUM_HASH_PE*BANK_ADDR_SIZE-1:0] prev_write_addr_reg_d;
    wire [`NUM_HASH_PE*BANK_ADDR_SIZE-1:0] prev_write_addr_reg_q;
    dff #(.W(`NUM_HASH_PE*BANK_ADDR_SIZE), .RST(0), .EN(1)) prev_write_addr_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(prev_write_addr_reg_d),
            .q(prev_write_addr_reg_q)
        );

    wire [BANK_NUM*BANK_WORD_SIZE-1:0] prev_write_data_reg_q;
    dff #(.W(BANK_NUM*BANK_WORD_SIZE), .RST(0), .EN(1)) prev_write_data_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(bank_write_data),
            .q(prev_write_data_reg_q)
        );
    // conflict handle logic end here



    always @(*) begin: bank_read_write_enable_address_logic
        integer row, col;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                // bank read enable logic
                bank_read_enable[row * `ROW_SIZE + col] = input_valid && pipeline_enable && !row_read_write_addr_conflict[row];
                // bank read address logic
                bank_read_address[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = input_hash_value_vec[row*(`HASH_BITS-`NUM_HASH_PE_LOG2)+`HASH_TAG_BITS +: BANK_ADDR_SIZE];
                if(init_flag_reg_q) begin
                    // bank write enable logic
                    bank_write_enable[row * `ROW_SIZE + col] = pipeline_enable && write_stage_valid_reg_q && write_stage_mask_reg_q[row] && !write_stage_delim_vec_reg_q[row];
                    // bank write address logic
                    bank_write_address[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2)+`HASH_TAG_BITS +: BANK_ADDR_SIZE];
                end
                else begin
                    // bank write enable logic
                    bank_write_enable[row * `ROW_SIZE + col] = 1'b1;
                    // bank write address logic
                    bank_write_address[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = init_addr_reg_q;
                end
            end
            prev_write_addr_reg_d[row* BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2)+`HASH_TAG_BITS +: BANK_ADDR_SIZE];
        end
    end

    always @(*) begin: bank_write_data_logic
        integer row, col;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                if(!init_flag_reg_q) begin
                    bank_write_data[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] = 0;
                end
                else begin
                    if(col == 0) begin
                        bank_write_data[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] = {1'b1,
                                       write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: `HASH_TAG_BITS],
                                       write_stage_addr_vec_reg_q[row*`ADDR_WIDTH +: `ADDR_WIDTH]}; // valid, tag, history_addr
                    end
                    else begin
                        bank_write_data[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] =
                                       bank_read_data_reg_q[(row * `ROW_SIZE + col - 1) * BANK_WORD_SIZE +: BANK_WORD_SIZE];
                    end
                end
            end
        end
    end

    always @(*) begin: bank_read_data_logic
        integer row;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            if(read_stage_valid_reg_q && read_stage_mask_reg_q[row] &&
                    write_stage_valid_reg_q && write_stage_mask_reg_q[row] &&
                    read_stage_hash_value_vec_reg_q[row * (BANK_ADDR_SIZE + `HASH_TAG_BITS) + `HASH_TAG_BITS +: BANK_ADDR_SIZE] ==
                    write_stage_hash_value_vec_reg_q[row * (BANK_ADDR_SIZE + `HASH_TAG_BITS) + `HASH_TAG_BITS +: BANK_ADDR_SIZE]) begin
                bank_read_data_reg_d[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE] = bank_write_data[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE];
            end
            else if (read_stage_valid_reg_q && read_stage_mask_reg_q[row] &&
                    prev_write_enable_reg_q[row] && 
                    read_stage_hash_value_vec_reg_q[row * (BANK_ADDR_SIZE + `HASH_TAG_BITS) + `HASH_TAG_BITS +: BANK_ADDR_SIZE] == 
                    prev_write_addr_reg_q[row * BANK_ADDR_SIZE +: BANK_ADDR_SIZE]) begin
                bank_read_data_reg_d[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE] = prev_write_data_reg_q[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE];
            end
            else begin
                bank_read_data_reg_d[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE] = bank_read_data[row*`ROW_SIZE*BANK_WORD_SIZE +: BANK_WORD_SIZE*`ROW_SIZE];
            end
        end
    end

    reg [`NUM_HASH_PE*`ROW_SIZE-1:0] bank_readout_history_valid_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`HASH_TAG_BITS-1:0] bank_readout_tag_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] bank_readout_history_addr_vec;

    reg handshake_buffer_valid;
    reg [`NUM_HASH_PE-1:0] handshake_buffer_mask;
    reg [`NUM_HASH_PE*`ADDR_WIDTH-1:0] handshake_buffer_addr_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE-1:0] handshake_buffer_history_valid_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] handshake_buffer_history_addr_vec;
    reg [`NUM_HASH_PE-1:0] handshake_buffer_delim_vec;

    always @(*) begin: handshake_buffer_data_logic
        integer row, col;
        handshake_buffer_valid = write_stage_valid_reg_q;
        handshake_buffer_mask = write_stage_mask_reg_q;
        handshake_buffer_addr_vec = write_stage_addr_vec_reg_q;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                {bank_readout_history_valid_vec[row*`ROW_SIZE + col],
                 bank_readout_tag_vec[(row*`ROW_SIZE + col)*`HASH_TAG_BITS +: `HASH_TAG_BITS],
                 bank_readout_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH]} =
                bank_read_data_reg_q[(row*`ROW_SIZE + col)*BANK_WORD_SIZE +: BANK_WORD_SIZE];

                handshake_buffer_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH] =
                                                 bank_readout_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH];

                handshake_buffer_history_valid_vec[row*`ROW_SIZE + col] =
                                                  bank_readout_history_valid_vec[row*`ROW_SIZE + col] && // history valid
                                                  (bank_readout_tag_vec[(row*`ROW_SIZE + col)*`HASH_TAG_BITS +: `HASH_TAG_BITS] == write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: `HASH_TAG_BITS]) && // tag matched
                                                  (write_stage_addr_vec_reg_q[row * `ADDR_WIDTH +: `ADDR_WIDTH] - handshake_buffer_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH] < `WINDOW_SIZE); // in sliding window
            end
        end
        handshake_buffer_delim_vec = write_stage_delim_vec_reg_q;
    end

    forward_reg #(.W(`NUM_HASH_PE*(1+`ADDR_WIDTH+`ROW_SIZE*(1+`ADDR_WIDTH)+1))) handshake_buffer (
                    .clk(clk),
                    .rst_n(p_rst_n),

                    .input_valid(handshake_buffer_valid),
                    .input_payload({handshake_buffer_mask, handshake_buffer_addr_vec, handshake_buffer_history_valid_vec, handshake_buffer_history_addr_vec, handshake_buffer_delim_vec}),
                    .input_ready(handshake_buffer_ready),

                    .output_valid(output_valid),
                    .output_payload({output_mask, output_addr_vec, output_history_valid_vec, output_history_addr_vec, output_delim_vec}),
                    .output_ready(output_ready)
                );
endmodule
