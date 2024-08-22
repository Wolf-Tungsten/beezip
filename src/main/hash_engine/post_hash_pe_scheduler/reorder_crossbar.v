`include "parameters.vh"
`include "log.vh"

module single_crossbar (
    input wire clk,
    input wire rst_n,

    input wire input_valid,
    input wire [`NUM_HASH_PE-1:0] input_mask,
    input wire [`NUM_HASH_PE-1:0] input_history_valid,
    input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_history_addr,
    input wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] input_meta_match_len,
    input wire [`NUM_HASH_PE-1:0] input_meta_match_can_ext,
    output wire input_ready,

    output wire output_valid,
    output wire output_row_valid,
    output wire output_history_valid,
    output wire [`ADDR_WIDTH-1:0] output_history_addr,
    output wire [`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len,
    output wire output_meta_match_can_ext,
    input wire output_ready
);

    localparam CROSSBAR_STAGE = (`NUM_HASH_PE_LOG2 + $clog2(`HASH_CROSSBAR_FACTOR)) / $clog2(`HASH_CROSSBAR_FACTOR);

    wire stage_valid[CROSSBAR_STAGE+1-1:0];
    wire stage_ready[CROSSBAR_STAGE+1-1:0];

    wire [`NUM_HASH_PE-1:0] stage_in_mask[CROSSBAR_STAGE+1-1:0];
    wire [`NUM_HASH_PE-1:0] stage_in_history_valid[CROSSBAR_STAGE+1-1:0];
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] stage_in_history_addr[CROSSBAR_STAGE+1-1:0];
    wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] stage_in_meta_match_len[CROSSBAR_STAGE+1-1:0];    
    wire [`NUM_HASH_PE-1:0] stage_in_meta_match_can_ext[CROSSBAR_STAGE+1-1:0];

    wire [`NUM_HASH_PE-1:0] stage_mux_mask[CROSSBAR_STAGE-1:0];
    wire [`NUM_HASH_PE-1:0] stage_mux_history_valid[CROSSBAR_STAGE-1:0];
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] stage_mux_history_addr[CROSSBAR_STAGE-1:0];
    wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] stage_mux_meta_match_len[CROSSBAR_STAGE-1:0];
    wire [`NUM_HASH_PE-1:0] stage_mux_meta_match_can_ext[CROSSBAR_STAGE-1:0];

    genvar i, j;
    generate
        for(i = 0; i < CROSSBAR_STAGE; i = i+1) begin: stage_gen_block
            localparam in_num = `NUM_HASH_PE / (2 ** (i * $clog2(`HASH_CROSSBAR_FACTOR)));
            localparam out_num = (in_num > `HASH_CROSSBAR_FACTOR) ? (in_num / `HASH_CROSSBAR_FACTOR) : 1;
            localparam factor = in_num / out_num;
            for(j = 0; j < out_num; j = j+1) begin: stage_mux_gen_block
                // in -mux1h-> mux -pingpong_reg-> in+1
                assign stage_mux_mask[i][j] = |(stage_in_mask[i][j * factor +: factor]);
                mux1h #(.P_CNT(factor), .P_W(1)) history_valid_mux1h (
                    .input_payload_vec(stage_in_history_valid[i][j * factor +: factor]),
                    .input_select_vec(stage_in_mask[i][j * factor +: factor]),
                    .output_payload(stage_mux_history_valid[i][j])
                );
                mux1h #(.P_CNT(factor), .P_W(`ADDR_WIDTH)) history_addr_mux1h (
                    .input_payload_vec(stage_in_history_addr[i][j * factor * `ADDR_WIDTH +: factor * `ADDR_WIDTH]),
                    .input_select_vec(stage_in_mask[i][j * factor +: factor]),
                    .output_payload(stage_mux_history_addr[i][j * `ADDR_WIDTH +: `ADDR_WIDTH])
                );
                mux1h #(.P_CNT(factor), .P_W(`META_MATCH_LEN_WIDTH)) meta_match_len_mux1h (
                    .input_payload_vec(stage_in_meta_match_len[i][j * factor * `META_MATCH_LEN_WIDTH +: factor * `META_MATCH_LEN_WIDTH]),
                    .input_select_vec(stage_in_mask[i][j * factor +: factor]),
                    .output_payload(stage_mux_meta_match_len[i][j * `META_MATCH_LEN_WIDTH +: `META_MATCH_LEN_WIDTH])
                );
                mux1h #(.P_CNT(factor), .P_W(1)) meta_match_can_ext_mux1h (
                    .input_payload_vec(stage_in_meta_match_can_ext[i][j * factor +: factor]),
                    .input_select_vec(stage_in_mask[i][j * factor +: factor]),
                    .output_payload(stage_mux_meta_match_can_ext[i][j])
                );
            end
            handshake_slice_reg #(.W(out_num*(1+(1 + `ADDR_WIDTH + `META_MATCH_LEN_WIDTH + 1)))
            , .DEPTH(2)) stage_reg (

                .clk(clk),
                .rst_n(rst_n),

                .input_valid(stage_valid[i]),
                .input_payload({stage_mux_mask[i][0 +: out_num], 
                stage_mux_history_valid[i][0 +: out_num], 
                stage_mux_history_addr[i][0 +: out_num * `ADDR_WIDTH], 
                stage_mux_meta_match_len[i][0 +: out_num * `META_MATCH_LEN_WIDTH],
                stage_mux_meta_match_can_ext[i][0 +: out_num]}),
                .input_ready(stage_ready[i]),

                .output_valid(stage_valid[i+1]),
                .output_payload({stage_in_mask[i+1][0 +: out_num], 
                stage_in_history_valid[i+1][0 +: out_num], 
                stage_in_history_addr[i+1][0 +: out_num * `ADDR_WIDTH], 
                stage_in_meta_match_len[i+1][0 +: out_num * `META_MATCH_LEN_WIDTH],
                stage_in_meta_match_can_ext[i+1][0 +: out_num]}),
                .output_ready(stage_ready[i+1])

            );
        end
    endgenerate
    assign stage_valid[0] = input_valid;
    assign input_ready = stage_ready[0];
    assign stage_in_mask[0] = input_mask;
    assign stage_in_history_valid[0] = input_history_valid;
    assign stage_in_history_addr[0] = input_history_addr;
    assign stage_in_meta_match_len[0] = input_meta_match_len;
    assign stage_in_meta_match_can_ext[0] = input_meta_match_can_ext;

    assign output_valid = stage_valid[CROSSBAR_STAGE];
    assign stage_ready[CROSSBAR_STAGE] = output_ready;
    assign output_row_valid = stage_in_mask[CROSSBAR_STAGE][0];
    assign output_history_valid = stage_in_history_valid[CROSSBAR_STAGE][0];
    assign output_history_addr = stage_in_history_addr[CROSSBAR_STAGE][0 +:  `ADDR_WIDTH];
    assign output_meta_match_len = stage_in_meta_match_len[CROSSBAR_STAGE][0 +:  `META_MATCH_LEN_WIDTH];
    assign output_meta_match_can_ext = stage_in_meta_match_can_ext[CROSSBAR_STAGE][0];

endmodule

module reorder_crossbar (
    input wire clk,
    input wire rst_n,

    input wire input_valid,
    input wire [`NUM_HASH_PE-1:0] input_mask,
    input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_addr,
    input wire [`NUM_HASH_PE-1:0] input_history_valid,
    input wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] input_history_addr,
    input wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] input_meta_match_len,
    input wire [`NUM_HASH_PE-1:0] input_meta_match_can_ext,
    input wire [`NUM_HASH_PE-1:0] input_delim,
    input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
    output wire input_ready,

    output wire output_valid,
    output wire [`ADDR_WIDTH-1:0] output_head_addr,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_row_valid,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_history_valid,
    output wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] output_history_addr,
    output wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] output_meta_match_len,
    output wire [`HASH_ISSUE_WIDTH-1:0] output_meta_match_can_ext,
    output wire [`HASH_ISSUE_WIDTH*8-1:0] output_data,
    output wire output_delim,
    input wire output_ready
);

    reg [`HASH_ISSUE_WIDTH*`NUM_HASH_PE-1:0] mask_stage_mask_input;
    reg [`ADDR_WIDTH-1:0] mask_stage_head_addr_input;
    reg mask_stage_delim_input;

    wire mask_stage_valid;
    wire [`HASH_ISSUE_WIDTH*`NUM_HASH_PE-1:0] mask_stage_mask;
    wire [`ADDR_WIDTH-1:0] mask_stage_head_addr;
    wire [`NUM_HASH_PE-1:0] mask_stage_history_valid;
    wire [`NUM_HASH_PE*`ADDR_WIDTH-1:0] mask_stage_history_addr;
    wire [`NUM_HASH_PE*`META_MATCH_LEN_WIDTH-1:0] mask_stage_meta_match_len;
    wire [`NUM_HASH_PE-1:0] mask_stage_meta_match_can_ext;
    wire mask_stage_delim;
    wire [`HASH_ISSUE_WIDTH*8-1:0] mask_stage_data;
    wire mask_stage_ready;

    always @(*) begin: crossbar_mask_logic
       integer i,j;
       mask_stage_head_addr_input = 0;
       mask_stage_delim_input = 0;
       for(i = 0; i < `NUM_HASH_PE; i = i+1) begin : crossbar_mask_outter_loop
            mask_stage_head_addr_input = mask_stage_head_addr_input | {`ADDR_WIDTH{input_mask[i]}} & input_addr[i * `ADDR_WIDTH +: `ADDR_WIDTH];
            mask_stage_delim_input = mask_stage_delim_input | (input_mask[i] & input_delim[i]);
            for(j = 0; j < `HASH_ISSUE_WIDTH; j = j+1) begin : crossbar_mask_inner_loop
                mask_stage_mask_input[j * `NUM_HASH_PE + i] = input_mask[i] && (input_addr[i * `ADDR_WIDTH +: `HASH_ISSUE_WIDTH_LOG2] == j[`HASH_ISSUE_WIDTH_LOG2-1:0]);
            end
       end
       mask_stage_head_addr_input = mask_stage_head_addr_input & {{(`ADDR_WIDTH-`HASH_ISSUE_WIDTH_LOG2){1'b1}}, {`HASH_ISSUE_WIDTH_LOG2{1'b0}}}; 
    end

    forward_reg #(.W(`ADDR_WIDTH + 
    `NUM_HASH_PE * `HASH_ISSUE_WIDTH + 
    `NUM_HASH_PE*(1 + `ADDR_WIDTH + `META_MATCH_LEN_WIDTH + 1) + 1 + 
    `HASH_ISSUE_WIDTH*8)) mask_stage_reg (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_payload({mask_stage_head_addr_input, 
                        mask_stage_mask_input,
                        input_history_valid, input_history_addr, 
                        input_meta_match_len, input_meta_match_can_ext, 
                        mask_stage_delim_input, 
                        input_data}),
        .input_ready(input_ready),
        .output_valid(mask_stage_valid),
        .output_payload({mask_stage_head_addr, 
                        mask_stage_mask, 
                        mask_stage_history_valid, mask_stage_history_addr,
                        mask_stage_meta_match_len, mask_stage_meta_match_can_ext,
                        mask_stage_delim,
                        mask_stage_data
                        }),
        .output_ready(mask_stage_ready)
    );

    

    wire [`HASH_ISSUE_WIDTH-1:0] crossbar_input_ready, crossbar_output_valid;

    wire [`HASH_ISSUE_WIDTH-1:0] crossbar_output_row_valid;
    wire [`HASH_ISSUE_WIDTH-1:0] crossbar_output_history_valid;
    wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] crossbar_output_history_addr;
    wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] crossbar_output_meta_match_len;
    wire [`HASH_ISSUE_WIDTH-1:0] crossbar_output_meta_match_can_ext;


    wire crossbar_output_ready;
    
    single_crossbar sc_inst [`HASH_ISSUE_WIDTH-1:0] (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(mask_stage_valid),
        .input_mask(mask_stage_mask),
        .input_history_valid(mask_stage_history_valid),
        .input_history_addr(mask_stage_history_addr),
        .input_meta_match_len(mask_stage_meta_match_len),
        .input_meta_match_can_ext(mask_stage_meta_match_can_ext),
        .input_ready(crossbar_input_ready),

        .output_valid(crossbar_output_valid),
        .output_row_valid(crossbar_output_row_valid),
        .output_history_valid(crossbar_output_history_valid),
        .output_history_addr(crossbar_output_history_addr),
        .output_meta_match_len(crossbar_output_meta_match_len),
        .output_meta_match_can_ext(crossbar_output_meta_match_can_ext),
        .output_ready(crossbar_output_ready)
    );

    localparam CROSSBAR_STAGE = (`NUM_HASH_PE_LOG2 + $clog2(`HASH_CROSSBAR_FACTOR)) / $clog2(`HASH_CROSSBAR_FACTOR);

    wire crossbar_bypass_valid[CROSSBAR_STAGE+1-1:0];
    wire crossbar_bypass_ready[CROSSBAR_STAGE+1-1:0];
    wire [`ADDR_WIDTH-1:0] crossbar_bypass_head_addr[CROSSBAR_STAGE+1-1:0];
    wire crossbar_bypass_delim[CROSSBAR_STAGE+1-1:0];
    wire [`HASH_ISSUE_WIDTH*8-1:0] crossbar_bypass_data[CROSSBAR_STAGE+1-1:0];

    assign crossbar_bypass_valid[0] = mask_stage_valid;
    assign crossbar_bypass_data[0] = mask_stage_data;
    assign crossbar_bypass_head_addr[0] = mask_stage_head_addr;
    assign crossbar_bypass_delim[0] = mask_stage_delim;
    assign mask_stage_ready = crossbar_bypass_ready[0];
    
    assign crossbar_bypass_ready[CROSSBAR_STAGE] = crossbar_output_ready;
    
    genvar gi;
    generate
        for(gi = 0; gi < CROSSBAR_STAGE; gi = gi + 1) begin
            handshake_slice_reg #(.W(`ADDR_WIDTH+1+`HASH_ISSUE_WIDTH*8), .DEPTH(2)) crossbar_bypass_reg (
                .clk(clk),
                .rst_n(rst_n),

                .input_valid(crossbar_bypass_valid[gi]),
                .input_payload({crossbar_bypass_head_addr[gi], crossbar_bypass_delim[gi], crossbar_bypass_data[gi]}),
                .input_ready(crossbar_bypass_ready[gi]),

                .output_valid(crossbar_bypass_valid[gi+1]),
                .output_payload({crossbar_bypass_head_addr[gi+1], crossbar_bypass_delim[gi+1], crossbar_bypass_data[gi+1]}),
                .output_ready(crossbar_bypass_ready[gi+1])
            );
        end
    endgenerate
   
    // crossbar architecture
    // always @(*) begin: crossbar_logic
    //     integer i, j;
    //     crossbar_stage_row_valid = 0;
    //     crossbar_stage_history_valid_vec = 0;
    //     crossbar_stage_history_addr_vec = 0;
    //     crossbar_stage_meta_match_len_vec = 0;
    //     crossbar_stage_meta_match_can_ext_vec = 0;
    //     crossbar_stage_delim = mask_stage_delim;
    //     for(i = 0; i < `NUM_HASH_PE; i = i+1) begin : crossbar_outter_loop
    //         for(j = 0; j < `HASH_ISSUE_WIDTH; j = j+1) begin : crossbar_inner_loop
    //             reg dst_match;
    //             dst_match = mask_stage_mask[j * `NUM_HASH_PE + i];
    //             crossbar_stage_row_valid[j] = crossbar_stage_row_valid[j] | dst_match;
    //             crossbar_stage_history_valid_vec[j * `ROW_SIZE +: `ROW_SIZE] = crossbar_stage_history_valid_vec[j * `ROW_SIZE +: `ROW_SIZE] | {`ROW_SIZE{dst_match}} & mask_stage_history_valid_vec[i * `ROW_SIZE +: `ROW_SIZE];
    //             crossbar_stage_history_addr_vec[j * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH] = crossbar_stage_history_addr_vec[j * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH] | {(`ROW_SIZE*`ADDR_WIDTH){dst_match}} & mask_stage_history_addr_vec[i * `ROW_SIZE * `ADDR_WIDTH +: `ROW_SIZE * `ADDR_WIDTH];
    //             crossbar_stage_meta_match_len_vec[j * `ROW_SIZE * `META_MATCH_LEN_WIDTH +: `ROW_SIZE * `META_MATCH_LEN_WIDTH] = crossbar_stage_meta_match_len_vec[j * `ROW_SIZE * `META_MATCH_LEN_WIDTH +: `ROW_SIZE * `META_MATCH_LEN_WIDTH] | {(`ROW_SIZE*`META_MATCH_LEN_WIDTH){dst_match}} & mask_stage_meta_match_len_vec[i * `ROW_SIZE * `META_MATCH_LEN_WIDTH +: `ROW_SIZE * `META_MATCH_LEN_WIDTH];
    //             crossbar_stage_meta_match_can_ext_vec[j * `ROW_SIZE +: `ROW_SIZE] = crossbar_stage_meta_match_can_ext_vec[j * `ROW_SIZE +: `ROW_SIZE] | {`ROW_SIZE{dst_match}} & mask_stage_meta_match_can_ext_vec[i * `ROW_SIZE +: `ROW_SIZE];
    //         end
    //     end
        
    // end

    pingpong_reg #(.W(`ADDR_WIDTH+`HASH_ISSUE_WIDTH*(1+(1+`ADDR_WIDTH+`META_MATCH_LEN_WIDTH+1))+1+`HASH_ISSUE_WIDTH*8)) stage_reg (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(crossbar_bypass_valid[CROSSBAR_STAGE]),
        .input_payload({crossbar_bypass_head_addr[CROSSBAR_STAGE], 
        crossbar_output_row_valid,
        crossbar_output_history_valid, crossbar_output_history_addr,
        crossbar_output_meta_match_len, crossbar_output_meta_match_can_ext,
        crossbar_bypass_delim[CROSSBAR_STAGE],
        crossbar_bypass_data[CROSSBAR_STAGE]}),
        .input_ready(crossbar_output_ready),
        .output_valid(output_valid),
        .output_payload({output_head_addr, 
        output_row_valid, output_history_valid, 
        output_history_addr, output_meta_match_len, 
        output_meta_match_can_ext, output_delim, output_data}),
        .output_ready(output_ready)
    );
    
endmodule
