`include "parameters.vh"
`include "log.vh"

module match_pe #(parameter MATCH_PE_IDX=0) (

    input wire clk,
    input wire rst_n,

    input wire i_match_req_valid,
    output wire o_match_req_ready,
    input wire [`NUM_JOB_PE_LOG2-1:0] i_match_req_job_pe_id,
    input wire [7:0] i_match_req_tag,
    input wire [`ADDR_WIDTH-1:0] i_match_req_head_addr,
    input wire [`ADDR_WIDTH-1:0] i_match_req_history_addr,


    output wire o_match_resp_valid,
    input wire i_match_resp_ready,
    output wire [`NUM_JOB_PE_LOG2-1:0] o_match_resp_job_pe_id,
    output wire [7:0] o_match_resp_tag,
    output wire [`MAX_MATCH_LEN_LOG2:0] o_match_resp_match_len
    
);

    localparam SCOREBOARD_DEPTH = 4;
    localparam SCOREBOARD_ENTRY_INDEX = $clog2(SCOREBOARD_DEPTH);

    reg scoreboard_occupied_reg [SCOREBOARD_DEPTH-1:0]; // 0-空闲 1-占用
    reg scoreboard_wait_reg [SCOREBOARD_DEPTH-1:0]; // 0-空闲或已在流水线中 1-等待发送到流水线中
    reg scoreboard_done_reg [SCOREBOARD_DEPTH-1:0]; // 0-未完成 1-已完成
    reg [`NUM_JOB_PE_LOG2-1:0] scoreboard_job_pe_id_reg [SCOREBOARD_DEPTH-1:0];
    reg [7:0] scoreboard_tag_reg [SCOREBOARD_DEPTH-1:0];
    reg [`ADDR_WIDTH-1:0] scoreboard_head_addr_reg [SCOREBOARD_DEPTH-1:0];
    reg [`ADDR_WIDTH-1:0] scoreboard_history_addr_reg [SCOREBOARD_DEPTH-1:0];
    reg [`MAX_MATCH_LEN_LOG2:0] scoreboard_match_len_reg [SCOREBOARD_DEPTH-1:0];
    reg scoreboard_match_contd_reg [SCOREBOARD_DEPTH-1:0]; // 跟踪匹配是否连续
    
    // 使用优先编码器选择目的scoreboard的条目
    reg [SCOREBOARD_ENTRY_INDEX-1:0] first_free_entry;
    reg [SCOREBOARD_ENTRY_INDEX-1:0] first_done_entry;
    reg no_free_entry;
    reg has_wait_entry;
    reg has_done_entry;
    integer i;
    always @(*) begin
        first_free_entry = 0;
        first_done_entry = 0;
        no_free_entry = 1;
        has_wait_entry = 0;
        has_done_entry = 0;
        for (i=SCOREBOARD_DEPTH-1; i >= 0 ; i=i-1) begin
            no_free_entry = no_free_entry & scoreboard_occupied_reg[i];
            has_wait_entry = has_wait_entry | scoreboard_wait_reg[i];
            has_done_entry = has_done_entry | scoreboard_done_reg[i];
            if(scoreboard_occupied_reg[i] == 0) begin
                first_free_entry = i[SCOREBOARD_ENTRY_INDEX-1:0];
            end
            if(scoreboard_done_reg[i] == 1) begin
                first_done_entry = i[SCOREBOARD_ENTRY_INDEX-1:0];
            end
        end
    end

    // 请求接收握手逻辑
    assign o_match_req_ready = !no_free_entry;
    // 响应发射握手逻辑
    assign o_match_resp_valid = has_done_entry;
    assign o_match_resp_job_pe_id = scoreboard_job_pe_id_reg[first_done_entry];
    assign o_match_resp_tag = scoreboard_tag_reg[first_done_entry];
    assign o_match_resp_match_len = scoreboard_match_len_reg[first_done_entry];

    // 猝发计数器
    reg [`ADDR_WIDTH-1:0] burst_addr_bias_reg;
    localparam MAX_BURST_ADDR_BIAS = `MATCH_BURST_LEN * `MATCH_PE_WIDTH;
    // 该把哪个条目发射到流水线上呢？
    reg [SCOREBOARD_ENTRY_INDEX-1:0] issue_entry_reg;
    wire [SCOREBOARD_ENTRY_INDEX-1:0] next_issue_entry = issue_entry_reg + 1;

    always @(posedge clk) begin
        if(~rst_n) begin
            burst_addr_bias_reg <= 0; 
            issue_entry_reg <= 0;
        end else begin
            if(burst_addr_bias_reg == MAX_BURST_ADDR_BIAS || ~scoreboard_wait_reg[next_issue_entry]) begin
                burst_addr_bias_reg <= 0;
                issue_entry_reg <= next_issue_entry;
            end else begin
                burst_addr_bias_reg <= burst_addr_bias_reg + `MATCH_PE_WIDTH;
            end
        end
    end

    // 流水线发射信号
    wire pipeline_i_valid = has_wait_entry;
    wire [SCOREBOARD_ENTRY_INDEX-1:0] pipeline_i_idx = issue_entry_reg;
    wire pipeline_i_last = (burst_addr_bias_reg == MAX_BURST_ADDR_BIAS);
    wire [`ADDR_WIDTH-1:0] pipeline_i_head_addr = scoreboard_head_addr_reg[issue_entry_reg] + burst_addr_bias_reg;
    wire [`ADDR_WIDTH-1:0] pipeline_i_history_addr = scoreboard_history_addr_reg[issue_entry_reg] + burst_addr_bias_reg;

    // 流水线回收信号
    wire pipeline_o_valid;
    wire pipeline_o_last;
    wire [SCOREBOARD_ENTRY_INDEX-1:0] pipeline_o_idx;
    wire [`MAX_MATCH_LEN_LOG2:0] pipeline_o_match_len;

    // scoreboard occupied 状态转换
    always @(posedge clk) begin
        for(i = 0; i < SCOREBOARD_DEPTH; i=i+1) begin
            if(~rst_n) begin
                scoreboard_occupied_reg[i] <= 1'b0;
            end else begin
                if(~scoreboard_occupied_reg[i]) begin
                    if(i_match_req_valid) begin
                        if(next_issue_entry == i[SCOREBOARD_ENTRY_INDEX-1:0]) begin
                            scoreboard_occupied_reg[i] <= 1'b1;
                        end else if (scoreboard_occupied_reg[next_issue_entry] && (i[SCOREBOARD_ENTRY_INDEX-1:0] == first_free_entry)) begin
                            scoreboard_occupied_reg[i] <= 1'b1; 
                        end
                    end
                end else if (scoreboard_occupied_reg[i] && (i[SCOREBOARD_ENTRY_INDEX-1:0] == first_done_entry) && scoreboard_done_reg[i]) begin
                    if(i_match_resp_ready) begin
                        scoreboard_occupied_reg[i] <= 1'b0;
                    end
                end
            end
        end
    end

    // scoreboard wait 状态转换
    always @(posedge clk) begin
        for(i = 0; i < SCOREBOARD_DEPTH; i=i+1) begin
            if(~rst_n) begin
                scoreboard_wait_reg[i] <= 1'b0;
            end else begin
                if(~scoreboard_occupied_reg[i]) begin
                    if(i_match_req_valid) begin
                        if(next_issue_entry == i[SCOREBOARD_ENTRY_INDEX-1:0]) begin
                            // 下一个要发射的条目就是我
                            scoreboard_wait_reg[i] <= 1'b1;
                        end else if (scoreboard_occupied_reg[next_issue_entry] && (i[SCOREBOARD_ENTRY_INDEX-1:0] == first_free_entry)) begin
                            // 下一个要发射的条目已经被占用了，并且当前条目是第一个空闲的条目
                            scoreboard_wait_reg[i] <= 1'b1; 
                        end
                    end
                end else if(scoreboard_wait_reg[i] && (i[SCOREBOARD_ENTRY_INDEX-1:0] == issue_entry_reg) ) begin
                    if(burst_addr_bias_reg == MAX_BURST_ADDR_BIAS) begin
                        scoreboard_wait_reg[i] <= 1'b0; // 流水线发射完成
                    end
                end else if (~scoreboard_wait_reg[i] && pipeline_o_valid && pipeline_o_last &&
                (pipeline_o_idx == i[SCOREBOARD_ENTRY_INDEX-1:0]) && // 流水线输出有效且指向当前条目
                (pipeline_o_match_len == `MATCH_PE_WIDTH) && // 最后一个匹配仍然饱和
                scoreboard_match_contd_reg[i] && // 之前的匹配都饱和
                scoreboard_match_len_reg[i] < (`MAX_MATCH_LEN - `MATCH_PE_WIDTH)) begin // 尚未达到最大匹配长度
                    scoreboard_wait_reg[i] <= 1'b1; // 继续下一轮匹配
                end
            end
        end
    end

    // scoreboard done 状态转换
    always @(posedge clk) begin
        for(i = 0; i < SCOREBOARD_DEPTH; i=i+1) begin
            if(~rst_n) begin
                scoreboard_done_reg[i] <= 1'b0;
            end else begin
                if(~scoreboard_done_reg[i] && pipeline_o_valid && pipeline_o_last && (pipeline_o_idx == i[SCOREBOARD_ENTRY_INDEX-1:0])) begin // 当流水线出现 last，且指向当前条目
                    if(~scoreboard_match_contd_reg[i] || 
                    pipeline_o_match_len < `MATCH_PE_WIDTH || // 匹配不连续（已中断）
                    scoreboard_match_len_reg[i] + pipeline_o_match_len >= `MAX_MATCH_LEN) begin //已达到最大长度
                        scoreboard_done_reg[i] <= 1'b1;
                    end 
                end else if(scoreboard_done_reg[i] && (i[SCOREBOARD_ENTRY_INDEX-1:0] == first_done_entry)) begin
                    if(i_match_resp_ready) begin
                        scoreboard_done_reg[i] <= 1'b0;
                    end
                end
            end
        end
    end

    // scoreboard 数据更新
    always @(posedge clk) begin
        for(i = 0; i < SCOREBOARD_DEPTH; i=i+1) begin
            if(~scoreboard_occupied_reg[i] && first_free_entry == i[SCOREBOARD_ENTRY_INDEX-1:0]) begin
                if(i_match_req_valid) begin
                    // 在 PE 收到 match 请求时写入当前条目
                    scoreboard_head_addr_reg[i] <= i_match_req_head_addr;
                    scoreboard_history_addr_reg[i] <= i_match_req_history_addr;
                    scoreboard_job_pe_id_reg[i] <= i_match_req_job_pe_id;
                    scoreboard_tag_reg[i] <= i_match_req_tag;
                    scoreboard_match_len_reg[i] <= 0;
                    scoreboard_match_contd_reg[i] <= 1;
                end
            end else if(scoreboard_occupied_reg[i] && ~scoreboard_done_reg[i]) begin // 考虑到猝发长度比流水线长的情况，所以只要是在占用且未完成状态都是可以更新的
                if(pipeline_o_valid && (pipeline_o_idx == i[SCOREBOARD_ENTRY_INDEX-1:0])) begin // 流水线返回了当前条目的匹配结果
                    if(scoreboard_match_contd_reg[i]) begin // 如果可以延续之前的匹配，就进行更新，不能延续则在任何情况下都丢弃
                        scoreboard_match_len_reg[i] <= scoreboard_match_len_reg[i] + pipeline_o_match_len; // 更新匹配长度
                        if(pipeline_o_last) begin // 如果是当前猝发中的最后一个结果，那么更新地址，以准备好下一轮的猝发请求
                            // 这里没有判断是否饱和，因为如果不饱和，就直接输出了
                            scoreboard_head_addr_reg[i] <= scoreboard_head_addr_reg[i] + MAX_BURST_ADDR_BIAS;
                            scoreboard_history_addr_reg[i] <= scoreboard_history_addr_reg[i] + MAX_BURST_ADDR_BIAS;
                        end else if(pipeline_o_match_len != `MATCH_PE_WIDTH) begin
                            scoreboard_match_contd_reg[i] <= 1'b0; // 如果匹配长度不饱和，后续的就要被丢弃了
                        end
                    end
                end
            end
        end
    end


endmodule