`include "parameters.vh"
`include "util.vh"

module mesh_adapter_job_pe#(parameter JOB_PE_IDX = 0) (
    input clk,
    input rst_n,

    input wire match_req_valid,
    output wire match_req_ready,
    input wire [`ADDR_WIDTH-1:0] match_req_head_addr,
    input wire [`ADDR_WIDTH-1:0] match_req_history_addr,
    input wire [`LAZY_LEN_LOG2-1:0] match_req_tag,

    output wire to_mesh_valid,
    input wire to_mesh_ready,
    output wire [`MESH_X_SIZE_LOG2-1:0] to_mesh_x_dst,
    output wire [`MESH_Y_SIZE_LOG2-1:0] to_mesh_y_dst,
    output wire [`MESH_W-1:0] to_mesh_payload,

    input wire from_mesh_valid,
    output wire from_mesh_ready,
    input wire [`MESH_W-1:0] from_mesh_payload,

    output wire match_resp_valid,
    input wire match_resp_ready,
    output wire [`LAZY_LEN_LOG2-1:0] match_resp_tag,
    output wire [`MATCH_LEN_WIDTH-1:0] match_resp_match_len
);

    assign to_mesh_valid = match_req_valid;
    assign match_req_ready = to_mesh_ready;
    /* 地址映射关系
    根据 history addr 可确定 shared_match_pe 在 mesh 中的位置
    shared match pe 数量等于 job pe 数量，所有 shared_pe 共同构成一个完整的滑动窗口
    所以 shared match pe 内部地址宽度为 WINDOW_LOG - NUM_JOB_PE_LOG2
    因此 history addr 拆分成 {无用的高位，mesh_addr, shared_match_pe_addr} 三部分
    mesh_addr 的位宽等于 MESH_X_SIZE_LOG2 + MESH_Y_SIZE_LOG2 - 1
    -1 的原因是 job pe 与 shared match pe 按列穿插排列，所以 shared match pe 的地址位宽比 mesh 地址位宽少 1
    y 地址为高位，x 地址为低位，shared match pe 的 x 地址最低位为 0
     */
    localparam IN_MESH_MATCH_PE_ADDR_WIDTH = `WINDOW_LOG - `NUM_JOB_PE_LOG2 ;
    wire [`MESH_X_SIZE_LOG2+`MESH_Y_SIZE_LOG2-1-1:0] mesh_addr = match_req_history_addr[IN_MESH_MATCH_PE_ADDR_WIDTH +: `MESH_X_SIZE_LOG2+`MESH_Y_SIZE_LOG2-1];
    wire [`MESH_Y_SIZE_LOG2-1-1:0] actual_y;
    assign {actual_y, to_mesh_x_dst} = mesh_addr;
    assign to_mesh_y_dst = {actual_y, 1'b1};
    assign to_mesh_payload = {match_req_head_addr, match_req_history_addr, match_req_tag, JOB_PE_IDX[`NUM_JOB_PE_LOG2-1:0]};

    assign match_resp_valid = from_mesh_valid;
    assign from_mesh_ready = match_resp_ready;
    assign {match_resp_match_len, match_resp_tag} = from_mesh_payload[$bits({match_resp_match_len, match_resp_tag})-1:0];
endmodule