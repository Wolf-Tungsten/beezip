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
        input wire [(`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8-1:0] input_data,
        output wire input_ready,

        output wire output_valid,
        output wire [`NUM_HASH_PE-1:0] output_mask,
        output wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] output_addr_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE-1:0] output_history_valid_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len_vec,
        output wire [`NUM_HASH_PE*`ROW_SIZE-1:0] output_meta_match_can_ext_vec,
        output wire [`NUM_HASH_PE-1:0] output_delim_vec,
        output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
        input wire output_ready
    );

    wire p_rst_n;
    dff #(.W(1), .RST(0), .EN(0)) rst_n_reg(
        .clk(clk),
        .d(rst_n),
        .q(p_rst_n),
        .rst_n(1'b0),
        .en(1'b0)
    );

    localparam BANK_NUM = `NUM_HASH_PE * `ROW_SIZE;
    localparam BANK_WORD_SIZE = 1 + `ADDR_WIDTH + `META_HISTORY_LEN*8;
    localparam BANK_ADDR_SIZE = `HASH_BANK_ROW_LOG2;

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

    wire [BANK_NUM-1:0] bank_read_enable;
    wire [BANK_NUM*BANK_ADDR_SIZE-1:0] bank_read_address;
    wire [BANK_NUM*BANK_WORD_SIZE-1:0] bank_read_data;
    wire [BANK_NUM-1:0] bank_write_enable;
    wire [BANK_NUM*BANK_ADDR_SIZE-1:0] bank_write_address;
    wire [BANK_NUM*BANK_WORD_SIZE-1:0] bank_write_data;
    /* verilator lint_off WIDTHCONCAT */
    sram2p #(.AWIDTH(BANK_ADDR_SIZE), .DWIDTH(BANK_WORD_SIZE), .NBPIPE(`HASH_PE_SRAM_NBPIPE)) sram_bank [BANK_NUM-1:0] (
                  .clk(clk),
                  .rst_n(p_rst_n),

                  .mem_enable(bank_read_enable | bank_write_enable | {BANK_NUM{!init_flag_reg_q}}),
                  .read_address(bank_read_address),
                  .read_data(bank_read_data),

                  .write_enable(bank_write_enable | {BANK_NUM{!init_flag_reg_q}}),
                  .write_address(init_flag_reg_q ? bank_write_address : {BANK_NUM{init_addr_reg_q}}),
                  .write_data(init_flag_reg_q ? bank_write_data : {(BANK_NUM*BANK_WORD_SIZE){1'b0}})
              );
    /* verilator lint_on WIDTHCONCAT */

    

    wire meta_shift_buffer_ready;

    // >>> bank read/write pipeline
    wire pipeline_enable = meta_shift_buffer_ready && init_flag_reg_q;
    assign input_ready = pipeline_enable;

    wire read_stage_valid_reg_q;
    dff #(.W(1), .RST(1), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_valid_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(input_valid),
            .q(read_stage_valid_reg_q)
        );
    wire [`NUM_HASH_PE-1:
          0] read_stage_mask_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(1), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_mask_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(input_mask),
            .q(read_stage_mask_reg_q)
        );
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:
          0] read_stage_addr_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*`ADDR_WIDTH), .RST(0), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_addr_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_addr_vec),
            .q(read_stage_addr_vec_reg_q)
        );
    wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] read_stage_hash_value_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)), .RST(0), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_hash_value_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_hash_value_vec),
            .q(read_stage_hash_value_vec_reg_q)
        );
    wire [`NUM_HASH_PE-1:0] read_stage_delim_vec_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(0), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_delim_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_delim_vec),
            .q(read_stage_delim_vec_reg_q)
        );
    wire [(`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8-1:0] read_stage_data_reg_q;
    dff #(.W((`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8), .RST(0), .EN(1), .PIPE_DEPTH(`HASH_PE_SRAM_NBPIPE+2)) read_stage_data_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(input_data),
            .q(read_stage_data_reg_q)
        );
    
    reg [BANK_NUM*BANK_ADDR_SIZE-1:0] read_req_addr_reg_d;
    dff #(.W(BANK_NUM*BANK_ADDR_SIZE), .RST(0), .EN(1), .PIPE_DEPTH(1)) read_req_addr_reg (
        .clk(clk),
        .rst_n(1'b1),
        .en(pipeline_enable),
        .d(read_req_addr_reg_d),
        .q(bank_read_address)
    );

    reg [BANK_NUM-1:0] read_req_enable_reg_d;
    dff #(.W(BANK_NUM), .RST(1), .EN(1), .PIPE_DEPTH(1)) read_req_enable_reg (
        .clk(clk),
        .rst_n(p_rst_n),
        .en(pipeline_enable),
        .d(read_req_enable_reg_d),
        .q(bank_read_enable)
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
          0] write_stage_mask_reg_q;
    dff #(.W(`NUM_HASH_PE), .RST(1), .EN(1)) write_stage_mask_reg (
            .clk(clk),
            .rst_n(p_rst_n),
            .en(pipeline_enable),
            .d(read_stage_mask_reg_q),
            .q(write_stage_mask_reg_q)
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
          0] write_stage_hash_value_vec_reg_q;
    dff #(.W(`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)), .RST(0), .EN(1)) write_stage_hash_value_vec_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(read_stage_hash_value_vec_reg_q),
            .q(write_stage_hash_value_vec_reg_q)
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
    wire [(`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8-1:0] write_stage_data_reg_q;
    dff #(.W((`HASH_ISSUE_WIDTH+`META_HISTORY_LEN-1)*8), .RST(0), .EN(1)) write_stage_data_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(read_stage_data_reg_q),
            .q(write_stage_data_reg_q)
        );

    reg [BANK_NUM*BANK_ADDR_SIZE-1:0] write_req_addr_reg_d;
    dff #(.W(BANK_NUM*BANK_ADDR_SIZE), .RST(0), .EN(1), .PIPE_DEPTH(2)) write_req_addr_reg (
        .clk(clk),
        .rst_n(1'b1),
        .en(pipeline_enable),
        .d(write_req_addr_reg_d),
        .q(bank_write_address)
    );

    reg [BANK_NUM-1:0] write_req_enable_reg_d;
    dff #(.W(BANK_NUM), .RST(1), .EN(1), .PIPE_DEPTH(2)) write_req_enable_reg (
        .clk(clk),
        .rst_n(p_rst_n),
        .en(pipeline_enable),
        .d(write_req_enable_reg_d),
        .q(bank_write_enable)
    );

    reg [BANK_NUM*BANK_WORD_SIZE-1:0] write_req_data_reg_d;
    dff #(.W(BANK_NUM*BANK_WORD_SIZE), .RST(0), .EN(1), .PIPE_DEPTH(2)) write_req_data_reg (
        .clk(clk),
        .rst_n(1'b1),
        .en(pipeline_enable),
        .d(write_req_data_reg_d),
        .q(bank_write_data)
    );


    wire [BANK_NUM*BANK_WORD_SIZE-1:
          0] bank_read_data_reg_q;
    dff #(.W(BANK_NUM*BANK_WORD_SIZE), .RST(0), .EN(1)) bank_read_data_reg (
            .clk(clk),
            .rst_n(1'b1),
            .en(pipeline_enable),
            .d(bank_read_data),
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
                if(input_hash_value_vec[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: BANK_ADDR_SIZE]
                        == write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: BANK_ADDR_SIZE]) begin
                    row_read_write_addr_conflict[row] = 1'b1;
                end
            end
        end
    end

    // conflict handle logic end here



    always @(*) begin: bank_read_write_enable_address_logic
        integer row, col;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                // bank read enable logic
                read_req_enable_reg_d[row * `ROW_SIZE + col] = input_valid && pipeline_enable;
                // bank read address logic
                read_req_addr_reg_d[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = input_hash_value_vec[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: BANK_ADDR_SIZE];
                if(init_flag_reg_q) begin
                    // bank write enable logic
                    write_req_enable_reg_d[row * `ROW_SIZE + col] = pipeline_enable && write_stage_valid_reg_q && write_stage_mask_reg_q[row] && !write_stage_delim_vec_reg_q[row] && !row_read_write_addr_conflict[row];
                    // bank write address logic
                    write_req_addr_reg_d[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = write_stage_hash_value_vec_reg_q[row*(`HASH_BITS-`NUM_HASH_PE_LOG2) +: BANK_ADDR_SIZE];
                end
                else begin
                    // bank write enable logic
                    write_req_enable_reg_d[row * `ROW_SIZE + col] = 1'b1;
                    // bank write address logic
                    write_req_addr_reg_d[(row * `ROW_SIZE + col) * BANK_ADDR_SIZE +: BANK_ADDR_SIZE] = init_addr_reg_q;
                end
            end
        end
    end

    reg [`META_HISTORY_LEN*8-1:0] bank_write_meta_history [`NUM_HASH_PE-1:0];
    always @(*) begin: bank_write_data_logic
        integer row, col;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            bank_write_meta_history[row] = {write_stage_data_reg_q >> {write_stage_addr_vec_reg_q[row*`ADDR_WIDTH +: `HASH_ISSUE_WIDTH_LOG2], 3'b0}}[`META_HISTORY_LEN*8-1:0];
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                if(!init_flag_reg_q) begin
                    write_req_data_reg_d[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] = 0;
                end
                else begin
                    if(col == 0) begin
                        write_req_data_reg_d[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] = {1'b1,
                                       bank_write_meta_history[row],
                                       write_stage_addr_vec_reg_q[row*`ADDR_WIDTH +: `ADDR_WIDTH]}; // valid, tag, history_addr
                    end
                    else begin
                        write_req_data_reg_d[(row * `ROW_SIZE + col) * BANK_WORD_SIZE +: BANK_WORD_SIZE] =
                                       bank_read_data_reg_q[(row * `ROW_SIZE + col - 1) * BANK_WORD_SIZE +: BANK_WORD_SIZE];
                    end
                end
            end
        end
    end

    reg [`NUM_HASH_PE*`ROW_SIZE-1:0] bank_readout_history_valid_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN*8-1:0] bank_readout_meta_history_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] bank_readout_history_addr_vec;

    reg meta_shift_buffer_valid;
    reg [`NUM_HASH_PE-1:0] meta_shift_buffer_mask;
    reg [`NUM_HASH_PE*`META_HISTORY_LEN*8-1:0] meta_shift_buffer_shift_data;
    reg [`NUM_HASH_PE*`ADDR_WIDTH-1:0] meta_shift_buffer_addr_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_shift_buffer_history_valid_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] meta_shift_buffer_history_addr_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN*8-1:0] meta_shift_buffer_meta_history_vec;
    reg [`HASH_ISSUE_WIDTH*8-1:0] meta_shift_buffer_data; // 只保留低位即可
    reg [`NUM_HASH_PE-1:0] meta_shift_buffer_delim_vec;

    wire meta_shift_buffer_output_valid;
    wire [`NUM_HASH_PE-1:0] meta_shift_buffer_output_mask;
    wire [`NUM_HASH_PE*`META_HISTORY_LEN*8-1:0] meta_shift_buffer_output_shift_data;
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] meta_shift_buffer_output_addr_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_shift_buffer_output_history_valid_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] meta_shift_buffer_output_history_addr_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN-1:0] meta_shift_buffer_output_meta_history_mask_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN*8-1:0] meta_shift_buffer_output_meta_history_vec;
    wire [`HASH_ISSUE_WIDTH*8-1:0] meta_shift_buffer_output_data; // 只保留低位即可
    wire [`NUM_HASH_PE-1:0] meta_shift_buffer_output_delim_vec;
    wire meta_shift_buffer_output_ready;

    always @(*) begin: meta_shift_buffer_data_logic
        integer row, col, m_i;
        meta_shift_buffer_valid = write_stage_valid_reg_q;
        meta_shift_buffer_mask = write_stage_mask_reg_q;
        meta_shift_buffer_addr_vec = write_stage_addr_vec_reg_q;
        meta_shift_buffer_data = write_stage_data_reg_q[`HASH_ISSUE_WIDTH*8-1:0];
        meta_shift_buffer_delim_vec = write_stage_delim_vec_reg_q;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            meta_shift_buffer_shift_data[row*`META_HISTORY_LEN*8 +: `META_HISTORY_LEN*8] = {write_stage_data_reg_q >> {write_stage_addr_vec_reg_q[row*`ADDR_WIDTH +: `HASH_ISSUE_WIDTH_LOG2], 3'b0}}[`META_HISTORY_LEN*8-1:0];
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                {bank_readout_history_valid_vec[row*`ROW_SIZE + col],
                 bank_readout_meta_history_vec[(row*`ROW_SIZE + col)*(`META_HISTORY_LEN*8) +: (`META_HISTORY_LEN*8)],
                 bank_readout_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH]} =
                bank_read_data_reg_q[(row*`ROW_SIZE + col)*BANK_WORD_SIZE +: BANK_WORD_SIZE];

                meta_shift_buffer_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH] =
                                                 bank_readout_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH];

                meta_shift_buffer_history_valid_vec[row*`ROW_SIZE + col] =
                                                  bank_readout_history_valid_vec[row*`ROW_SIZE + col] && // history valid
                                                  (write_stage_addr_vec_reg_q[row * `ADDR_WIDTH +: `ADDR_WIDTH] - meta_shift_buffer_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH] < `WINDOW_SIZE); // in sliding window
                


                meta_shift_buffer_meta_history_vec[(row*`ROW_SIZE + col)*`META_HISTORY_LEN*8 +: `META_HISTORY_LEN*8] =
                    bank_readout_meta_history_vec[(row*`ROW_SIZE + col)*(`META_HISTORY_LEN*8) +: (`META_HISTORY_LEN*8)];
            end
        end
    end

    handshake_slice_reg #(.W(`NUM_HASH_PE*(1+`ADDR_WIDTH+`META_HISTORY_LEN*8+`ROW_SIZE*(1+`ADDR_WIDTH+`META_HISTORY_LEN*8)+1) + (`HASH_ISSUE_WIDTH*8)),
    .DEPTH(2)) meta_shift_buffer (
                    .clk(clk),
                    .rst_n(p_rst_n),

                    .input_valid(meta_shift_buffer_valid),
                    .input_payload({meta_shift_buffer_mask, 
                                    meta_shift_buffer_addr_vec, 
                                    meta_shift_buffer_shift_data,
                                    meta_shift_buffer_history_valid_vec, 
                                    meta_shift_buffer_history_addr_vec, 
                                    meta_shift_buffer_meta_history_vec, 
                                    meta_shift_buffer_delim_vec,
                                    meta_shift_buffer_data}),
                    .input_ready(meta_shift_buffer_ready),
                    .output_valid(meta_shift_buffer_output_valid),
                    .output_payload({meta_shift_buffer_output_mask, 
                                     meta_shift_buffer_output_addr_vec,
                                     meta_shift_buffer_output_shift_data,
                                     meta_shift_buffer_output_history_valid_vec, 
                                     meta_shift_buffer_output_history_addr_vec, 
                                     meta_shift_buffer_output_meta_history_vec, 
                                     meta_shift_buffer_output_delim_vec,
                                     meta_shift_buffer_output_data}),
                    .output_ready(meta_shift_buffer_output_ready)
                );

    reg meta_mask_buffer_valid;
    reg [`NUM_HASH_PE-1:0] meta_mask_buffer_mask;
    reg [`NUM_HASH_PE*`ADDR_WIDTH-1:0] meta_mask_buffer_addr_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_mask_buffer_history_valid_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] meta_mask_buffer_history_addr_vec;
    reg [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN-1:0] meta_mask_buffer_meta_history_mask_vec;
    reg [`HASH_ISSUE_WIDTH*8-1:0] meta_mask_buffer_data; // 只保留低位即可
    reg [`NUM_HASH_PE-1:0] meta_mask_buffer_delim_vec;
    

    always @(*) begin: meta_mask_buffer_data_logic
        integer row, col, m_i;
        meta_mask_buffer_valid = meta_shift_buffer_output_valid;
        meta_mask_buffer_mask = meta_shift_buffer_output_mask;
        meta_mask_buffer_addr_vec = meta_shift_buffer_output_addr_vec;
        meta_mask_buffer_data = meta_shift_buffer_output_data;
        for(row = 0; row < `NUM_HASH_PE; row = row + 1) begin
            for(col = 0; col < `ROW_SIZE; col = col + 1) begin
                meta_mask_buffer_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH] =
                                                 meta_shift_buffer_output_history_addr_vec[(row*`ROW_SIZE + col)*`ADDR_WIDTH +: `ADDR_WIDTH];
                meta_mask_buffer_history_valid_vec[row*`ROW_SIZE + col] = meta_shift_buffer_output_history_valid_vec[row*`ROW_SIZE + col];
                
                for(m_i = 0; m_i < `META_HISTORY_LEN; m_i = m_i+1) begin
                    meta_mask_buffer_meta_history_mask_vec[(row*`ROW_SIZE + col)*`META_HISTORY_LEN + m_i] =
                        meta_shift_buffer_output_meta_history_vec[(row*`ROW_SIZE + col)*(`META_HISTORY_LEN*8) + m_i*8 +: 8] == meta_shift_buffer_output_shift_data[row*`META_HISTORY_LEN*8 + m_i*8 +: 8];
                end
            end
        end
        meta_mask_buffer_delim_vec = meta_shift_buffer_output_delim_vec;
    end

    wire meta_mask_buffer_output_valid, meta_mask_buffer_output_ready;
    wire [`NUM_HASH_PE-1:0] meta_mask_buffer_output_mask;
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] meta_mask_buffer_output_addr_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_mask_buffer_output_history_valid_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] meta_mask_buffer_output_history_addr_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`META_HISTORY_LEN-1:0] meta_mask_buffer_output_meta_history_mask_vec;
    wire [`NUM_HASH_PE-1:0] meta_mask_buffer_output_delim_vec;
    wire [`HASH_ISSUE_WIDTH*8-1:0] meta_mask_buffer_output_data;

    handshake_slice_reg #(.W(`NUM_HASH_PE*(1+`ADDR_WIDTH+`ROW_SIZE*(1+`ADDR_WIDTH+`META_HISTORY_LEN)+1) + (`HASH_ISSUE_WIDTH*8)),
    .DEPTH(2)) meta_mask_buffer (
                    .clk(clk),
                    .rst_n(p_rst_n),

                    .input_valid(meta_mask_buffer_valid),
                    .input_payload({meta_mask_buffer_mask, 
                                    meta_mask_buffer_addr_vec, 
                                    meta_mask_buffer_history_valid_vec, 
                                    meta_mask_buffer_history_addr_vec, 
                                    meta_mask_buffer_meta_history_mask_vec, 
                                    meta_mask_buffer_delim_vec,
                                    meta_mask_buffer_data}),
                    .input_ready(meta_shift_buffer_output_ready),
                    .output_valid(meta_mask_buffer_output_valid),
                    .output_payload({meta_mask_buffer_output_mask, 
                                     meta_mask_buffer_output_addr_vec, 
                                     meta_mask_buffer_output_history_valid_vec, 
                                     meta_mask_buffer_output_history_addr_vec, 
                                     meta_mask_buffer_output_meta_history_mask_vec, 
                                     meta_mask_buffer_output_delim_vec,
                                     meta_mask_buffer_output_data}),
                    .output_ready(meta_mask_buffer_output_ready)
                );

    wire [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_match_history_valid_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE*`META_MATCH_LEN_WIDTH-1:0] meta_match_len_vec;
    wire [`NUM_HASH_PE*`ROW_SIZE-1:0] meta_match_can_ext_vec;
    genvar g_row, g_col;
    generate
        for(g_row = 0; g_row < `NUM_HASH_PE; g_row = g_row+1) begin : meta_match_len_gen_row
            for(g_col = 0; g_col < `ROW_SIZE; g_col = g_col+1) begin : meta_match_len_gen_col
                match_len_encoder #(.MASK_WIDTH(`META_HISTORY_LEN), .MATCH_LEN_WIDTH(`META_MATCH_LEN_WIDTH)) match_len_encoder_inst (
                        .compare_bitmask(meta_mask_buffer_output_meta_history_mask_vec[(g_row*`ROW_SIZE + g_col)*`META_HISTORY_LEN +: `META_HISTORY_LEN]),
                        .match_len(meta_match_len_vec[(g_row*`ROW_SIZE + g_col)*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH]),
                        .can_ext(meta_match_can_ext_vec[g_row*`ROW_SIZE + g_col])
                    );
                assign meta_match_history_valid_vec[g_row*`ROW_SIZE + g_col] = meta_mask_buffer_output_history_valid_vec[g_row*`ROW_SIZE + g_col] && 
                (meta_match_len_vec[(g_row*`ROW_SIZE + g_col)*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH] >= `MIN_MATCH_LEN);
                // always @(posedge clk) begin
                //     if(p_rst_n) begin
                //         if(meta_mask_buffer_output_valid && meta_mask_buffer_output_ready) begin
                //             $display("row=%0d, col=%0d, addr=%0d, compare_bitmask=%b, match_len=%0d, can_ext=%0d", 
                //             g_row, g_col, 
                //             meta_mask_buffer_output_addr_vec[g_row* `ADDR_WIDTH +: `ADDR_WIDTH],
                //             meta_mask_buffer_output_meta_history_mask_vec[(g_row*`ROW_SIZE + g_col)*`META_HISTORY_LEN +: `META_HISTORY_LEN], 
                //             meta_match_len_vec[(g_row*`ROW_SIZE + g_col)*`META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH], 
                //             meta_match_can_ext_vec[g_row*`ROW_SIZE + g_col]);
                //         end
                //     end
                // end
            end
        end
    endgenerate


    handshake_slice_reg #(.W(`NUM_HASH_PE*(1+`ADDR_WIDTH+`ROW_SIZE*(1+`ADDR_WIDTH+`META_MATCH_LEN_WIDTH+1)+1) + `HASH_ISSUE_WIDTH*8),
                         .DEPTH(2)) meta_match_len_buffer (
        .clk(clk),
        .rst_n(p_rst_n),
        .input_valid(meta_mask_buffer_output_valid),
        .input_payload({meta_mask_buffer_output_mask, 
                        meta_mask_buffer_output_addr_vec, 
                        meta_match_history_valid_vec, 
                        meta_mask_buffer_output_history_addr_vec, 
                        meta_match_len_vec, 
                        meta_match_can_ext_vec, 
                        meta_mask_buffer_output_delim_vec,
                        meta_mask_buffer_output_data}),
        .input_ready(meta_mask_buffer_output_ready),
        .output_valid(output_valid),
        .output_payload({
            output_mask,
            output_addr_vec,
            output_history_valid_vec,
            output_history_addr_vec,
            output_meta_match_len_vec,
            output_meta_match_can_ext_vec,
            output_delim_vec,
            output_data
        }),
        .output_ready(output_ready)
    );

endmodule
