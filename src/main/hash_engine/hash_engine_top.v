`include "parameters.vh"

module hash_engine_top(
    input wire clk,
    input wire rst_n,

    input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num, 

    input  wire input_valid,
    output wire input_ready,
    input  wire input_delim,
    input  wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_row_valid,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_history_valid_vec,
    output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
    output wire output_delim,
    input wire output_ready
);
    /*
           [module name]      :   [short name]
    1. input_leftover_buffer  : buffer
    2. hash_compute           : compute
    3. pre_hash_pe_scheduler  : pre
    4. hash_bank              : bank
    5. post_hash_pe_scheduler : post
    */

    // signas between input_leftover_buffer and hash_compute
    wire valid_between_buffer_compute;
    wire ready_between_buffer_compute;
    wire delim_between_buffer_compute;
    wire [`ADDR_WIDTH-1:0] head_addr_between_buffer_compute;
    wire [(`HASH_ISSUE_WIDTH+`HASH_COVER_BYTES-1)*8-1:0] data_between_buffer_compute;

    // signals between hash_compute and pre_hash_pe_scheduler
    wire valid_between_comp_pre_schd;
    wire ready_between_comp_pre_schd;
    wire delim_between_comp_pre_schd;
    wire [`ADDR_WIDTH-1:0] head_addr_between_comp_pre_schd;
    wire [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] hash_value_vec_between_comp_pre_schd;

    // signals between pre_hash_pe_scheduler and hash_pe_array
    wire valid_between_pre_schd_pe_array;
    wire [`NUM_HASH_PE-1:0] mask_between_pre_schd_pe_array;
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] addr_between_pre_schd_pe_array;
    wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] hash_value_between_pre_schd_pe_array;
    wire [`NUM_HASH_PE-1:0] delim_between_pre_schd_pe_array;
    wire ready_between_pre_schd_pe_array;

    // signals between hash_pe_array and post_hash_pe_scheduler
    wire valid_between_pe_array_post_schd;
    wire [`NUM_HASH_PE-1:0] mask_between_pe_array_post_schd; 
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] addr_between_pe_array_post_schd;
    wire [`NUM_HASH_PE*`ADDR_WIDTH*`ROW_SIZE-1:0] history_addr_vec_between_pe_array_post_schd;
    wire [`NUM_HASH_PE*`ROW_SIZE-1:0] history_valid_vec_between_pe_array_post_schd;
    wire [`NUM_HASH_PE-1:0] delim_between_pe_array_post_schd;
    wire ready_between_pe_array_post_schd;


    input_leftover_buffer u_input_leftover_buffer(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_delim(input_delim),
        .input_data (input_data),

        .output_valid(valid_between_buffer_compute),
        .output_ready(ready_between_buffer_compute),
        .output_delim(delim_between_buffer_compute),
        .output_head_addr(head_addr_between_buffer_compute),
        .output_data(data_between_buffer_compute)
    );

    hash_compute u_hash_compute(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(valid_between_buffer_compute),
        .input_ready(ready_between_buffer_compute),
        .input_delim(delim_between_buffer_compute),
        .input_head_addr(head_addr_between_buffer_compute),
        .input_data(data_between_buffer_compute),
        
        .output_valid(valid_between_comp_pre_schd),
        .output_head_addr(head_addr_between_comp_pre_schd),
        .output_hash_value_vec(hash_value_vec_between_comp_pre_schd),
        .output_delim(delim_between_comp_pre_schd),
        .output_ready(ready_between_comp_pre_schd)
    );

    pre_hash_pe_scheduler u_pre_hash_pe_scheduler(
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),
    
        .input_valid(valid_between_comp_pre_schd),
        .input_head_addr(head_addr_between_comp_pre_schd), // low bits of the head address is always 0
        .input_hash_value_vec(hash_value_vec_between_comp_pre_schd),
        .input_delim(delim_between_comp_pre_schd),
        .input_ready(ready_between_comp_pre_schd),
    
        .output_valid(valid_between_pre_schd_pe_array),
        .output_mask(mask_between_pre_schd_pe_array),
        .output_addr(addr_between_pre_schd_pe_array), 
        .output_hash_value(hash_value_between_pre_schd_pe_array), // only in hash bank part
        .output_delim(delim_between_pre_schd_pe_array),
        .output_ready(ready_between_pre_schd_pe_array) 
    );

    hash_pe_array u_hash_pe_array(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(valid_between_pre_schd_pe_array),
        .input_mask(mask_between_pre_schd_pe_array),
        .input_addr_vec(addr_between_pre_schd_pe_array),
        .input_hash_value_vec(hash_value_between_pre_schd_pe_array),
        .input_delim_vec(delim_between_pre_schd_pe_array),
        .input_ready(ready_between_pre_schd_pe_array),

        .output_valid(valid_between_pe_array_post_schd),
        .output_mask(mask_between_pe_array_post_schd),
        .output_addr_vec(addr_between_pe_array_post_schd),
        .output_history_valid_vec(history_valid_vec_between_pe_array_post_schd),
        .output_history_addr_vec(history_addr_vec_between_pe_array_post_schd),
        .output_delim_vec(delim_between_pe_array_post_schd),
        .output_ready(ready_between_pe_array_post_schd)
    );

    post_hash_pe_scheduler u_post_hash_pe_scheduler(
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),

        .input_valid(valid_between_pe_array_post_schd),
        .input_mask(mask_between_pe_array_post_schd),
        .input_addr_vec(addr_between_pe_array_post_schd),
        .input_history_valid_vec(history_valid_vec_between_pe_array_post_schd),
        .input_history_addr_vec(history_addr_vec_between_pe_array_post_schd),
        .input_delim_vec(delim_between_pe_array_post_schd),
        .input_ready(ready_between_pe_array_post_schd),
        
        .output_valid(output_valid),
        .output_head_addr(output_head_addr),
        .output_row_valid(output_row_valid),
        .output_history_valid_vec(output_history_valid_vec),
        .output_history_addr_vec(output_history_addr_vec),
        .output_delim(output_delim),
        .output_ready(output_ready)
    );

    `ifdef HASH_RESULT_LOG
        always @(posedge clk) begin
            integer log_i, log_j;
            if(output_valid && output_ready) begin
                for(log_i = 0; log_i < `HASH_ISSUE_WIDTH; log_i = log_i + 1) begin
                    for(log_j = 0; log_j < `ROW_SIZE; log_j = log_j + 1) begin
                        if(output_history_valid_vec[log_i * `ROW_SIZE + log_j]) begin
                            $display("[HashResult] head_addr=%d, hist_addr=%d, slot_idx=%d", output_head_addr + log_i, output_history_addr_vec[log_i * `ROW_SIZE * `ADDR_WIDTH + log_j * `ADDR_WIDTH +: `ADDR_WIDTH], log_j);
                        end
                    end
                end
            end
        end
    `endif
endmodule