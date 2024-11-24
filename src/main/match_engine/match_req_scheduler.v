/**
match_req_scheduler

- 功能描述：

    - Job PE 通过一个 Match Request Group Channel 将最多 LAZY_LEN 个 Match Request 打包发送到 match_req_scheduler
    - match_req_scheduler 通过 M 个独立握手的 Match Request Channel 与 M 个 Match PE 通信
    - match_req_scheduler 的主要功能是将 Match Request Group Channel 中的 Match Request 调度到 Match Request Channel 上
    - Match Request 的组成
        - head_addr 和 history_addr 字段，原样发送给 Match PE
        - router_mask：明确当前 Request 应该由哪个 Match PE 处理，
            - 例如，M=4，如果 router_mask = 4'b1110，表明该 Match Request 应当由 Match PE 1-3 的任意一个处理，不能由 Match PE 0 处理
    - Match Request Group Channel
        - 采用 valid-ready 握手，由 Job PE 输入到 match_req_scheduler 模块
        - 包含一组 LAZY_MATCH 个 Match Request
        - 为每一个 Match Request 增加一位 strb 信号表明是否有效
    - Match Request Channel
        - 采用 valid-ready 握手，由 match_req_scheduler 模块输出到 Match PE
        - 包含一个  Match Request
        - 附带一个 tag 字段，该字段由 match_req_scheduler 的 IDX 参数、来源请求在 Match Request Group Channel 中的索引共同确定，标记请求的位置
    - 调度策略
        - 当 match_req_scheduler 从 Job PE 接收到一组（LAZY_LEN）个 Match Request 后开始调度
        - 要求根据每个 Match Request 的 router_mask 尽可能短的完成到 Match Request Channel 的调度
        - 完成一组 Match Request 调度再后等待处理下一组 
*/
`include "parameters.vh"
`include "util.vh"
`include "log.vh"

module match_req_scheduler #(
    parameter JOB_PE_IDX = 0,
    parameter LAZY_LEN = `LAZY_LEN,                       // The number of Match Requests in a group
    parameter M        = `NUM_MATCH_REQ_CH               // The number of Match Req Channal
) (
    // Input Ports
    input wire clk,
    input wire rst_n,

    // Match Request Group Channel Ports from Job PE to match_req_scheduler
    input  wire                              match_req_group_valid,
    output wire                              match_req_group_ready,
    input  wire [(LAZY_LEN*`ADDR_WIDTH)-1:0] match_req_group_head_addr,
    input  wire [(LAZY_LEN*`ADDR_WIDTH)-1:0] match_req_group_history_addr,
    input  wire [          (LAZY_LEN*M)-1:0] match_req_group_router_map,
    input  wire [              LAZY_LEN-1:0] match_req_group_strb,

    // Match Request Channel Ports from match_req_scheduler to match_pe
    output wire [            M-1:0] match_req_valid,
    input  wire [            M-1:0] match_req_ready,
    output wire [M*`ADDR_WIDTH-1:0] match_req_head_addr,
    output wire [M*`ADDR_WIDTH-1:0] match_req_history_addr,
    output wire [   M*`LAZY_LEN_LOG2-1:0] match_req_tag
);

    reg [LAZY_LEN-1:0] pending_reg;
    reg [LAZY_LEN*`ADDR_WIDTH-1:0] head_addr_reg;
    reg [LAZY_LEN*`ADDR_WIDTH-1:0] history_addr_reg;
    reg [LAZY_LEN*M-1:0] router_map_reg;

    localparam S_WAIT_REQ = 3'b001;
    localparam S_SCHED = 3'b010;
    reg [2:0] state_reg;

    always @(posedge clk) begin
        if(~rst_n) begin
            state_reg <= S_WAIT_REQ;
        end else begin
            case(state_reg)
            S_WAIT_REQ: begin
                if(match_req_group_valid) begin
                    state_reg <= S_SCHED;
                end
            end
            S_SCHED: begin
                if(~|pending_reg) begin
                    state_reg <= S_WAIT_REQ;
                end
            end
            default: begin
                state_reg <= S_WAIT_REQ;
            end
            endcase
        end
    end 

    assign match_req_group_ready = state_reg == S_WAIT_REQ;
    always @(posedge clk) begin
        if(~rst_n) begin
        end else begin
            if(state_reg == S_WAIT_REQ && match_req_group_valid) begin
                head_addr_reg <= match_req_group_head_addr;
                history_addr_reg <= match_req_group_history_addr;
                router_map_reg <= match_req_group_router_map;
            end
        end
    end

  /*
  调度逻辑的实现解释

  对于 LAZY_LEN 个需要调度的请求，分别提供：
  - M 位的 prev_occupied_map 表示在当前请求之前，有哪些 req ch 已经被占用
  - M 位的 current_avaliable_map 表示当前请求可以被哪些 req ch 接受
  - M 位的 current_1h_map 表示当前请求最终被哪个 req ch 接受

  - 第一个请求之前没有任何请求，所以 prev_occupied_map[0] = 0，没有任何通道会被占用
  - 对于后续的请求，prev_occupied_map[i] = prev_occupied_map[i-1] | current_1h_map[i-1]，表示当前请求之前的所有请求占用的通道
  - current_avaliable_map[i] 的计算方法
    - pending_reg[i]: 只有 pending 信号为 1 的请求才能被调度
    - match_req_ready: 只有处于 match_req_ready 状态的 ch 才能接受请求
    - router_map_reg: 请求的 router mask 确定请求能被哪些 ch 处理
    - ~prev_occupied_map[i]: 只能发送到之前没有被占用的 ch
  - 从 current_avaliable_map[i] 可以计算出
    - current_1h_map[i]：当前请求最终被哪个 ch 接受，选择最低有效位
    - current_issue[i]：当前请求是否被调度，用来更新 pending_reg
  */
    reg [M-1:0] prev_occupied_map [LAZY_LEN-1:0];
    /* verilator lint_off UNOPTFLAT */
    reg [M-1:0] current_avaliable_map [LAZY_LEN-1:0];
    /* verilator lint_on UNOPTFLAT */
    wire [M-1:0] current_1h_map [LAZY_LEN-1:0];
    wire [LAZY_LEN-1:0] current_1h_map_trans [M-1:0];
    wire [LAZY_LEN-1:0] current_issue;
    wire [`LAZY_LEN_LOG2*LAZY_LEN-1:0] group_tag;

  
    integer i;

    always @(*) begin
        prev_occupied_map[0] = '0;
        current_avaliable_map[0] = {M{pending_reg[0]}} & match_req_ready & `VEC_SLICE(router_map_reg, 0, M);
        for (i = 1; i < LAZY_LEN; i = i + 1) begin
            prev_occupied_map[i] = prev_occupied_map[i-1] | current_1h_map[i-1];
            current_avaliable_map[i] = {M{pending_reg[i]}} & match_req_ready & `VEC_SLICE(router_map_reg, i, M) & ~prev_occupied_map[i];
        end
    end

  genvar gi, gj;
  generate
    for (gi = 0; gi < LAZY_LEN; gi = gi + 1 ) begin
        priority_selector #(.W(M)) current_1h_sel (
            .input_vec(current_avaliable_map[gi]),
            .output_vec(current_1h_map[gi])
        );
    end
    for(gi = 0; gi < LAZY_LEN; gi = gi+1) begin
        assign current_issue[gi] = |current_avaliable_map[gi];
    end
    for(gi = 0; gi < LAZY_LEN; gi = gi+1) begin
        for(gj = 0; gj < M; gj = gj+1) begin
            assign current_1h_map_trans[gj][gi] = current_1h_map[gi][gj];
        end
    end
    for(gi = 0; gi < LAZY_LEN; gi = gi+1) begin
        assign `VEC_SLICE(group_tag, gi, `LAZY_LEN_LOG2) = gi[`LAZY_LEN_LOG2-1:0];
    end
    for(gj = 0; gj < M; gj = gj+1) begin
        assign match_req_valid[gj] = (state_reg == S_SCHED) & |current_1h_map_trans[gj];
        mux1h #(.P_CNT(LAZY_LEN), .P_W(`ADDR_WIDTH)) head_addr_sel (
            .input_payload_vec(head_addr_reg),
            .input_select_vec(current_1h_map_trans[gj]),
            .output_payload(`VEC_SLICE(match_req_head_addr, gj, `ADDR_WIDTH))
        );
        mux1h #(.P_CNT(LAZY_LEN), .P_W(`ADDR_WIDTH)) history_addr_sel (
            .input_payload_vec(history_addr_reg),
            .input_select_vec(current_1h_map_trans[gj]),
            .output_payload(`VEC_SLICE(match_req_history_addr, gj, `ADDR_WIDTH))
        );
        mux1h #(.P_CNT(LAZY_LEN), .P_W(`LAZY_LEN_LOG2)) tag_sel (
            .input_payload_vec(group_tag),
            .input_select_vec(current_1h_map_trans[gj]),
            .output_payload(`VEC_SLICE(match_req_tag, gj, `LAZY_LEN_LOG2))
        );
    end
  endgenerate

  always @(posedge clk) begin
    if(~rst_n) begin
        pending_reg <= '0;
    end else begin
        if (state_reg == S_WAIT_REQ) begin
            pending_reg <= match_req_group_strb;
        end else if (state_reg == S_SCHED) begin
            pending_reg <= pending_reg & ~current_issue;
        end
    end
  end

  `ifdef JOB_PE_DEBUG_LOG
    always @(posedge clk) begin
        for(integer i = 0; i < `NUM_MATCH_REQ_CH; i = i + 1) begin
            if(match_req_valid[i] & match_req_ready[i]) begin
                $display(
                    "[match_req_scheduler %0d @ %0t] send request head_addr = %0d, history_addr = %0d, tag = %0d to request channel %0d",
                    JOB_PE_IDX, $time, 
                    `VEC_SLICE(match_req_head_addr, i, `ADDR_WIDTH), 
                    `VEC_SLICE(match_req_history_addr, i, `ADDR_WIDTH),
                    `VEC_SLICE(match_req_tag, i, `LAZY_LEN_LOG2),
                    i
                );
            end
        end
    end
  `endif
endmodule
