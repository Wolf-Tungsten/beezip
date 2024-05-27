`include "parameters.vh"

module pre_hash_pe_scheduler(
        input wire clk,
        input wire rst_n,

        input wire [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num, 

        input wire input_valid,
        input wire [`ADDR_WIDTH-1:0] input_head_addr, // low bits of the head address is always 0
        input wire [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] input_hash_value_vec,
        input wire input_delim,
        output wire input_ready,

        output wire output_valid,
        output wire [`NUM_HASH_PE-1:0] output_mask,
        output wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] output_addr,
        output wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] output_hash_value, 
        output wire [`NUM_HASH_PE-1:0] output_delim,
        input wire output_ready
    );

    // input - stage 0

    reg [`ADDR_WIDTH-1:0]     stage_0_head_addr_in;
    reg [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] stage_0_hash_value_vec_in;
    reg stage_0_delim_in;
    reg [`HASH_ISSUE_WIDTH*`NUM_HASH_PE-1:0] stage_0_mask_vec_in;
    wire stage_0_valid_out, stage_0_ready_out;
    wire [`ADDR_WIDTH-1:0] stage_0_head_addr_out;
    wire [`HASH_BITS*`HASH_ISSUE_WIDTH-1:0] stage_0_hash_value_vec_out;
    wire stage_0_delim_out;
    wire [`HASH_ISSUE_WIDTH*`NUM_HASH_PE-1:0] stage_0_mask_vec_out;


    forward_reg #(.W(`ADDR_WIDTH+`HASH_BITS*`HASH_ISSUE_WIDTH+1+`HASH_ISSUE_WIDTH*`NUM_HASH_PE)) stage_0_forward_reg (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_payload({stage_0_head_addr_in, stage_0_hash_value_vec_in, stage_0_delim_in, stage_0_mask_vec_in}),

        .output_valid(stage_0_valid_out),
        .output_ready(stage_0_ready_out),
        .output_payload({stage_0_head_addr_out, stage_0_hash_value_vec_out, stage_0_delim_out, stage_0_mask_vec_out})
    );

    reg [`HASH_BITS-1:0] hash_value_arr [`HASH_ISSUE_WIDTH-1:0];
    always @(*) begin: pre_schd_stage_0_input_logic
        integer i, j;
        stage_0_head_addr_in = input_head_addr;
        stage_0_hash_value_vec_in = input_hash_value_vec;
        stage_0_delim_in = input_delim;
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
            hash_value_arr[i] = input_hash_value_vec[i*`HASH_BITS +: `HASH_BITS];
        end
        for(i = 0; i < `NUM_HASH_PE; i = i+1) begin
            for(j = 0; j < `HASH_ISSUE_WIDTH; j = j+1) begin
                stage_0_mask_vec_in[i*`HASH_ISSUE_WIDTH+j] = hash_value_arr[j][`HASH_BITS-1 -: `NUM_HASH_PE_LOG2] == i;
            end
        end
    end

    // stage 0 - hash_pe_request_serializer
    wire [`NUM_HASH_PE-1:0] hprs_ready_in;
    wire [`NUM_HASH_PE-1:0] hprs_valid_out;
    wire [`ADDR_WIDTH*`NUM_HASH_PE-1:0] hprs_addr_out;
    wire [`NUM_HASH_PE*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] hprs_hash_value_out; 
    wire [`NUM_HASH_PE-1:0] hprs_delim_out;
    wire [`NUM_HASH_PE-1:0] hprs_ready_out;

    assign stage_0_ready_out = &hprs_ready_in; 

    wire [`HASH_ISSUE_WIDTH*(`HASH_BITS-`NUM_HASH_PE_LOG2)-1:0] hprs_hash_value_vec_in;

    genvar gi;
    generate
        for(gi = 0; gi < `HASH_ISSUE_WIDTH; gi = gi + 1) begin
            assign hprs_hash_value_vec_in[gi * (`HASH_BITS-`NUM_HASH_PE_LOG2) +: (`HASH_BITS-`NUM_HASH_PE_LOG2)] = 
            stage_0_hash_value_vec_out[gi * `HASH_BITS +: `HASH_BITS-`NUM_HASH_PE_LOG2];
        end
    endgenerate

    hash_pe_request_serializer hprs_inst[`NUM_HASH_PE-1:0] (
        .clk(clk),
        .rst_n(rst_n),

        .cfg_max_queued_req_num(cfg_max_queued_req_num),

        .input_valid(stage_0_valid_out & stage_0_ready_out),
        .input_head_addr(stage_0_head_addr_out),
        .input_mask_vec(stage_0_mask_vec_out),
        .input_hash_value_vec(hprs_hash_value_vec_in),
        .input_delim(stage_0_delim_out),
        .input_ready(hprs_ready_in),

        .output_valid(hprs_valid_out),
        .output_addr(hprs_addr_out),
        .output_hash_value(hprs_hash_value_out),
        .output_delim(hprs_delim_out),
        .output_ready(hprs_ready_out)
    );
    
    // hash_pe_request_serializer - pingpong buffer - output
    wire pingpong_reg_input_ready;
    wire pingpong_reg_input_valid;
    assign pingpong_reg_input_valid = |hprs_valid_out;
    assign hprs_ready_out = {`NUM_HASH_PE{pingpong_reg_input_ready}};

    pingpong_reg #(.W(`NUM_HASH_PE*(1+`ADDR_WIDTH+`HASH_BITS-`NUM_HASH_PE_LOG2+1))) stage_1_pingpong_reg(
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(pingpong_reg_input_valid),
        .input_payload({hprs_valid_out, hprs_addr_out, hprs_hash_value_out, hprs_delim_out}),
        .input_ready(pingpong_reg_input_ready),

        .output_valid(output_valid),
        .output_payload({output_mask, output_addr, output_hash_value, output_delim}),
        .output_ready(output_ready)
    );
    


endmodule
