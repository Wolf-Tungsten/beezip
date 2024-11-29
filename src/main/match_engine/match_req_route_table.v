`include "parameters.vh"
`include "util.vh"

module match_req_route_table (
    input wire [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] offset,
    output wire [`LAZY_LEN*`NUM_MATCH_REQ_CH-1:0] route_map
);
    wire [`SEQ_OFFSET_BITS-1:0] channel_lower_bound [`NUM_MATCH_REQ_CH-1:0];
    wire [`SEQ_OFFSET_BITS-1:0] channel_upper_bound [`NUM_MATCH_REQ_CH-1:0];
    

    assign channel_lower_bound[0] = 0;
    assign channel_upper_bound[0] = 2 ** `MATCH_PE_0_SIZE_LOG2 - 768;
    assign channel_lower_bound[1] = 0;
    assign channel_upper_bound[1] = 2 ** `MATCH_PE_1_SIZE_LOG2 - 768; // 32 KB
    assign channel_lower_bound[2] = 0;
    assign channel_upper_bound[2] = 2 ** `MATCH_PE_2_SIZE_LOG2 - 768; // 64 KB
    assign channel_lower_bound[3] = 2 ** `MATCH_PE_2_SIZE_LOG2 - 768;
    assign channel_upper_bound[3] = 2 ** `MATCH_PE_3_SIZE_LOG2 - 1; // 1 MB

    genvar i, j;
    generate
        for(i = 0; i < `LAZY_LEN; i = i + 1) begin: ROUTE_MAP_GEN
            for(j = 0; j < `NUM_MATCH_REQ_CH; j = j + 1) begin: CHANNEL_GEN
                // assign route_map[i*`NUM_MATCH_REQ_CH + j] = 
                // `VEC_SLICE(offset, i, `SEQ_OFFSET_BITS) >= channel_lower_bound[j] && 
                // `VEC_SLICE(offset, i, `SEQ_OFFSET_BITS) < channel_upper_bound[j];
            end
            assign route_map[i*`NUM_MATCH_REQ_CH +: `NUM_MATCH_REQ_CH] = 4'b1000;
            // enforce map to shared match pe to help debug
        end
    endgenerate
endmodule