`include "parameters.vh"

module pu_bus_mux_4 #(parameter W=8) (
        input wire [W*4-1:0] payload_in,
        input wire [3:0] sel,
        output wire [W-1:0] payload_out
    );

    wire [W-1:0] intm0_payload, intm1_payload;
    wire intm0_sel, intm1_sel;

    assign intm0_payload = sel[0] ?  payload_in[0 +: W] : payload_in[1*W +: W];
    assign intm0_sel = sel[0] | sel[1];
    assign intm1_payload = sel[2] ? payload_in[2*W +: W] : payload_in[3*W +: W];
    assign intm1_sel = sel[2] | sel[3];

    assign payload_out = intm0_sel ? intm0_payload : intm1_payload;
endmodule

module match_pu_result_bus (
        input wire clk,
        input wire rst_n,
        // PU response bus port
        input wire [`MATCH_PU_NUM-1:0] pu_resp_bus_valid,
        input wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] pu_resp_bus_addr,
        input wire [`MATCH_PU_NUM*`MATCH_PU_NUM_LOG2-1:0] pu_resp_bus_slot_idx,
        input wire [`MATCH_PU_NUM*(`MAX_MATCH_LEN_LOG2+1)-1:0] pu_resp_bus_match_len,
        input wire [`MATCH_PU_NUM-1:0] pu_resp_bus_extp,

        // coordinator table slot port
        output wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM-1:0] slot_resp_valid,
        output wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM*`TABLE_ADDR_TAG_BITS-1:0] slot_resp_addr_tag,
        output wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM*(`MAX_MATCH_LEN_LOG2+1)-1:0] slot_resp_match_len,
        output wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM-1:0] slot_resp_extp
    );

    localparam MATCH_LEN_BITS = `MAX_MATCH_LEN_LOG2 + 1;

    /** begin >>> PU Result bus reorganize **/
    wire pu_result_valid [`MATCH_PU_NUM-1:0];
    wire [`TABLE_ADDR_TAG_BITS-1:0] pu_result_addr_tag [`MATCH_PU_NUM-1:0];
    wire [`MATCH_PU_NUM_LOG2-1:0] pu_result_slot_idx [`MATCH_PU_NUM-1:0];
    wire [`HASH_ISSUE_WIDTH_LOG2-1:0] pu_result_row_idx [`MATCH_PU_NUM-1:0];
    wire [MATCH_LEN_BITS-1:0] pu_result_match_len [`MATCH_PU_NUM-1:0];
    wire pu_result_extp [`MATCH_PU_NUM-1:0];

    genvar i, j;
    generate;
        for(j = 0; j < `MATCH_PU_NUM; j = j+1) begin
            wire [`ADDR_WIDTH-1:0] addr = pu_resp_bus_addr[j*`ADDR_WIDTH +: `ADDR_WIDTH];
            assign pu_result_valid[j] = pu_resp_bus_valid[j];
            assign pu_result_addr_tag[j] = addr[`HASH_ISSUE_WIDTH_LOG2 +: `TABLE_ADDR_TAG_BITS];
            assign pu_result_slot_idx[j] = pu_resp_bus_slot_idx[j*`MATCH_PU_NUM_LOG2 +: `MATCH_PU_NUM_LOG2];
            assign pu_result_row_idx[j] = addr[`HASH_ISSUE_WIDTH_LOG2-1:0];
            assign pu_result_match_len[j] = pu_resp_bus_match_len[j*MATCH_LEN_BITS +: MATCH_LEN_BITS];
            assign pu_result_extp[j] = pu_resp_bus_extp[j];
        end
    endgenerate
    /** PU Result bus reorganize <<< end **/

    generate;
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
            for(j = 0; j < `MATCH_PU_NUM; j = j+1) begin
                wire [3:0] sel = {pu_result_valid[3] && (pu_result_row_idx[3] == i) && (pu_result_slot_idx[3] == j),
                                  pu_result_valid[2] && (pu_result_row_idx[2] == i) && (pu_result_slot_idx[2] == j),
                                  pu_result_valid[1] && (pu_result_row_idx[1] == i) && (pu_result_slot_idx[1] == j),
                                  pu_result_valid[0] && (pu_result_row_idx[0] == i) && (pu_result_slot_idx[0] == j)};
                assign slot_resp_valid[i*`MATCH_PU_NUM + j] = |sel;
                pu_bus_mux_4 #(.W(`TABLE_ADDR_TAG_BITS + MATCH_LEN_BITS + 1)) addr_tag_mux (
                                 .payload_in({{pu_result_addr_tag[3], pu_result_match_len[3], pu_result_extp[3]},
                                              {pu_result_addr_tag[2],pu_result_match_len[2], pu_result_extp[2]},
                                              {pu_result_addr_tag[1],pu_result_match_len[1], pu_result_extp[1]},
                                              {pu_result_addr_tag[0],pu_result_match_len[0], pu_result_extp[0]}}),
                                 .sel(sel),
                                 .payload_out({slot_resp_addr_tag[i*`MATCH_PU_NUM*`TABLE_ADDR_TAG_BITS + j*`TABLE_ADDR_TAG_BITS +: `TABLE_ADDR_TAG_BITS],
                                               slot_resp_match_len[i*`MATCH_PU_NUM*(`MAX_MATCH_LEN_LOG2+1) + j*(`MAX_MATCH_LEN_LOG2+1) +: (`MAX_MATCH_LEN_LOG2+1)],
                                               slot_resp_extp[i*`MATCH_PU_NUM + j]
                                              })
                             );
            end
        end
    endgenerate
endmodule