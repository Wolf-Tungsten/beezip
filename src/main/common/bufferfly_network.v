// bufferfly_network a buffered butterfly network.

module butterfly_coordinator #(parameter W=8, MAX_DST_W=4, DST_IDX=3)
    (
        // input channel 0
        input wire                 input_0_valid  ,
        input wire [MAX_DST_W-1:0] input_0_dst    ,
        input wire [W-1:0]         input_0_payload,
        output wire                input_0_ready  ,

        // input channel 1
        input wire                 input_1_valid  ,
        input wire [MAX_DST_W-1:0] input_1_dst    ,
        input wire [W-1:0]         input_1_payload, 
        output wire                input_1_ready  ,

        // output channel 0
        output wire                 output_0_valid  ,
        output wire [MAX_DST_W-1:0] output_0_dst    ,
        output wire [W-1:0]         output_0_payload,
        input wire                  output_0_ready  ,

        // output channel 1
        output wire                 output_1_valid  ,
        output wire [MAX_DST_W-1:0] output_1_dst    ,
        output wire [W-1:0]         output_1_payload,
        input wire                  output_1_ready
    );

    wire valid_0_to_0 = input_0_valid && (input_0_dst[DST_IDX] == 0);  // from input_0 to output_0
    wire valid_0_to_1 = input_0_valid && (input_0_dst[DST_IDX] == 1);  // from input_0 to output_1
    wire valid_1_to_0 = input_1_valid && (input_1_dst[DST_IDX] == 0);  // from input_1 to output_0
    wire valid_1_to_1 = input_1_valid && (input_1_dst[DST_IDX] == 1);  // from input_1 to output_1

    wire ready_0_to_0 = output_0_ready && (input_0_dst[DST_IDX] == 0);                   // from output_0 to input_0
    wire ready_1_to_0 = output_1_ready && (input_0_dst[DST_IDX] == 1);                   // from output_1 to input_0
    wire ready_0_to_1 = output_0_ready && (input_1_dst[DST_IDX] == 0) && ~valid_0_to_0;  // from output_0 to input_1
    wire ready_1_to_1 = output_1_ready && (input_1_dst[DST_IDX] == 1) && ~valid_0_to_1;  // from output_1 to input_1
    

    assign output_0_valid = valid_0_to_0 || valid_1_to_0;
    assign output_1_valid = valid_0_to_1 || valid_1_to_1;

    assign input_0_ready = ready_0_to_0 || ready_1_to_0;
    assign input_1_ready = ready_0_to_1 || ready_1_to_1;


    assign output_0_payload = valid_0_to_0 ? input_0_payload : input_1_payload;
    assign output_1_payload = valid_0_to_1 ? input_0_payload : input_1_payload;

    assign output_0_dst = {{(MAX_DST_W-DST_IDX){1'b0}}, (valid_0_to_0 ? input_0_dst[DST_IDX:0] : input_1_dst[DST_IDX:0])};
    assign output_1_dst = {{(MAX_DST_W-DST_IDX){1'b0}}, (valid_0_to_1 ? input_0_dst[DST_IDX:0] : input_1_dst[DST_IDX:0])};


endmodule

module bufferfly_network #(parameter NETWORK_WIDTH_LOG2=3, W=8)
(
        input wire clk,
        input wire rst_n,

        // all input channel
        input wire  [2**NETWORK_WIDTH_LOG2-1:0]                      input_valid_vec  ,
        input wire  [NETWORK_WIDTH_LOG2*(2**NETWORK_WIDTH_LOG2)-1:0] input_dst_vec    ,
        input wire  [W*(2**NETWORK_WIDTH_LOG2)-1:0]                  input_payload_vec,
        output wire [2**NETWORK_WIDTH_LOG2-1:0]                      input_ready_vec  ,

        // all output channel
        output wire [2**NETWORK_WIDTH_LOG2-1:0]     output_valid_vec  ,
        output wire [W*(2**NETWORK_WIDTH_LOG2)-1:0] output_payload_vec,
        input wire  [2**NETWORK_WIDTH_LOG2-1:0]     output_ready_vec
    );
    localparam DST_WIDTH     = NETWORK_WIDTH_LOG2;
    localparam NETWORK_WIDTH = 2**NETWORK_WIDTH_LOG2;   // network width
    localparam LAYER         = NETWORK_WIDTH_LOG2+1;    // network layer
    
    // row major
    wire buffer_input_valid_vec[LAYER][NETWORK_WIDTH];
    wire buffer_input_ready_vec[LAYER][NETWORK_WIDTH];
    wire [DST_WIDTH-1:0] buffer_input_dst_vec[LAYER][NETWORK_WIDTH];
    wire [W-1:0] buffer_input_payload_vec[LAYER][NETWORK_WIDTH];
    

    wire buffer_output_valid_vec[LAYER][NETWORK_WIDTH];
    wire buffer_output_ready_vec[LAYER][NETWORK_WIDTH];
    wire [DST_WIDTH-1:0] buffer_output_dst_vec[LAYER-1][NETWORK_WIDTH];
    wire [W-1:0] buffer_output_payload_vec[LAYER][NETWORK_WIDTH];
    

    // connect input and output
    genvar i,j;
    generate
        for(i = 0; i < NETWORK_WIDTH; i = i+1) begin : connect_input_output
            assign buffer_input_valid_vec[0][i]   = input_valid_vec[i];
            assign buffer_input_dst_vec[0][i]     = input_dst_vec[i*DST_WIDTH +: DST_WIDTH];
            assign buffer_input_payload_vec[0][i] = input_payload_vec[i*W +: W];
            assign input_ready_vec[i] = buffer_input_ready_vec[0][i];

            assign output_valid_vec[i]          = buffer_output_valid_vec[LAYER-1][i];
            assign output_payload_vec[i*W +: W] = buffer_output_payload_vec[LAYER-1][i];
            assign buffer_output_ready_vec[LAYER-1][i] = output_ready_vec[i];
        end
    endgenerate

    // generate 0 .. LAYER-2 buffers
    genvar layer;
    generate 
        for(layer = 0; layer < LAYER - 1; layer = layer + 1) begin : buffer_for_each_layer
            for(i = 0; i < NETWORK_WIDTH; i = i + 1) begin : buffer_for_each_node_in_one_layer
                pingpong_reg #(.W(W + DST_WIDTH)) pingpong_reg_inst (
                                 .clk(clk),
                                 .rst_n(rst_n),

                                 .input_valid  (buffer_input_valid_vec[layer][i]),
                                 .input_payload({buffer_input_payload_vec[layer][i],buffer_input_dst_vec[layer][i]}),
                                 .input_ready  (buffer_input_ready_vec[layer][i]),

                                 .output_valid  (buffer_output_valid_vec[layer][i]),
                                 .output_payload({buffer_output_payload_vec[layer][i],buffer_output_dst_vec[layer][i]}),
                                 .output_ready  (buffer_output_ready_vec[layer][i])
                             );
            end
        end
    endgenerate

    // generate last layer
    generate
        for(i = 0; i < NETWORK_WIDTH; i = i+1) begin : buffer_for_each_node_in_last_layer
            pingpong_reg #(.W(W)) pingpong_reg_inst (
                             .clk(clk),
                             .rst_n(rst_n),
                             .input_valid  (buffer_input_valid_vec[LAYER-1][i]),
                             .input_payload(buffer_input_payload_vec[LAYER-1][i]),
                             .input_ready  (buffer_input_ready_vec[LAYER-1][i]),

                             .output_valid  (buffer_output_valid_vec[LAYER-1][i]),
                             .output_payload(buffer_output_payload_vec[LAYER-1][i]),
                             .output_ready  (buffer_output_ready_vec[LAYER-1][i])
                         );
        end
    endgenerate

    // construct butterfly network
    genvar group_idx, in_group_idx;
    generate
        for(layer = 0; layer < LAYER-1; layer = layer + 1) begin : butterfly_network
            localparam group_num = 2**layer;
            localparam group_size = NETWORK_WIDTH / group_num / 2;
            localparam butterfly_gap = group_size;
            for(group_idx = 0; group_idx < group_num ; group_idx = group_idx + 1) begin
                for(in_group_idx = 0; in_group_idx < group_size; in_group_idx = in_group_idx + 1) begin
                    localparam top_idx = group_idx * group_size * 2 + in_group_idx;
                    localparam btm_idx = top_idx + butterfly_gap;
                    butterfly_coordinator #(.W(W), .MAX_DST_W(DST_WIDTH), .DST_IDX(DST_WIDTH-layer-1)) coordinator (
                        .input_0_valid  (buffer_output_valid_vec[layer][top_idx]),
                        .input_0_dst    (buffer_output_dst_vec[layer][top_idx]),
                        .input_0_payload(buffer_output_payload_vec[layer][top_idx]),
                        .input_0_ready  (buffer_output_ready_vec[layer][top_idx]),

                        .input_1_valid  (buffer_output_valid_vec[layer][btm_idx]),
                        .input_1_dst    (buffer_output_dst_vec[layer][btm_idx]),
                        .input_1_payload(buffer_output_payload_vec[layer][btm_idx]),
                        .input_1_ready  (buffer_output_ready_vec[layer][btm_idx]),

                        .output_0_valid  (buffer_input_valid_vec[layer+1][top_idx]),
                        .output_0_dst    (buffer_input_dst_vec[layer+1][top_idx]),
                        .output_0_payload(buffer_input_payload_vec[layer+1][top_idx]),
                        .output_0_ready  (buffer_input_ready_vec[layer+1][top_idx]),

                        .output_1_valid  (buffer_input_valid_vec[layer+1][btm_idx]),
                        .output_1_dst    (buffer_input_dst_vec[layer+1][btm_idx]),
                        .output_1_payload(buffer_input_payload_vec[layer+1][btm_idx]),
                        .output_1_ready  (buffer_input_ready_vec[layer+1][btm_idx])
                    );
                end
            end
        end
    endgenerate

endmodule
