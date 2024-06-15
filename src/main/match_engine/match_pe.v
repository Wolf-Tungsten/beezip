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
    reg [SCOREBOARD_ENTRY_INDEX-1:0] first_wait_entry;
    reg [SCOREBOARD_ENTRY_INDEX-1:0] first_done_entry;
    reg no_free_entry;
    reg has_wait_entry;
    reg has_done_entry;
    integer i;
    always @(*) begin
        first_free_entry = 0;
        first_wait_entry = 0;
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
            if(scoreboard_wait_reg[i] == 1) begin
                first_wait_entry = i[SCOREBOARD_ENTRY_INDEX-1:0];
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

    // 流水线发射信号
    wire pipeline_i_valid = has_wait_entry;
    wire [SCOREBOARD_ENTRY_INDEX-1:0] pipeline_i_idx = first_wait_entry;
    reg pipeline_i_last;
    reg [`ADDR_WIDTH-1:0] pipeline_i_head_addr;
    reg [`ADDR_WIDTH-1:0] pipeline_i_history_addr;
    // 流水线回收信号
    wire pipeline_o_valid;
    wire pipeline_o_last;
    wire [SCOREBOARD_ENTRY_INDEX-1:0] pipeline_o_idx;
    wire [`MATCH_PU_WIDTH_LOG2:0] pipeline_o_match_len;

    // scoreboard occupied 状态转换
    always @(posedge clk) begin
        for(i = 0; i < SCOREBOARD_DEPTH; i=i+1) begin
            if(~rst_n) begin
                scoreboard_occupied_reg[i] <= 1'b0;
            end else begin
                if((i[SCOREBOARD_ENTRY_INDEX-1:0] == first_free_entry) && ~scoreboard_occupied_reg[i]) begin
                    if(i_match_req_valid) begin
                        scoreboard_occupied_reg[i] <= 1'b1;
                    end
                end else if ((i[SCOREBOARD_ENTRY_INDEX-1:0] == first_done_entry) && scoreboard_done_reg[i]) begin
                    if(o_match_req_ready) begin
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
                if((i[SCOREBOARD_ENTRY_INDEX-1:0] == first_free_entry) && ~scoreboard_occupied_reg[i]) begin
                    if(i_match_req_valid) begin
                        scoreboard_wait_reg[i] <= 1'b1;
                    end
                end else if((i[SCOREBOARD_ENTRY_INDEX-1:0] == first_wait_entry) && scoreboard_wait_reg[i]) begin
                    scoreboard_wait_reg[i] <= 1'b0; // 发射到流水线上
                end else if (pipeline_o_valid && pipeline_o_last &&
                (pipeline_o_idx == i[SCOREBOARD_ENTRY_INDEX-1:0]) && // 流水线输出有效且指向当前条目
                (pipeline_o_match_len == `MATCH_PU_WIDTH) && // 最后一个匹配仍然饱和
                scoreboard_match_contd_reg[i] && // 之前的匹配都饱和
                scoreboard_match_len_reg[i] < (`MAX_MATCH_LEN - `MATCH_PU_WIDTH)) begin // 尚未达到最大匹配长度
                    scoreboard_wait_reg[i] <= 1'b1; // 继续下一轮匹配
                end
            end
        end
    end




    


endmodule