`include "util.vh"
module match_len_encoder #(parameter MASK_WIDTH=14, MATCH_LEN_WIDTH=5) (
    input wire [MASK_WIDTH-1:0] compare_bitmask,
    output reg [MATCH_LEN_WIDTH-1:0] match_len,
    output reg can_ext
    );

    wire output_valid;
    wire [MATCH_LEN_WIDTH-1-1:0] output_index;
    wire [$clog2(MASK_WIDTH)-1:0] internal_index;
    priority_encoder #(.W(MASK_WIDTH)) pe_inst (
        .input_vec(~compare_bitmask),
        .output_valid(output_valid),
        .output_index(internal_index)
    );
    assign output_index = `ZERO_EXTEND(internal_index, MATCH_LEN_WIDTH-1);

    always @(*) begin
        can_ext = !output_valid;
        if(output_valid) begin
            match_len = {1'b0, output_index};
        end else begin
            match_len = MASK_WIDTH[MATCH_LEN_WIDTH-1:0];
        end
    end
endmodule