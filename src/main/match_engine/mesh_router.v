module mesh_router #(
    parameter W = 8,
    X_SIZE = 4,
    Y_SIZE = 4,
    BUFFER_DEPTH = 4
) (
    input wire clk,
    input wire rst_n,
    input wire [$clog2(X_SIZE)-1:0] i_coord_x,
    input wire [$clog2(Y_SIZE)-1:0] i_coord_y,
    input wire i_n_valid,
    i_e_valid,
    i_s_valid,
    i_w_valid,
    i_l_valid,
    input wire [$clog2(X_SIZE)-1:0] i_n_dst_x,
    i_e_dst_x,
    i_s_dst_x,
    i_w_dst_x,
    i_l_dst_x,
    input wire [$clog2(Y_SIZE)-1:0] i_n_dst_y,
    i_e_dst_y,
    i_s_dst_y,
    i_w_dst_y,
    i_l_dst_y,
    input wire [W-1:0] i_n_payload,
    i_e_payload,
    i_s_payload,
    i_w_payload,
    i_l_payload,
    output wire i_n_ready,
    i_e_ready,
    i_s_ready,
    i_w_ready,
    i_l_ready,
    output wire o_n_valid,
    o_e_valid,
    o_s_valid,
    o_w_valid,
    o_l_valid,
    output wire [$clog2(X_SIZE)-1:0] o_n_dst_x,
    o_e_dst_x,
    o_s_dst_x,
    o_w_dst_x,
    o_l_dst_x,
    output wire [$clog2(Y_SIZE)-1:0] o_n_dst_y,
    o_e_dst_y,
    o_s_dst_y,
    o_w_dst_y,
    o_l_dst_y,
    output wire [W-1:0] o_n_payload,
    o_e_payload,
    o_s_payload,
    o_w_payload,
    o_l_payload,
    input wire o_n_ready,
    o_e_ready,
    o_s_ready,
    o_w_ready,
    o_l_ready
);

  /* 先东西后南北 */
  wire n_to_s_valid = i_n_valid && (i_n_dst_x == i_coord_x) && (i_n_dst_y > i_coord_y);
  wire n_to_l_valid = i_n_valid && (i_n_dst_x == i_coord_x) && (i_n_dst_y == i_coord_y);

  wire s_to_n_valid = i_s_valid && (i_s_dst_x == i_coord_x) && (i_s_dst_y < i_coord_y);
  wire s_to_l_valid = i_s_valid && (i_s_dst_x == i_coord_x) && (i_s_dst_y == i_coord_y);

  wire e_to_n_valid = i_e_valid && (i_e_dst_x == i_coord_x) && (i_e_dst_y < i_coord_y);
  wire e_to_s_valid = i_e_valid && (i_e_dst_x == i_coord_x) && (i_e_dst_y > i_coord_y);
  wire e_to_w_valid = i_e_valid && (i_e_dst_x < i_coord_x);
  wire e_to_l_valid = i_e_valid && (i_e_dst_x == i_coord_x) && (i_e_dst_y == i_coord_y);

  wire w_to_n_valid = i_w_valid && (i_w_dst_x == i_coord_x) && (i_w_dst_y < i_coord_y);
  wire w_to_s_valid = i_w_valid && (i_w_dst_x == i_coord_x) && (i_w_dst_y > i_coord_y);
  wire w_to_e_valid = i_w_valid && (i_w_dst_x > i_coord_x);
  wire w_to_l_valid = i_w_valid && (i_w_dst_x == i_coord_x) && (i_w_dst_y == i_coord_y);

  wire l_to_n_valid = i_l_valid && (i_l_dst_x == i_coord_x) && (i_l_dst_y < i_coord_y);
  wire l_to_s_valid = i_l_valid && (i_l_dst_x == i_coord_x) && (i_l_dst_y > i_coord_y);
  wire l_to_e_valid = i_l_valid && (i_l_dst_x > i_coord_x);
  wire l_to_w_valid = i_l_valid && (i_l_dst_x < i_coord_x);

  wire n_fifo_ready, e_fifo_ready, s_fifo_ready, w_fifo_ready, l_fifo_ready;

  assign i_n_ready = s_fifo_ready && l_fifo_ready;
  assign i_s_ready = n_fifo_ready && l_fifo_ready;
  assign i_e_ready = n_fifo_ready && s_fifo_ready && w_fifo_ready && l_fifo_ready;
  assign i_w_ready = n_fifo_ready && s_fifo_ready && e_fifo_ready && l_fifo_ready;
  assign i_l_ready = n_fifo_ready && s_fifo_ready && e_fifo_ready && w_fifo_ready;

  mesh_quad_fifo #(
      .W(W),
      .X_SIZE(X_SIZE),
      .Y_SIZE(Y_SIZE),
      .BUFFER_DEPTH(BUFFER_DEPTH)
  ) n_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .i_valid_0(s_to_n_valid),
      .i_valid_1(e_to_n_valid),
      .i_valid_2(w_to_n_valid),
      .i_valid_3(l_to_n_valid),
      .i_dst_x_0(i_s_dst_x),
      .i_dst_x_1(i_e_dst_x),
      .i_dst_x_2(i_w_dst_x),
      .i_dst_x_3(i_l_dst_x),
      .i_dst_y_0(i_s_dst_y),
      .i_dst_y_1(i_e_dst_y),
      .i_dst_y_2(i_w_dst_y),
      .i_dst_y_3(i_l_dst_y),
      .i_payload_0(i_s_payload),
      .i_payload_1(i_e_payload),
      .i_payload_2(i_w_payload),
      .i_payload_3(i_l_payload),
      .i_ready(n_fifo_ready),
      .o_valid(o_n_valid),
      .o_dst_x(o_n_dst_x),
      .o_dst_y(o_n_dst_y),
      .o_payload(o_n_payload),
      .o_ready(o_n_ready)
  );

  mesh_quad_fifo #(
      .W(W),
      .X_SIZE(X_SIZE),
      .Y_SIZE(Y_SIZE),
      .BUFFER_DEPTH(BUFFER_DEPTH)
  ) s_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .i_valid_0(n_to_s_valid),
      .i_valid_1(e_to_s_valid),
      .i_valid_2(w_to_s_valid),
      .i_valid_3(l_to_s_valid),
      .i_dst_x_0(i_n_dst_x),
      .i_dst_x_1(i_e_dst_x),
      .i_dst_x_2(i_w_dst_x),
      .i_dst_x_3(i_l_dst_x),
      .i_dst_y_0(i_n_dst_y),
      .i_dst_y_1(i_e_dst_y),
      .i_dst_y_2(i_w_dst_y),
      .i_dst_y_3(i_l_dst_y),
      .i_payload_0(i_n_payload),
      .i_payload_1(i_e_payload),
      .i_payload_2(i_w_payload),
      .i_payload_3(i_l_payload),
      .i_ready(s_fifo_ready),
      .o_valid(o_s_valid),
      .o_dst_x(o_s_dst_x),
      .o_dst_y(o_s_dst_y),
      .o_payload(o_s_payload),
      .o_ready(o_s_ready)
  );

  mesh_dual_fifo #(
      .W(W),
      .X_SIZE(X_SIZE),
      .Y_SIZE(Y_SIZE),
      .BUFFER_DEPTH(BUFFER_DEPTH)
  ) e_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .i_valid_0(w_to_e_valid),
      .i_valid_1(l_to_e_valid),
      .i_dst_x_0(i_w_dst_x),
      .i_dst_x_1(i_l_dst_x),
      .i_dst_y_0(i_w_dst_y),
      .i_dst_y_1(i_l_dst_y),
      .i_payload_0(i_w_payload),
      .i_payload_1(i_l_payload),
      .i_ready(e_fifo_ready),
      .o_valid(o_e_valid),
      .o_dst_x(o_e_dst_x),
      .o_dst_y(o_e_dst_y),
      .o_payload(o_e_payload),
      .o_ready(o_e_ready)
  );

  mesh_dual_fifo #(
      .W(W),
      .X_SIZE(X_SIZE),
      .Y_SIZE(Y_SIZE),
      .BUFFER_DEPTH(BUFFER_DEPTH)
  ) w_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .i_valid_0(e_to_w_valid),
      .i_valid_1(l_to_w_valid),
      .i_dst_x_0(i_e_dst_x),
      .i_dst_x_1(i_l_dst_x),
      .i_dst_y_0(i_e_dst_y),
      .i_dst_y_1(i_l_dst_y),
      .i_payload_0(i_e_payload),
      .i_payload_1(i_l_payload),
      .i_ready(w_fifo_ready),
      .o_valid(o_w_valid),
      .o_dst_x(o_w_dst_x),
      .o_dst_y(o_w_dst_y),
      .o_payload(o_w_payload),
      .o_ready(o_w_ready)
  );

  mesh_quad_fifo #(
      .W(W),
      .X_SIZE(X_SIZE),
      .Y_SIZE(Y_SIZE),
      .BUFFER_DEPTH(BUFFER_DEPTH)
  ) l_fifo (
      .clk(clk),
      .rst_n(rst_n),
      .i_valid_0(e_to_l_valid),
      .i_valid_1(s_to_l_valid),
      .i_valid_2(n_to_l_valid),
      .i_valid_3(w_to_l_valid),
      .i_dst_x_0(i_e_dst_x),
      .i_dst_x_1(i_s_dst_x),
      .i_dst_x_2(i_n_dst_x),
      .i_dst_x_3(i_w_dst_x),
      .i_dst_y_0(i_e_dst_y),
      .i_dst_y_1(i_s_dst_y),
      .i_dst_y_2(i_n_dst_y),
      .i_dst_y_3(i_w_dst_y),
      .i_payload_0(i_e_payload),
      .i_payload_1(i_s_payload),
      .i_payload_2(i_n_payload),
      .i_payload_3(i_w_payload),
      .i_ready(l_fifo_ready),
      .o_valid(o_l_valid),
      .o_dst_x(o_l_dst_x),
      .o_dst_y(o_l_dst_y),
      .o_payload(o_l_payload),
      .o_ready(o_l_ready)
  );

endmodule
