`include "parameters.vh"
`include "util.vh"
`default_nettype none

module switch_fifo #(parameter ADDR_WIDTH=`ADDR_WIDTH, parameter SWITCH_IDX_WIDTH=2)
    (input wire clk,
     input wire rst_n,
     input wire input_valid,
     input wire [SWITCH_IDX_WIDTH-1:0] input_dst_idx,
     input wire input_is_ext,
     input wire [SWITCH_IDX_WIDTH-1:0] input_slot_idx,
     input wire [ADDR_WIDTH-1:0] input_head_addr,
     input wire [ADDR_WIDTH-1:0] input_history_addr,
     output wire input_ready,
     output wire output_valid,
     output wire [SWITCH_IDX_WIDTH-1:0] output_dst_idx,
     output wire output_is_ext,
     output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx,
     output wire [ADDR_WIDTH-1:0] output_head_addr,
     output wire [ADDR_WIDTH-1:0] output_history_addr,
     input wire output_ready
    );

    localparam PAYLOAD_WIDTH = (SWITCH_IDX_WIDTH*2+1+ADDR_WIDTH*2);
    // reg
    reg head_ptr, tail_ptr;
    reg [1:0] count_reg;
    reg [PAYLOAD_WIDTH-1:0] buffer[1:0];

    assign input_ready = count_reg < 2'b10;
    assign output_valid = count_reg > 2'b0;
    assign {output_dst_idx, output_is_ext, output_slot_idx, output_head_addr, output_history_addr} = buffer[head_ptr];

    always @(posedge clk) begin
        if (!rst_n) begin
            head_ptr <= `TD 1'b0;
            tail_ptr <= `TD 1'b0;
            count_reg <= `TD 2'b0;
        end
        else begin
            if (input_valid && input_ready) begin
                buffer[tail_ptr] <= `TD {input_dst_idx, input_is_ext, input_slot_idx, input_head_addr, input_history_addr};
                tail_ptr <= `TD ~tail_ptr;
            end
            if (output_valid && output_ready) begin
                head_ptr <= `TD ~head_ptr;
            end
            if (input_valid && input_ready && output_valid && output_ready) begin
                count_reg <= `TD count_reg;
            end
            else if (input_valid && input_ready) begin
                count_reg <= `TD count_reg + 2'b1;
            end
            else if (output_valid && output_ready) begin
                count_reg <= `TD count_reg - 2'b1;
            end
        end
    end
endmodule

module switch_node #(parameter SWITCH_IDX_WIDTH = 2, OUT_0_MAX_DST=1, OUT_1_MAX_DST=3)
    (
        input wire clk,
        input wire rst_n,
        // input 0
        input wire input_valid_0,
        input wire [SWITCH_IDX_WIDTH-1:0] input_dst_idx_0,
        input wire input_is_ext_0,
        input wire [SWITCH_IDX_WIDTH-1:0] input_slot_idx_0,
        input wire [`ADDR_WIDTH-1:0] input_head_addr_0,
        input wire [`ADDR_WIDTH-1:0] input_history_addr_0,
        output wire input_ready_0,
        // input 1
        input wire input_valid_1,
        input wire [SWITCH_IDX_WIDTH-1:0] input_dst_idx_1,
        input wire input_is_ext_1,
        input wire [SWITCH_IDX_WIDTH-1:0] input_slot_idx_1,
        input wire [`ADDR_WIDTH-1:0] input_head_addr_1,
        input wire [`ADDR_WIDTH-1:0] input_history_addr_1,
        output wire input_ready_1,
        // output 0
        output wire output_valid_0,
        output wire [SWITCH_IDX_WIDTH-1:0] output_dst_idx_0,
        output wire output_is_ext_0,
        output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_0,
        output wire [`ADDR_WIDTH-1:0] output_head_addr_0,
        output wire [`ADDR_WIDTH-1:0] output_history_addr_0,
        input  wire output_ready_0,
        // output 1
        output wire output_valid_1,
        output wire [SWITCH_IDX_WIDTH-1:0] output_dst_idx_1,
        output wire output_is_ext_1,
        output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_1,
        output wire [`ADDR_WIDTH-1:0] output_head_addr_1,
        output wire [`ADDR_WIDTH-1:0] output_history_addr_1,
        input  wire output_ready_1
    );

    wire fifo_0_output_valid;
    wire [SWITCH_IDX_WIDTH-1:0] fifo_0_output_dst_idx;
    wire fifo_0_output_is_ext;
    wire [SWITCH_IDX_WIDTH-1:0] fifo_0_output_slot_idx;
    wire [`ADDR_WIDTH-1:0] fifo_0_output_head_addr;
    wire [`ADDR_WIDTH-1:0] fifo_0_output_history_addr;
    wire fifo_0_output_ready;
    wire [(SWITCH_IDX_WIDTH*2+2+`ADDR_WIDTH*2)-1:0] fifo_0_output_payload;
    wire [(SWITCH_IDX_WIDTH+2)-1:0] fifo_0_output_order;
    wire [(SWITCH_IDX_WIDTH*2+2+`ADDR_WIDTH*2)-1:0] output_payload_0;

    wire fifo_1_output_valid;
    wire [SWITCH_IDX_WIDTH-1:0] fifo_1_output_dst_idx;
    wire fifo_1_output_is_ext;
    wire [SWITCH_IDX_WIDTH-1:0] fifo_1_output_slot_idx;
    wire [`ADDR_WIDTH-1:0] fifo_1_output_head_addr;
    wire [`ADDR_WIDTH-1:0] fifo_1_output_history_addr;
    wire fifo_1_output_ready;
    wire [(SWITCH_IDX_WIDTH*2+2+`ADDR_WIDTH*2)-1:0] fifo_1_output_payload;
    wire [(SWITCH_IDX_WIDTH+2)-1:0] fifo_1_output_order;
    wire [(SWITCH_IDX_WIDTH*2+2+`ADDR_WIDTH*2)-1:0] output_payload_1;

    reg swap, block0, block1;

    assign fifo_0_output_order = {fifo_0_output_head_addr[1:0], fifo_0_output_dst_idx};
    assign fifo_1_output_order = {fifo_1_output_head_addr[1:0], fifo_1_output_dst_idx};
    assign fifo_0_output_payload = {fifo_0_output_dst_idx, fifo_0_output_is_ext, fifo_0_output_slot_idx, fifo_0_output_head_addr, fifo_0_output_history_addr};
    assign fifo_1_output_payload = {fifo_1_output_dst_idx, fifo_1_output_is_ext, fifo_1_output_slot_idx, fifo_1_output_head_addr, fifo_1_output_history_addr};
    assign {output_dst_idx_0, output_is_ext_0, output_slot_idx_0, output_head_addr_0, output_history_addr_0} = output_payload_0;
    assign {output_dst_idx_1, output_is_ext_1, output_slot_idx_1, output_head_addr_1, output_history_addr_1} = output_payload_1;

    assign output_payload_0 = swap ? fifo_1_output_payload : fifo_0_output_payload;
    assign output_payload_1 = swap ? fifo_0_output_payload : fifo_1_output_payload;
    assign output_valid_0 =  swap ? (fifo_1_output_valid && !block1) : (fifo_0_output_valid && !block0);
    assign output_valid_1 = swap ? (fifo_0_output_valid  && !block0) : (fifo_1_output_valid && !block1);
    assign fifo_0_output_ready = (swap ? output_ready_1 : output_ready_0) && !block0;
    assign fifo_1_output_ready = (swap ? output_ready_0 : output_ready_1) && !block1;

    switch_fifo #(.SWITCH_IDX_WIDTH(SWITCH_IDX_WIDTH)) fifo_0
                (
                    .clk(clk),
                    .rst_n(rst_n),
                    .input_valid(input_valid_0),
                    .input_dst_idx(input_dst_idx_0),
                    .input_is_ext(input_is_ext_0),
                    .input_slot_idx(input_slot_idx_0),
                    .input_head_addr(input_head_addr_0),
                    .input_history_addr(input_history_addr_0),
                    .input_ready(input_ready_0),
                    .output_valid(fifo_0_output_valid),
                    .output_dst_idx(fifo_0_output_dst_idx),
                    .output_is_ext(fifo_0_output_is_ext),
                    .output_slot_idx(fifo_0_output_slot_idx),
                    .output_head_addr(fifo_0_output_head_addr),
                    .output_history_addr(fifo_0_output_history_addr),
                    .output_ready(fifo_0_output_ready)
                );

    switch_fifo #(.SWITCH_IDX_WIDTH(SWITCH_IDX_WIDTH)) fifo_1
                (
                    .clk(clk),
                    .rst_n(rst_n),
                    .input_valid(input_valid_1),
                    .input_dst_idx(input_dst_idx_1),
                    .input_is_ext(input_is_ext_1),
                    .input_slot_idx(input_slot_idx_1),
                    .input_head_addr(input_head_addr_1),
                    .input_history_addr(input_history_addr_1),
                    .input_ready(input_ready_1),
                    .output_valid(fifo_1_output_valid),
                    .output_dst_idx(fifo_1_output_dst_idx),
                    .output_is_ext(fifo_1_output_is_ext),
                    .output_slot_idx(fifo_1_output_slot_idx),
                    .output_head_addr(fifo_1_output_head_addr),
                    .output_history_addr(fifo_1_output_history_addr),
                    .output_ready(fifo_1_output_ready)
                );

    always @(*) begin
        if(fifo_0_output_valid && fifo_1_output_valid) begin
            if(fifo_0_output_dst_idx < OUT_0_MAX_DST && fifo_1_output_dst_idx < OUT_1_MAX_DST) begin
                // direct
                swap = 0;
                block0 = 0;
                block1 = 0;
            end
            else if (fifo_0_output_dst_idx < OUT_1_MAX_DST && fifo_1_output_dst_idx < OUT_0_MAX_DST) begin
                // swap
                swap = 1;
                block0 = 0;
                block1 = 0;
            end
            else begin
                // constraint: OUT_1_MAX_DST > OUT_0_MAX_DST
                // so when there is a conflict, all payload want goto out 1
                // conflict
                swap = (fifo_0_output_order <= fifo_1_output_order); // compare order, let smaller go first
                block0 = (fifo_0_output_order > fifo_1_output_order);
                block1 = (fifo_0_output_order <= fifo_1_output_order);
            end
        end
        else if (fifo_0_output_valid) begin
            // only fifo 0 has payload
            swap = (fifo_0_output_dst_idx > OUT_0_MAX_DST); // swap when indeed.
            block0 = 0;
            block1 = 0;
        end
        else if (fifo_1_output_valid) begin
            swap = 0; // never swap
            block0 = 0;
            block1 = 0;
        end
        else begin
            // no payload at all, no swap, no drop
            swap = 0;
            block0 = 0;
            block1 = 0;
        end
    end

endmodule

module switch_network #(parameter SWITCH_IDX_WIDTH=2)
    (input wire clk,
     input wire rst_n,
     // input 0
     input wire input_valid_0,
     input wire input_is_ext_0,
     input wire [`ADDR_WIDTH-1:0] input_head_addr_0,
     input wire [`ADDR_WIDTH-1:0] input_history_addr_0,
     output wire input_ready_0,
     // input 1
     input wire input_valid_1,
     input wire input_is_ext_1,
     input wire [`ADDR_WIDTH-1:0] input_head_addr_1,
     input wire [`ADDR_WIDTH-1:0] input_history_addr_1,
     output wire input_ready_1,
     // input 2
     input wire input_valid_2,
     input wire input_is_ext_2,
     input wire [`ADDR_WIDTH-1:0] input_head_addr_2,
     input wire [`ADDR_WIDTH-1:0] input_history_addr_2,
     output wire input_ready_2,
     // input 3
     input wire input_valid_3,
     input wire input_is_ext_3,
     input wire [`ADDR_WIDTH-1:0] input_head_addr_3,
     input wire [`ADDR_WIDTH-1:0] input_history_addr_3,
     output wire input_ready_3,
     // output 0
     output wire output_valid_0,
     output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_0,
     output wire output_is_ext_0,
     output wire [`ADDR_WIDTH-1:0] output_head_addr_0,
     output wire [`ADDR_WIDTH-1:0] output_history_addr_0,
     input wire output_ready_0,
     // output 1
     output wire output_valid_1,
     output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_1,
     output wire output_is_ext_1,
     output wire [`ADDR_WIDTH-1:0] output_head_addr_1,
     output wire [`ADDR_WIDTH-1:0] output_history_addr_1,
     input wire output_ready_1,
     // output 2
     output wire output_valid_2,
     output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_2,
        output wire output_is_ext_2,
     output wire [`ADDR_WIDTH-1:0] output_head_addr_2,
     output wire [`ADDR_WIDTH-1:0] output_history_addr_2,
     input wire output_ready_2,
     // output 3
     output wire output_valid_3,
     output wire [SWITCH_IDX_WIDTH-1:0] output_slot_idx_3,
        output wire output_is_ext_3,
     output wire [`ADDR_WIDTH-1:0] output_head_addr_3,
     output wire [`ADDR_WIDTH-1:0] output_history_addr_3,
     input wire output_ready_3
    );

    wire [`WINDOW_LOG-1:0] dist_0, dist_1, dist_2, dist_3;
    wire [SWITCH_IDX_WIDTH-1:0] input_dst_idx_0, input_dst_idx_1, input_dst_idx_2, input_dst_idx_3;
    assign dist_0 = input_head_addr_0 - input_history_addr_0;
    assign dist_1 = input_head_addr_1 - input_history_addr_1;
    assign dist_2 = input_head_addr_2 - input_history_addr_2;
    assign dist_3 = input_head_addr_3 - input_history_addr_3;

    assign input_dst_idx_0 = dist_0 < `MATCH_PU_0_SIZE-128 ? 0 : (dist_0 < `MATCH_PU_1_SIZE ? 2 : (dist_0 < `MATCH_PU_2_SIZE ? 2 : 3));
    assign input_dst_idx_1 = dist_1 < `MATCH_PU_0_SIZE-128 ? 0 : (dist_1 < `MATCH_PU_1_SIZE ? 2 : (dist_1 < `MATCH_PU_2_SIZE ? 2 : 3));
    assign input_dst_idx_2 = dist_2 < `MATCH_PU_0_SIZE-128 ? 0 : (dist_2 < `MATCH_PU_1_SIZE ? 2 : (dist_2 < `MATCH_PU_2_SIZE ? 2 : 3));
    assign input_dst_idx_3 = dist_3 < `MATCH_PU_0_SIZE-128 ? 0 : (dist_3 < `MATCH_PU_1_SIZE ? 2 : (dist_3 < `MATCH_PU_2_SIZE ? 2 : 3));

    // node0 output 0
    wire node0_output_valid_0;
    wire [SWITCH_IDX_WIDTH-1:0] node0_output_dst_idx_0;
    wire [SWITCH_IDX_WIDTH-1:0] node0_output_slot_idx_0;
    wire node0_output_is_ext_0;
    wire [`ADDR_WIDTH-1:0] node0_output_head_addr_0;
    wire [`ADDR_WIDTH-1:0] node0_output_history_addr_0;
    wire node0_output_ready_0;
    // node0 output 1
    wire node0_output_valid_1;
    wire [SWITCH_IDX_WIDTH-1:0] node0_output_dst_idx_1;
    wire [SWITCH_IDX_WIDTH-1:0] node0_output_slot_idx_1;
    wire node0_output_is_ext_1;
    wire [`ADDR_WIDTH-1:0] node0_output_head_addr_1;
    wire [`ADDR_WIDTH-1:0] node0_output_history_addr_1;
    wire node0_output_ready_1;

    switch_node #(.SWITCH_IDX_WIDTH(2), .OUT_0_MAX_DST(2), .OUT_1_MAX_DST(3)) node0 (
        .clk(clk),
        .rst_n(rst_n),
        // input 0
        .input_valid_0(input_valid_0),
        .input_dst_idx_0(input_dst_idx_0),
        .input_slot_idx_0(2'h0),
        .input_is_ext_0(input_is_ext_0),
        .input_head_addr_0(input_head_addr_0),
        .input_history_addr_0(input_history_addr_0),
        .input_ready_0(input_ready_0),
        // input 1
        .input_valid_1(input_valid_1),
        .input_dst_idx_1(input_dst_idx_1),
        .input_slot_idx_1(2'h1),
        .input_is_ext_1(input_is_ext_1),
        .input_head_addr_1(input_head_addr_1),
        .input_history_addr_1(input_history_addr_1),
        .input_ready_1(input_ready_1),
        // output 1
        .output_valid_0(node0_output_valid_0),
        .output_dst_idx_0(node0_output_dst_idx_0),
        .output_slot_idx_0(node0_output_slot_idx_0),
        .output_is_ext_0(node0_output_is_ext_0),
        .output_head_addr_0(node0_output_head_addr_0),
        .output_history_addr_0(node0_output_history_addr_0),
        .output_ready_0(node0_output_ready_0),
        // output 2
        .output_valid_1(node0_output_valid_1),
        .output_dst_idx_1(node0_output_dst_idx_1),
        .output_slot_idx_1(node0_output_slot_idx_1),
        .output_is_ext_1(node0_output_is_ext_1),
        .output_head_addr_1(node0_output_head_addr_1),
        .output_history_addr_1(node0_output_history_addr_1),
        .output_ready_1(node0_output_ready_1)
    );

    // node 1 output 0
    wire node1_output_valid_0;
    wire [SWITCH_IDX_WIDTH-1:0] node1_output_dst_idx_0;
    wire [SWITCH_IDX_WIDTH-1:0] node1_output_slot_idx_0;
    wire node1_output_is_ext_0;
    wire [`ADDR_WIDTH-1:0] node1_output_head_addr_0;
    wire [`ADDR_WIDTH-1:0] node1_output_history_addr_0;
    wire node1_output_ready_0;
    // node 1 output 1
    wire node1_output_valid_1;
    wire [SWITCH_IDX_WIDTH-1:0] node1_output_dst_idx_1;
    wire [SWITCH_IDX_WIDTH-1:0] node1_output_slot_idx_1;
    wire node1_output_is_ext_1;
    wire [`ADDR_WIDTH-1:0] node1_output_head_addr_1;
    wire [`ADDR_WIDTH-1:0] node1_output_history_addr_1;
    wire node1_output_ready_1;
   
    switch_node #(.SWITCH_IDX_WIDTH(2), .OUT_0_MAX_DST(3), .OUT_1_MAX_DST(3)) node1 
    (
        .clk(clk),
        .rst_n(rst_n),
        // input 0
        .input_valid_0(input_valid_2),
        .input_dst_idx_0(input_dst_idx_2),
        .input_slot_idx_0(2'h2),
        .input_is_ext_0(input_is_ext_2),
        .input_head_addr_0(input_head_addr_2),
        .input_history_addr_0(input_history_addr_2),
        .input_ready_0(input_ready_2),
        // input 1
        .input_valid_1(input_valid_3),
        .input_dst_idx_1(input_dst_idx_3),
        .input_slot_idx_1(2'h3),
        .input_is_ext_1(input_is_ext_3),
        .input_head_addr_1(input_head_addr_3),
        .input_history_addr_1(input_history_addr_3),
        .input_ready_1(input_ready_3),
        // output 1
        .output_valid_0(node1_output_valid_0),
        .output_dst_idx_0(node1_output_dst_idx_0),
        .output_slot_idx_0(node1_output_slot_idx_0),
        .output_is_ext_0(node1_output_is_ext_0),
        .output_head_addr_0(node1_output_head_addr_0),
        .output_history_addr_0(node1_output_history_addr_0),
        .output_ready_0(node1_output_ready_0),
        // output 2
        .output_valid_1(node1_output_valid_1),
        .output_dst_idx_1(node1_output_dst_idx_1),
        .output_slot_idx_1(node1_output_slot_idx_1),
        .output_is_ext_1(node1_output_is_ext_1),
        .output_head_addr_1(node1_output_head_addr_1),
        .output_history_addr_1(node1_output_history_addr_1),
        .output_ready_1(node1_output_ready_1)
    );

    // node 2 output 0
    wire node2_output_valid_0;
    wire [SWITCH_IDX_WIDTH-1:0] node2_output_dst_idx_0;
    wire [SWITCH_IDX_WIDTH-1:0] node2_output_slot_idx_0;
    wire node2_output_is_ext_0;
    wire [`ADDR_WIDTH-1:0] node2_output_head_addr_0;
    wire [`ADDR_WIDTH-1:0] node2_output_history_addr_0;
    wire node2_output_ready_0;
    // node 2 output 1
    wire node2_output_valid_1;
    wire [SWITCH_IDX_WIDTH-1:0] node2_output_dst_idx_1;
    wire [SWITCH_IDX_WIDTH-1:0] node2_output_slot_idx_1;
    wire node2_output_is_ext_1;
    wire [`ADDR_WIDTH-1:0] node2_output_head_addr_1;
    wire [`ADDR_WIDTH-1:0] node2_output_history_addr_1;
    wire node2_output_ready_1;
    switch_node #(.SWITCH_IDX_WIDTH(2), .OUT_0_MAX_DST(2), .OUT_1_MAX_DST(3)) node2
    (
        .clk(clk),
        .rst_n(rst_n),
        // node 0 output 1 -> node 2 input 0
        .input_valid_0(node0_output_valid_1),
        .input_dst_idx_0(node0_output_dst_idx_1),
        .input_slot_idx_0(node0_output_slot_idx_1),
        .input_is_ext_0(node0_output_is_ext_1),
        .input_head_addr_0(node0_output_head_addr_1),
        .input_history_addr_0(node0_output_history_addr_1),
        .input_ready_0(node0_output_ready_1),
        // node 1 output 0 -> node 2 input 1
        .input_valid_1(node1_output_valid_0),
        .input_dst_idx_1(node1_output_dst_idx_0),
        .input_slot_idx_1(node1_output_slot_idx_0),
        .input_is_ext_1(node1_output_is_ext_0),
        .input_head_addr_1(node1_output_head_addr_0),
        .input_history_addr_1(node1_output_history_addr_0),
        .input_ready_1(node1_output_ready_0),
        // output 0
        .output_valid_0(node2_output_valid_0),
        .output_dst_idx_0(node2_output_dst_idx_0),
        .output_slot_idx_0(node2_output_slot_idx_0),
        .output_is_ext_0(node2_output_is_ext_0),
        .output_head_addr_0(node2_output_head_addr_0),
        .output_history_addr_0(node2_output_history_addr_0),
        .output_ready_0(node2_output_ready_0),
        // output 1
        .output_valid_1(node2_output_valid_1),
        .output_dst_idx_1(node2_output_dst_idx_1),
        .output_slot_idx_1(node2_output_slot_idx_1),
        .output_is_ext_1(node2_output_is_ext_1),
        .output_head_addr_1(node2_output_head_addr_1),
        .output_history_addr_1(node2_output_history_addr_1),
        .output_ready_1(node2_output_ready_1)
    );

    wire [`MATCH_PU_NUM_LOG2*`MATCH_PU_NUM-1:0] ignore_dst_idx;
    switch_node #(.SWITCH_IDX_WIDTH(2), .OUT_0_MAX_DST(0), .OUT_1_MAX_DST(2)) node3
    (
        .clk(clk),
        .rst_n(rst_n),
        // node 0 output 0 -> node 3 input 0
        .input_valid_0(node0_output_valid_0),
        .input_dst_idx_0(node0_output_dst_idx_0),
        .input_slot_idx_0(node0_output_slot_idx_0),
        .input_is_ext_0(node0_output_is_ext_0),
        .input_head_addr_0(node0_output_head_addr_0),
        .input_history_addr_0(node0_output_history_addr_0),
        .input_ready_0(node0_output_ready_0),
        // node 2 output 0 -> node 3 input 1
        .input_valid_1(node2_output_valid_0),
        .input_dst_idx_1(node2_output_dst_idx_0),
        .input_slot_idx_1(node2_output_slot_idx_0),
        .input_is_ext_1(node2_output_is_ext_0),
        .input_head_addr_1(node2_output_head_addr_0),
        .input_history_addr_1(node2_output_history_addr_0),
        .input_ready_1(node2_output_ready_0),
        // node 3 output 0 -> output 0
        .output_valid_0(output_valid_0),
        .output_dst_idx_0(ignore_dst_idx[0 +: `MATCH_PU_NUM_LOG2]),
        .output_slot_idx_0(output_slot_idx_0),
        .output_is_ext_0(output_is_ext_0),
        .output_head_addr_0(output_head_addr_0),
        .output_history_addr_0(output_history_addr_0),
        .output_ready_0(output_ready_0),
        // node 3 output 1 -> output 1
        .output_valid_1(output_valid_1),
        .output_dst_idx_1(ignore_dst_idx[`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_slot_idx_1(output_slot_idx_1),
        .output_is_ext_1(output_is_ext_1),
        .output_head_addr_1(output_head_addr_1),
        .output_history_addr_1(output_history_addr_1),
        .output_ready_1(output_ready_1)
    );

    switch_node #(.SWITCH_IDX_WIDTH(2), .OUT_0_MAX_DST(2), .OUT_1_MAX_DST(3)) node4
    (
        .clk(clk),
        .rst_n(rst_n),
        // node 2 output 1 -> node 4 input 0
        .input_valid_0(node2_output_valid_1),
        .input_dst_idx_0(node2_output_dst_idx_1),
        .input_slot_idx_0(node2_output_slot_idx_1),
        .input_is_ext_0(node2_output_is_ext_1),
        .input_head_addr_0(node2_output_head_addr_1),
        .input_history_addr_0(node2_output_history_addr_1),
        .input_ready_0(node2_output_ready_1),
        // node 1 output 1 -> node 4 input 1
        .input_valid_1(node1_output_valid_1),
        .input_dst_idx_1(node1_output_dst_idx_1),
        .input_slot_idx_1(node1_output_slot_idx_1),
        .input_is_ext_1(node1_output_is_ext_1),
        .input_head_addr_1(node1_output_head_addr_1),
        .input_history_addr_1(node1_output_history_addr_1),
        .input_ready_1(node1_output_ready_1),
        // node 4 output 0 -> output 2
        .output_valid_0(output_valid_2),
        .output_dst_idx_0(ignore_dst_idx[2*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_slot_idx_0(output_slot_idx_2),
        .output_is_ext_0(output_is_ext_2),
        .output_head_addr_0(output_head_addr_2),
        .output_history_addr_0(output_history_addr_2),
        .output_ready_0(output_ready_2),
        // node 4 output 1 -> output 3
        .output_valid_1(output_valid_3),
        .output_dst_idx_1(ignore_dst_idx[3*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2]),
        .output_slot_idx_1(output_slot_idx_3),
        .output_is_ext_1(output_is_ext_3),
        .output_head_addr_1(output_head_addr_3),
        .output_history_addr_1(output_history_addr_3),
        .output_ready_1(output_ready_3)
    );
endmodule

