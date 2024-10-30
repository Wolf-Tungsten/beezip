/**

match_resp_sync

收集来自 M 个 match_pe 的响应，收集到 LAZY_LEN 个响应后，将这些响应发送到 job_pe。

*/

`include "parameters.vh"
`include "util.vh"

module match_resp_sync #(
    parameter L = `LAZY_LEN,
    parameter C = `NUM_MATCH_REQ_CH,
    parameter TAG_BITS = `LAZY_LEN_LOG2,
    parameter ML = `MAX_MATCH_LEN_LOG2+1
) (
    input wire clk,
    input wire rst_n,

    input req_group_valid,
    input [L-1:0] req_group_strb,

    input wire [C-1:0] resp_valid,
    output wire [C-1:0] resp_ready,
    input wire [C*TAG_BITS-1:0] resp_tag,
    input wire [C*ML-1:0] resp_match_len,

    output wire resp_group_valid,
    input wire resp_group_ready,
    output wire [L*ML-1:0] resp_group_match_len
);

    reg [L-1:0] done_reg;
    reg [L*ML-1:0] match_len_reg;

    reg [L-1:0] valid_vec;
    reg [L*ML-1:0] match_len_vec;
    reg valid_tmp;
    always @(*) begin
        for(integer i = 0; i < L; i = i + 1) begin
            valid_vec[i] = '0;
            match_len_vec[i*ML +: ML] = '0;
            for(integer j = 0; j < C; j = j + 1) begin
                valid_tmp = resp_valid[j] && (resp_tag[j*TAG_BITS +: TAG_BITS] == i[TAG_BITS-1:0]);
                valid_vec[i] |= valid_tmp;
                match_len_vec[i*ML +: ML] |= valid_tmp ? resp_match_len[j*ML +: ML] : '0;
            end
        end
    end

    assign resp_group_valid = &done_reg;
    assign resp_ready = {C{~&done_reg}};
    assign resp_group_match_len = match_len_reg;

    always @(posedge clk) begin
        if(~rst_n) begin
            done_reg <= '0;
            match_len_reg <= '0;
        end else begin
            if(req_group_valid) begin
                done_reg <= ~req_group_strb;
            end else if(|(resp_ready & resp_valid)) begin
                done_reg <= done_reg | valid_vec;
                match_len_reg <= match_len_reg | match_len_vec;
            end
        end
    end
endmodule