`include "parameters.vh"
`include "util.vh"

module match_req_route_table (
    input wire [`LAZY_LEN*`SEQ_OFFSET_BITS-1:0] offset,
    output wire [`LAZY_LEN*`NUM_MATCH_REQ_CH-1:0] route_map
);
    wire [`SEQ_OFFSET_BITS-1:0] channel_lower_bound [`NUM_MATCH_REQ_CH-1:0];
    wire [`SEQ_OFFSET_BITS-1:0] channel_upper_bound [`NUM_MATCH_REQ_CH-1:0];
    

    assign channel_lower_bound[0] = 0;
    assign channel_upper_bound[0] = 1 << 12; // 4 KB
    assign channel_lower_bound[1] = 0;
    assign channel_upper_bound[1] = 1 << 16; // 64 KB
    assign channel_lower_bound[2] = 0;
    assign channel_upper_bound[2] = 1 << 15; // 64 KB
    assign channel_lower_bound[3] = 1 << 15;
    assign channel_upper_bound[3] = 1 << 20; // 1 MB

    genvar i, j;
    generate
        for(i = 0; i < `LAZY_LEN; i = i + 1) begin: ROUTE_MAP_GEN
            for(j = 0; j < `NUM_MATCH_REQ_CH; j = j + 1) begin: CHANNEL_GEN
                assign route_map[i*`NUM_MATCH_REQ_CH + j] = 
                `VEC_SLICE(offset, i, `SEQ_OFFSET_BITS) >= channel_lower_bound[j] && 
                `VEC_SLICE(offset, i, `SEQ_OFFSET_BITS) < channel_upper_bound[j];
            end
        end
    endgenerate
endmodule