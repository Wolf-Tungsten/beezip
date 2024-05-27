`include "parameters.vh"


module job_dispatcher (
        input wire clk,
        input wire rst_n,

        // input data port
        input wire input_valid,
        input wire [`ADDR_WIDTH-1:0] input_head_addr,
        input wire [`HASH_ISSUE_WIDTH*8-1:0] input_data,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_hash_valid_vec,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
        input wire input_delim,
        output wire input_ready,

        // head_window_buffer write port
        output wire history_window_buffer_write_enable,
        output wire [`MATCH_PE_NUM-1:0] head_window_buffer_write_enable,
        output wire [`ADDR_WIDTH-1:0] window_buffer_write_addr,
        output wire [`HASH_ISSUE_WIDTH*8-1:0] window_buffer_write_data,

        // output hash result port
        output wire [`MATCH_PE_NUM-1:0] output_valid,
        output wire [`ADDR_WIDTH-1:0] output_head_addr,
        output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] output_hash_valid_vec,
        output wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] output_history_addr_vec,
        input wire  [`MATCH_PE_NUM-1:0] output_ready,

        // job launch port
        output wire [`MATCH_PE_NUM-1:0] job_launch_valid,
        output wire job_delim,
        input wire [`MATCH_PE_NUM-1:0] job_launch_ready
    );

    localparam SLICE_COUNTER_BITS = $clog2(`JOB_ISSUE_LEN);

    reg [`MATCH_PE_NUM-1:0] output_valid_reg;
    wire [`MATCH_PE_NUM-1:0] ovr_cyclic_shift_left = {output_valid_reg[`MATCH_PE_NUM-2:0], output_valid_reg[`MATCH_PE_NUM-1]};
    wire [`MATCH_PE_NUM-1:0] ovr_cyclic_shift_right = {output_valid_reg[0], output_valid_reg[`MATCH_PE_NUM-1: 1]};

    reg [SLICE_COUNTER_BITS-1:0] slice_counter_reg;
    reg job_init_reg;
    reg wait_job_launch; // data and hash result not convey when in wait job launch mode.
    reg job_delim_reg;

    assign output_valid = {`MATCH_PE_NUM{input_valid & ~wait_job_launch}} & output_valid_reg;
    wire output_ready_select = |(output_valid_reg & output_ready);

    wire job_launch_ready_select = |(job_launch_ready & ovr_cyclic_shift_right);
    wire job_launch_valid_internal = wait_job_launch || (input_valid && output_ready_select && (slice_counter_reg == `JOB_ISSUE_LEN-1) && job_init_reg) ;
    assign job_launch_valid = {`MATCH_PE_NUM{job_launch_valid_internal}} & ovr_cyclic_shift_right;

    wire handshake = input_valid & ~wait_job_launch & output_ready_select;

    assign input_ready = output_ready_select & ~wait_job_launch;

    assign head_window_buffer_write_enable = {`MATCH_PE_NUM{handshake}} & (output_valid_reg | ovr_cyclic_shift_right);
    assign history_window_buffer_write_enable = handshake;
    assign window_buffer_write_addr = input_head_addr;
    assign window_buffer_write_data = input_data;

    assign output_head_addr = input_head_addr;
    assign output_hash_valid_vec = input_hash_valid_vec;
    assign output_history_addr_vec = input_history_addr_vec;

    assign job_delim = wait_job_launch ? job_delim_reg : input_delim;

    always @(posedge clk) begin
        if(~rst_n) begin
            output_valid_reg <= `TD {{(`MATCH_PE_NUM-1){1'b0}}, 1'b1};
            slice_counter_reg <= `TD 0;
            job_init_reg <= `TD 0;
            wait_job_launch <= `TD 0;
            job_delim_reg <= `TD 0;
        end
        else begin
            if(wait_job_launch) begin
                if (job_launch_ready_select) begin
                    wait_job_launch <= `TD 0;
                    slice_counter_reg <= `TD 0;
                    output_valid_reg <= `TD ovr_cyclic_shift_left;
                end
            end
            else begin
                if(handshake) begin
                    if(slice_counter_reg == `JOB_ISSUE_LEN-1) begin
                        if(~job_init_reg) begin
                            job_init_reg <= `TD 1; 
                            output_valid_reg <= `TD ovr_cyclic_shift_left;
                            slice_counter_reg <= `TD 0;
                        end else if (~job_launch_ready_select) begin
                            job_delim_reg <= `TD input_delim;
                            wait_job_launch <= `TD 1;
                        end else begin
                            output_valid_reg <= `TD ovr_cyclic_shift_left;
                            slice_counter_reg <= `TD 0;
                        end
                    end
                    else begin
                        slice_counter_reg <= `TD slice_counter_reg + 1;
                    end
                end
            end
        end

    end

    `ifdef JOB_DISPATCHER_LOG
    always @(posedge clk) begin
        integer log_i;
        if(handshake) begin
            for(log_i = 0; log_i < `MATCH_PE_NUM; log_i = log_i + 1) begin
                if(output_valid[log_i]) begin
                    $display("[JobDispatcher] send hash result @%d to match PE %d", output_head_addr, log_i);
                end
            end
            for(log_i = 0; log_i < `MATCH_PE_NUM; log_i = log_i + 1) begin
                if(history_window_buffer_write_enable) begin
                    $display("[JobDispatcher] write history @%d to match PE %d", window_buffer_write_addr, log_i);
                end
            end
            for(log_i = 0; log_i < `MATCH_PE_NUM; log_i = log_i + 1) begin
                if(head_window_buffer_write_enable[log_i]) begin
                    $display("[JobDispatcher] write head @%d to match PE %d", window_buffer_write_addr, log_i);
                end
            end
            for(log_i = 0; log_i < `MATCH_PE_NUM; log_i = log_i + 1) begin
                if(job_launch_valid[log_i]) begin
                    $display("[JobDispatcher] launch job of PE %d", log_i);
                end
            end
        end
    end
    `endif
endmodule
