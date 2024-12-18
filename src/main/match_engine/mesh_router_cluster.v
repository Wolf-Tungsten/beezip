`include "parameters.vh"

module mesh_router_cluster #(parameter MESH_X_IDX = 0, MESH_Y_IDX = 0) (
    input wire clk,
    input wire rst_n,

    input wire [`NUM_SHARED_MATCH_PE-1:0] i_n_valid,
    i_e_valid,
    i_s_valid,
    i_w_valid,
    i_l_valid,
    input wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] i_n_dst_x,
    i_e_dst_x,
    i_s_dst_x,
    i_w_dst_x,
    i_l_dst_x,
    input wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] i_n_dst_y,
    i_e_dst_y,
    i_s_dst_y,
    i_w_dst_y,
    i_l_dst_y,
    input wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] i_n_payload,
    i_e_payload,
    i_s_payload,
    i_w_payload,
    i_l_payload,
    output wire [`NUM_SHARED_MATCH_PE-1:0] i_n_ready,
    i_e_ready,
    i_s_ready,
    i_w_ready,
    i_l_ready,
    output wire [`NUM_SHARED_MATCH_PE-1:0] o_n_valid,
    o_e_valid,
    o_s_valid,
    o_w_valid,
    o_l_valid,
    output wire [`NUM_SHARED_MATCH_PE*`MESH_X_SIZE_LOG2-1:0] o_n_dst_x,
    o_e_dst_x,
    o_s_dst_x,
    o_w_dst_x,
    o_l_dst_x,
    output wire [`NUM_SHARED_MATCH_PE*`MESH_Y_SIZE_LOG2-1:0] o_n_dst_y,
    o_e_dst_y,
    o_s_dst_y,
    o_w_dst_y,
    o_l_dst_y,
    output wire [`NUM_SHARED_MATCH_PE*`MESH_W-1:0] o_n_payload,
    o_e_payload,
    o_s_payload,
    o_w_payload,
    o_l_payload,
    input wire [`NUM_SHARED_MATCH_PE-1:0] o_n_ready,
    o_e_ready,
    o_s_ready,
    o_w_ready,
    o_l_ready
);

    mesh_router #(.X_SIZE(`MESH_X_SIZE), .Y_SIZE(`MESH_Y_SIZE), .W(`MESH_W)) mesh_router_inst [`NUM_SHARED_MATCH_PE-1:0] (
        .clk(clk),
        .rst_n(rst_n),
        .i_coord_x(MESH_X_IDX[`MESH_X_SIZE_LOG2-1:0]),
        .i_coord_y(MESH_Y_IDX[`MESH_Y_SIZE_LOG2-1:0]),
        .i_n_valid(i_n_valid),
        .i_e_valid(i_e_valid),
        .i_s_valid(i_s_valid),
        .i_w_valid(i_w_valid),
        .i_l_valid(i_l_valid),
        .i_n_dst_x(i_n_dst_x),
        .i_e_dst_x(i_e_dst_x),
        .i_s_dst_x(i_s_dst_x),
        .i_w_dst_x(i_w_dst_x),
        .i_l_dst_x(i_l_dst_x),
        .i_n_dst_y(i_n_dst_y),
        .i_e_dst_y(i_e_dst_y),
        .i_s_dst_y(i_s_dst_y),
        .i_w_dst_y(i_w_dst_y),
        .i_l_dst_y(i_l_dst_y),
        .i_n_payload(i_n_payload),
        .i_e_payload(i_e_payload),
        .i_s_payload(i_s_payload),
        .i_w_payload(i_w_payload),
        .i_l_payload(i_l_payload),
        .i_n_ready(i_n_ready),
        .i_e_ready(i_e_ready),
        .i_s_ready(i_s_ready),
        .i_w_ready(i_w_ready),
        .i_l_ready(i_l_ready),
        .o_n_valid(o_n_valid),
        .o_e_valid(o_e_valid),
        .o_s_valid(o_s_valid),
        .o_w_valid(o_w_valid),
        .o_l_valid(o_l_valid),
        .o_n_dst_x(o_n_dst_x),
        .o_e_dst_x(o_e_dst_x),
        .o_s_dst_x(o_s_dst_x),
        .o_w_dst_x(o_w_dst_x),
        .o_l_dst_x(o_l_dst_x),
        .o_n_dst_y(o_n_dst_y),
        .o_e_dst_y(o_e_dst_y),
        .o_s_dst_y(o_s_dst_y),
        .o_w_dst_y(o_w_dst_y),
        .o_l_dst_y(o_l_dst_y),
        .o_n_payload(o_n_payload),
        .o_e_payload(o_e_payload),
        .o_s_payload(o_s_payload),
        .o_w_payload(o_w_payload),
        .o_l_payload(o_l_payload),
        .o_n_ready(o_n_ready),
        .o_e_ready(o_e_ready),
        .o_s_ready(o_s_ready),
        .o_w_ready(o_w_ready),
        .o_l_ready(o_l_ready)
    );
endmodule