`include "parameters.vh"
`include "util.vh"

module mesh_adapter_shared_match_pe (
    input clk,
    input rst_n,

    input wire from_mesh_valid,
    output wire from_mesh_ready,
    input wire [`MESH_W-1:0] from_mesh_payload,

    output wire match_req_valid,
    input wire match_req_ready,
    output wire [`ADDR_WIDTH-1:0] match_req_head_addr,
    output wire [`ADDR_WIDTH-1:0] match_req_history_addr,
    output wire [`NUM_JOB_PE_LOG2+`LAZY_LEN_LOG2-1:0] match_req_tag,    

    input wire match_resp_valid,
    output wire match_resp_ready,
    input wire [`NUM_JOB_PE_LOG2+`LAZY_LEN_LOG2-1:0] match_resp_tag,
    input wire [`MATCH_LEN_WIDTH-1:0] match_resp_match_len,

    output wire to_mesh_valid,
    input wire to_mesh_ready,
    output wire [`MESH_X_SIZE_LOG2-1:0] to_mesh_x_dst,
    output wire [`MESH_Y_SIZE_LOG2-1:0] to_mesh_y_dst,
    output wire [`MESH_W-1:0] to_mesh_payload
);

    assign match_req_valid = from_mesh_valid;
    assign from_mesh_ready = match_req_ready;
    assign {match_req_head_addr, match_req_history_addr, match_req_tag} = from_mesh_payload;

    assign to_mesh_valid = match_resp_valid;
    assign match_resp_ready = to_mesh_ready;
    wire [`LAZY_LEN_LOG2-1:0] local_tag;
    wire [`MESH_Y_SIZE_LOG2+`MESH_X_SIZE_LOG2-1-1:0] mesh_addr;
    assign {mesh_addr, local_tag} = match_resp_tag;
    assign {to_mesh_y_dst, to_mesh_x_dst} = {mesh_addr, 1'b1};
    assign to_mesh_payload = { {($bits(to_mesh_payload) - $bits(match_resp_match_len) - $bits(local_tag)){1'b0}} ,match_resp_match_len, local_tag};

endmodule