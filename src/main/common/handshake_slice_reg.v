module handshake_slice_reg #(parameter W=8, DEPTH=3)
(
    input wire clk,
    input wire rst_n,

    input  wire         input_valid,
    output wire         input_ready,
    input  wire [W-1:0] input_payload,
    
    output wire         output_valid,
    input  wire         output_ready,
    output wire [W-1:0] output_payload
    
);

    wire fire_reg_d[DEPTH-1:0];
    wire fire_reg_q[DEPTH-1:0];
    wire ready_reg_d[DEPTH-1:0];
    wire ready_reg_q[DEPTH-1:0];
    wire [W-1:0] payload_reg_d[DEPTH-1:0];
    wire [W-1:0] payload_reg_q[DEPTH-1:0];

    wire fifo_in_valid, fifo_in_ready, fifo_out_valid, fifo_out_ready;
    wire [W-1:0] fifo_in_payload, fifo_out_payload;

    assign fire_reg_d[0] = input_valid && input_ready;
    assign payload_reg_d[0] = input_payload;
    assign ready_reg_d[DEPTH-1] = output_ready;

    genvar i;
    generate
        for(i = 0; i < DEPTH; i = i+1) begin : shift_reg
            reg fire_reg;
            reg ready_reg;
            reg [W-1:0] payload_reg;
            always @(posedge clk) begin
                if(!rst_n) begin
                    fire_reg <= 1'b0;
                    ready_reg <= 1'b0;
                end else begin
                    fire_reg <= fire_reg_d[i];
                    ready_reg <= ready_reg_d[i];
                    payload_reg <= payload_reg_d[i];
                end
            end
            assign fire_reg_q[i] = fire_reg;
            assign ready_reg_q[i] = ready_reg;
            assign payload_reg_q[i] = payload_reg;
            if(i > 0) begin
                assign fire_reg_d[i] = fire_reg_q[i-1];
                assign ready_reg_d[i-1] = ready_reg_q[i];
                assign payload_reg_d[i] = payload_reg_q[i-1];
            end
        end
    endgenerate


    assign input_ready = ready_reg_q[0];
    assign output_valid = fire_reg_q[DEPTH-1] || fifo_out_valid;
    assign output_payload = fifo_out_valid ? fifo_out_payload : payload_reg_q[DEPTH-1];
    assign fifo_in_valid = fire_reg_q[DEPTH-1] && (fifo_out_valid || !output_ready);
    assign fifo_in_payload = payload_reg_q[DEPTH-1];
    assign fifo_out_ready = output_ready;
    
    fifo #(.W(W), .DEPTH(DEPTH)) fifo_inst (
        .clk(clk),
        .rst_n(rst_n),

        .input_valid(fifo_in_valid),
        .input_payload(fifo_in_payload),
        .input_ready(fifo_in_ready),

        .output_valid(fifo_out_valid),
        .output_payload(fifo_out_payload),
        .output_ready(fifo_out_ready)
    );
endmodule