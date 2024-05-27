`include "parameters.vh"
`include "log.vh"

module reorder_crossbar (
    input wire clk,
    input wire rst_n,

    input wire input_valid,
    input wire [`NUM_HASH_PE-1:0] input_mask,
    input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_addr_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE-1:0] input_history_valid_vec,
    input wire [`NUM_HASH_PE*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
    input wire [`NUM_HASH_PE-1:0] input_delim_vec,
    output wire input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_row_valid,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_history_valid_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec, 
    output wire output_delim,
    input wire output_ready
);

    wire stage_reg_valid;
    reg [`ADDR_WIDTH-1:0] stage_reg_head_addr;
    reg [`HASH_ISSUE_WIDTH-1:0] stage_reg_row_valid;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] stage_reg_history_valid_vec;
    reg [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] stage_reg_history_addr_vec;
    reg stage_reg_delim;
    wire stage_reg_ready;

    assign stage_reg_valid = input_valid;
    assign input_ready = stage_reg_ready;
    // assign stage_delim = |(input_mask & input_delim_vec);

    // crossbar architecture
    always @(*) begin: crossbar_logic
        integer i, j;
        stage_reg_head_addr = 0;
        stage_reg_history_valid_vec = 0;
        stage_reg_history_addr_vec = 0;
        stage_reg_delim = 0;
        stage_reg_row_valid = 0;
        for(i = 0; i < `NUM_HASH_PE; i = i+1) begin : crossbar_outter_loop
            stage_reg_head_addr = stage_reg_head_addr | {`ADDR_WIDTH{input_mask[i]}} & input_addr_vec[i * `ADDR_WIDTH +: `ADDR_WIDTH];
            stage_reg_delim = stage_reg_delim | (input_mask[i] & input_delim_vec[i]);
            for(j = 0; j < `HASH_ISSUE_WIDTH; j = j+1) begin : crossbar_inner_loop
                reg dst_match;
                dst_match = input_mask[i] && (input_addr_vec[i * `ADDR_WIDTH +: `HASH_ISSUE_WIDTH_LOG2] == j);
                stage_reg_row_valid[j] = stage_reg_row_valid[j] | dst_match;
                stage_reg_history_valid_vec[j * `ROW_SIZE +: `ROW_SIZE] = stage_reg_history_valid_vec[j * `ROW_SIZE +: `ROW_SIZE] | {`ROW_SIZE{dst_match}} & input_history_valid_vec[i * `ROW_SIZE +: `ROW_SIZE];
                stage_reg_history_addr_vec[j * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH] = stage_reg_history_addr_vec[j * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH] | {(`ROW_SIZE*`ADDR_WIDTH){dst_match}} & input_history_addr_vec[i * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH];
            end
        end
        stage_reg_head_addr = stage_reg_head_addr & {{(`ADDR_WIDTH-`HASH_ISSUE_WIDTH_LOG2){1'b1}}, {`HASH_ISSUE_WIDTH_LOG2{1'b0}}};
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
