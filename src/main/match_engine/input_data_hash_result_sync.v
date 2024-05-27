`include "parameters.vh"

module input_data_hash_result_sync (
    input wire clk,
    input wire rst_n,

    input wire input_data_valid,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
    output wire input_data_ready,

    input wire input_hash_result_valid,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_hash_valid_vec,
    input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
    input wire input_delim,
    output wire input_hash_result_ready,
    
    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_hash_valid_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
    output wire output_delim,
    input wire output_ready
    );

    reg [`ADDR_WIDTH-1:0] head_addr_reg;

    assign output_valid = input_hash_result_valid & input_data_valid;
    assign output_head_addr = head_addr_reg;
    assign output_data = input_data;
    assign output_hash_valid_vec = input_hash_valid_vec;
    assign output_history_addr_vec = input_history_addr_vec;
    assign output_delim = input_delim;

    assign input_data_ready = output_ready & input_hash_result_valid;
    assign input_hash_result_ready = output_ready & input_data_valid;

    always @(posedge clk) begin
        if (~rst_n) begin
            head_addr_reg <= `TD 0;
        end else begin
            if (output_ready & output_valid) begin
                head_addr_reg <= `TD head_addr_reg +  `HASH_ISSUE_WIDTH;
            end
        end
    end

    `ifdef MATCH_ENGINE_INPUT_LOG
        always @(posedge clk) begin
            if(output_ready && output_valid) begin
                $display("[MatchEngine] input_addr=%d", head_addr_reg);
            end
        end
    `endif
endmodule