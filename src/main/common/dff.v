`include "util.vh"

module dff #(parameter W=1, EN=1, RST=1, RST_V=0, PIPE_DEPTH=1, RETIMING=1) (
        input wire clk,
        input wire rst_n,

        input wire [W-1:0] d,
        input wire en,

        output wire [W-1:0] q
    );

    wire [W-1:0] internal_d [PIPE_DEPTH-1:0];
    wire [W-1:0] internal_q [PIPE_DEPTH-1:0];

    assign internal_d[0] = d;
    assign q = internal_q[PIPE_DEPTH-1];

    reg [W-1:0] fixed_d_reg;
    assign internal_q[PIPE_DEPTH-1] = fixed_d_reg;
    generate
        if(RST && EN) begin
            always @(posedge clk) begin
                if(!rst_n) begin
                    fixed_d_reg <= RST_V;
                end
                else begin
                    if(en) begin
                        fixed_d_reg <= internal_d[PIPE_DEPTH-1];
                    end
                end
            end
        end
        else if (RST) begin
            always @(posedge clk) begin
                if(!rst_n) begin
                    fixed_d_reg <= RST_V;
                end
                else begin
                    fixed_d_reg <= internal_d[PIPE_DEPTH-1];
                end
            end
        end
        else if (EN) begin
            always @(posedge clk) begin
                if(en) begin
                    fixed_d_reg <= internal_d[PIPE_DEPTH-1];
                end
            end
        end
        else begin
            always @(posedge clk) begin
                fixed_d_reg <= internal_d[PIPE_DEPTH-1];
            end
        end
    endgenerate

    genvar i;
    generate
        for(i = 0; i < PIPE_DEPTH-1; i = i+1) begin
            (* retiming_backward = RETIMING *)  reg [W-1:0] timing_d_reg;
            assign internal_q[i] = timing_d_reg;
            if(RST && EN) begin
                always @(posedge clk) begin
                    if(!rst_n) begin
                        timing_d_reg <= RST_V;
                    end
                    else begin
                        if(en) begin
                            timing_d_reg <= internal_d[i];
                        end
                    end
                end
            end
            else if (RST) begin
                always @(posedge clk) begin
                    if(!rst_n) begin
                        timing_d_reg <= RST_V;
                    end
                    else begin
                        timing_d_reg <= internal_d[i];
                    end
                end
            end
            else if (EN) begin
                always @(posedge clk) begin
                    if(en) begin
                        timing_d_reg <= internal_d[i];
                    end
                end
            end
            else begin
                always @(posedge clk) begin
                    timing_d_reg <= internal_d[i];
                end
            end
        end
        for(i = 1; i < PIPE_DEPTH; i = i+1) begin
            assign internal_d[i] = internal_q[i-1];
        end
    endgenerate


endmodule
