`include "log.vh"
`include "parameters.vh"
module mesh_router #(
    parameter W = `MESH_W,
    X_SIZE = 8,
    Y_SIZE = 8,
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
  wire n_to_s_has_payload = (i_n_dst_x == i_coord_x) && (i_n_dst_y > i_coord_y);
  wire n_to_s_valid = i_n_valid && n_to_s_has_payload;
  wire n_to_l_has_payload = (i_n_dst_x == i_coord_x) && (i_n_dst_y == i_coord_y);
  wire n_to_l_valid = i_n_valid && n_to_l_has_payload;

  wire s_to_n_has_payload = (i_s_dst_x == i_coord_x) && (i_s_dst_y < i_coord_y);
  wire s_to_n_valid = i_s_valid && s_to_n_has_payload;
  wire s_to_l_has_payload = (i_s_dst_x == i_coord_x) && (i_s_dst_y == i_coord_y);
  wire s_to_l_valid = i_s_valid && s_to_l_has_payload;

  wire e_to_n_has_payload = (i_e_dst_x == i_coord_x) && (i_e_dst_y < i_coord_y);
  wire e_to_n_valid = i_e_valid && e_to_n_has_payload;
  wire e_to_s_has_payload = (i_e_dst_x == i_coord_x) && (i_e_dst_y > i_coord_y);
  wire e_to_s_valid = i_e_valid && e_to_s_has_payload;
  wire e_to_w_has_payload = (i_e_dst_x < i_coord_x);
  wire e_to_w_valid = i_e_valid && e_to_w_has_payload;
  wire e_to_l_has_payload = (i_e_dst_x == i_coord_x) && (i_e_dst_y == i_coord_y);
  wire e_to_l_valid = i_e_valid && e_to_l_has_payload;

  wire w_to_n_has_payload = (i_w_dst_x == i_coord_x) && (i_w_dst_y < i_coord_y);
  wire w_to_n_valid = i_w_valid && w_to_n_has_payload;
  wire w_to_s_has_payload = (i_w_dst_x == i_coord_x) && (i_w_dst_y > i_coord_y);
  wire w_to_s_valid = i_w_valid && w_to_s_has_payload;
  wire w_to_e_has_payload = (i_w_dst_x > i_coord_x);
  wire w_to_e_valid = i_w_valid && w_to_e_has_payload;
  wire w_to_l_has_payload = (i_w_dst_x == i_coord_x) && (i_w_dst_y == i_coord_y);
  wire w_to_l_valid = i_w_valid && w_to_l_has_payload;

  wire l_to_n_has_payload = (i_l_dst_x == i_coord_x) && (i_l_dst_y < i_coord_y);
  wire l_to_n_valid = i_l_valid && l_to_n_has_payload;
  wire l_to_s_has_payload = (i_l_dst_x == i_coord_x) && (i_l_dst_y > i_coord_y);
  wire l_to_s_valid = i_l_valid && l_to_s_has_payload;
  wire l_to_e_has_payload = (i_l_dst_x > i_coord_x);
  wire l_to_e_valid = i_l_valid && l_to_e_has_payload;
  wire l_to_w_has_payload = (i_l_dst_x < i_coord_x);
  wire l_to_w_valid = i_l_valid && l_to_w_has_payload;

  wire n_fifo_ready, e_fifo_ready, s_fifo_ready, w_fifo_ready, l_fifo_ready;

  assign i_n_ready = (n_to_s_has_payload & s_fifo_ready) | (n_to_l_has_payload & l_fifo_ready);
  assign i_s_ready = (s_to_n_has_payload & n_fifo_ready) | (s_to_l_has_payload & l_fifo_ready);
  assign i_e_ready = (e_to_n_has_payload & n_fifo_ready) | (e_to_s_has_payload & s_fifo_ready) | (e_to_w_has_payload & w_fifo_ready) | (e_to_l_has_payload & l_fifo_ready);
  assign i_w_ready = (w_to_n_has_payload & n_fifo_ready) | (w_to_s_has_payload & s_fifo_ready) | (w_to_e_has_payload & e_fifo_ready) | (w_to_l_has_payload & l_fifo_ready);
  assign i_l_ready = (l_to_n_has_payload & n_fifo_ready) | (l_to_s_has_payload & s_fifo_ready) | (l_to_e_has_payload & e_fifo_ready) | (l_to_w_has_payload & w_fifo_ready);

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

`ifdef MESH_DEBUG_LOG
  function automatic string interpret_payload;
    input [$clog2(X_SIZE)-1:0] dst_x;
    input [$clog2(Y_SIZE)-1:0] dst_y;
    input [W-1:0] payload;
    begin
      if (dst_y[0]) begin
        // request
        reg [`ADDR_WIDTH-1:0] match_req_head_addr;
        reg [`ADDR_WIDTH-1:0] match_req_history_addr;
        reg [`LAZY_LEN_LOG2-1:0] match_req_tag;
        reg [`NUM_JOB_PE_LOG2-1:0] match_req_job_pe_idx;
        reg [`NUM_JOB_PE_LOG2-1:0] shared_match_pe_idx;
        shared_match_pe_idx = {dst_y[$clog2(Y_SIZE)-1:1], dst_x};
        {match_req_head_addr, match_req_history_addr, match_req_tag, match_req_job_pe_idx} = payload;
        interpret_payload = $sformatf(
            "match_req from job_pe %0d to shared_match_pe %0d, head_addr=%0d, history_addr=%0d, slot=%0d",
            match_req_job_pe_idx,
            shared_match_pe_idx,
            match_req_head_addr,
            match_req_history_addr,
            match_req_tag
        );
      end else begin
        // response
        reg [`LAZY_LEN_LOG2-1:0] match_resp_tag;
        reg [`MATCH_LEN_WIDTH-1:0] match_resp_match_len;
        reg [`NUM_JOB_PE_LOG2-1:0] match_resp_job_pe_idx;
        {match_resp_match_len, match_resp_tag} = payload[$bits({match_resp_match_len, match_resp_tag})-1:0];
        match_resp_job_pe_idx = {dst_y[$clog2(Y_SIZE)-1:1], dst_x};
        interpret_payload = $sformatf(
            "match_resp to job_pe %0d, match_len=%0d, slot=%0d",
            match_resp_job_pe_idx,
            match_resp_match_len,
            match_resp_tag
        );
      end
    end
  endfunction
  always @(posedge clk) begin
    if(i_l_valid & i_l_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)] recv local input %s",
            $time, i_coord_x, i_coord_y, interpret_payload(i_l_dst_x, i_l_dst_y, i_l_payload));
    end
    if(i_w_valid & i_w_ready) begin
        $display("[mesh_router @ %0t] (x, y) = (%0d, %0d)->[(%0d, %0d)] recv west input %s",
            $time, i_coord_x-1, i_coord_y, i_coord_x, i_coord_y, interpret_payload(i_w_dst_x, i_w_dst_y, i_w_payload));
    end
    if(i_e_valid & i_e_ready) begin
        $display("[mesh_router @ %0t] (x, y) = (%0d, %0d)->[(%0d, %0d)] recv east input %s",
            $time, i_coord_x+1, i_coord_y, i_coord_x, i_coord_y, interpret_payload(i_e_dst_x, i_e_dst_y, i_e_payload));
    end
    if(i_s_valid & i_s_ready) begin
        $display("[mesh_router @ %0t] (x, y) = (%0d, %0d)->[(%0d, %0d)] recv south input %s",
            $time, i_coord_x, i_coord_y+1, i_coord_x, i_coord_y, interpret_payload(i_s_dst_x, i_s_dst_y, i_s_payload));
    end
    if(i_n_valid & i_n_ready) begin
        $display("[mesh_router @ %0t] (x, y) = (%0d, %0d)->[(%0d, %0d)] recv north input %s",
            $time, i_coord_x, i_coord_y-1, i_coord_x, i_coord_y, interpret_payload(i_n_dst_x, i_n_dst_y, i_n_payload));
    end
    if(o_l_valid & o_l_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)] send local output %s",
            $time, i_coord_x, i_coord_y, interpret_payload(o_l_dst_x, o_l_dst_y, o_l_payload));
    end
    if(o_w_valid & o_w_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)]->(%0d, %0d) send west output %s",
            $time, i_coord_x, i_coord_y, i_coord_x-1, i_coord_y, interpret_payload(o_w_dst_x, o_w_dst_y, o_w_payload));
    end
    if(o_e_valid & o_e_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)]->(%0d, %0d) send east output %s",
            $time, i_coord_x, i_coord_y, i_coord_x+1, i_coord_y, interpret_payload(o_e_dst_x, o_e_dst_y, o_e_payload));
    end
    if(o_s_valid & o_s_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)]->(%0d, %0d) send south output %s",
            $time, i_coord_x, i_coord_y, i_coord_x, i_coord_y+1, interpret_payload(o_s_dst_x, o_s_dst_y, o_s_payload));
    end
    if(o_n_valid & o_n_ready) begin
        $display("[mesh_router @ %0t] (x, y) = [(%0d, %0d)]->(%0d, %0d) send north output %s",
            $time, i_coord_x, i_coord_y, i_coord_x, i_coord_y-1, interpret_payload(o_n_dst_x, o_n_dst_y, o_n_payload));
    end
  end
`endif

endmodule
