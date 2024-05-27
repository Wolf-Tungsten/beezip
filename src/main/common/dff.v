module dff #(parameter W=1, EN=1, RST=1, RST_V=0) (
    input wire clk,
    input wire rst_n,

    input wire [W-1:0] d,
    input wire en,
    
    output wire [W-1:0] q
);

    reg [W-1:0] d_reg;
    assign q = d_reg;
    
    generate if(EN && RST) begin : dff_en_rst
        always @(posedge clk) begin
            if (!rst_n) begin
                d_reg <= `TD RST_V;
            end else if (en) begin
                d_reg <= `TD d;
            end
        end
    end else if(EN) begin : dff_en
        always @(posedge clk) begin
            if(en) begin
                d_reg <= `TD d;
            end
        end
    end else if(RST) begin : dff_rst
        always @(posedge clk) begin
            if (!rst_n) begin
                d_reg <= `TD RST_V;
            end else if (en) begin
                d_reg <= `TD d;
            end
        end 
    end else begin : dff
        always @(posedge clk) begin
            d_reg <= `TD d;
        end
    end endgenerate
endmodule