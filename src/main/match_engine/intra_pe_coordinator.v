`include "parameters.vh"
`include "log.vh"

module intra_pe_coordinator #(parameter MATCH_PE_IDX = 0)(
        input wire clk,
        input wire rst_n,

        // input hash result port
        input wire input_hash_result_valid,
        input wire [`ADDR_WIDTH-1:0] input_head_addr,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] input_hash_valid_vec,
        input wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] input_history_addr_vec,
        output wire input_hash_result_ready,

        // // head window buffer flow control
        // input wire input_head_window_buffer_write_enable,
        // output wire output_head_window_buffer_write_enable,

        // job launch port
        input wire job_launch_valid,
        input wire job_delim,
        output wire job_launch_ready,

        // PU request ports
        output wire [`MATCH_PU_NUM-1:0] pu_req_valid,
        output wire [`ADDR_WIDTH-1:0] pu_req_head_addr,
        output wire [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] pu_req_hist_addr,
        output wire [`MATCH_PU_NUM-1:0] pu_req_is_ext,
        input wire [`MATCH_PU_NUM-1:0] pu_req_ready,

        // coordinator table slot port
        input wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM-1:0] slot_resp_valid,
        input wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM*`TABLE_ADDR_TAG_BITS-1:0] slot_resp_addr_tag,
        input wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM*(`MAX_MATCH_LEN_LOG2+1)-1:0] slot_resp_match_len,
        input wire [`HASH_ISSUE_WIDTH*`MATCH_PU_NUM-1:0] slot_resp_extp,

        // commit port
        output wire commit_valid,
        output wire commit_job_delim,
        output wire commit_end_of_job,
        output wire commit_has_overlap,
        output wire [`JOB_LEN_LOG2+1-1:0] commit_overlap_len,
        output wire [`JOB_LEN_LOG2+1-1:0] commit_lit_len,
        output wire [`ADDR_WIDTH-1:0] commit_match_start_addr,
        output wire [`MAX_MATCH_LEN_LOG2+1-1:0] commit_match_len,
        output wire [`ADDR_WIDTH-1:0] commit_history_addr,
        input wire commit_ready
    );

    localparam MATCH_LEN_BITS = `MAX_MATCH_LEN_LOG2 + 1;
    localparam JOB_LEN = `HASH_ISSUE_WIDTH * `JOB_ISSUE_LEN;

    localparam SLOT_STATE_BITS = 3;
    localparam slot_state_wait = 3'b000;
    localparam slot_state_pending = 3'b010;
    localparam slot_state_wait_ext = 3'b011;
    localparam slot_state_pending_ext = 3'b100;
    localparam slot_state_done = 3'b101;

    reg slot_row_valid_reg [`HASH_ISSUE_WIDTH-1:0];
    reg [`MATCH_PU_NUM*SLOT_STATE_BITS-1:0] slot_state_reg [`HASH_ISSUE_WIDTH-1:0];
    reg [`MATCH_PU_NUM*`ADDR_WIDTH-1:0] slot_hist_addr_reg [`HASH_ISSUE_WIDTH-1:0];
    reg [`MATCH_PU_NUM*MATCH_LEN_BITS-1:0] slot_match_len_reg [`HASH_ISSUE_WIDTH-1:0];

    reg [`ADDR_WIDTH-1:0] job_head_addr_reg;
    reg job_delim_reg;
    reg empty_job_reg;
    reg [`ADDR_WIDTH-1:0] head_ptr_reg;
    reg [`ADDR_WIDTH-1:0] spec_ptr_reg;
    reg [`ADDR_WIDTH-1:0] table_head_ptr_reg;
    reg [`ADDR_WIDTH-1:0] prev_match_addr_reg;

    localparam COORD_STATE_BITS = 4;
    localparam coord_state_idle = 4'b0000;
    localparam coord_state_load_table = 4'b0001;
    localparam coord_state_issue_head = 4'b0010;
    localparam coord_state_seek_valid_row = 4'b0011;
    localparam coord_state_issue_spec = 4'b0100;
    localparam coord_state_wait_done = 4'b0101;
    localparam coord_state_commit = 4'b0110;
    localparam coord_state_end_of_job = 4'b0111;
    localparam coord_state_empty_hash_fifo = 4'b1000;

    reg [COORD_STATE_BITS-1:0] coord_state_reg;

    /** begin >>> Hash Result FIFO **/
    localparam HASH_RESULT_FIFO_WIDTH = `ADDR_WIDTH + `HASH_ISSUE_WIDTH*`ROW_SIZE + `HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH;
    wire hash_result_fifo_input_ready;
    wire hash_result_fifo_output_valid;
    wire [`ADDR_WIDTH-1:0] hash_result_fifo_output_head_addr;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE-1:0] hash_result_fifo_output_hash_valid_vec;
    wire [`HASH_ISSUE_WIDTH*`ROW_SIZE*`ADDR_WIDTH-1:0] hash_result_fifo_output_history_addr_vec;
    wire input_block_barrier;

    wire hash_result_fifo_input_valid = input_hash_result_valid & ~input_block_barrier;
    assign input_hash_result_ready = hash_result_fifo_input_ready & ~input_block_barrier;

    fifo #(.DEPTH(`JOB_ISSUE_LEN), .W(HASH_RESULT_FIFO_WIDTH)) hash_result_fifo (
             .clk(clk),
             .rst_n(rst_n),
             .input_valid(hash_result_fifo_input_valid),
             .input_payload({input_head_addr, input_hash_valid_vec, input_history_addr_vec}),
             .input_ready(hash_result_fifo_input_ready),
             .output_valid(hash_result_fifo_output_valid),
             .output_payload({hash_result_fifo_output_head_addr, hash_result_fifo_output_hash_valid_vec, hash_result_fifo_output_history_addr_vec}),
             .output_ready((coord_state_reg == coord_state_load_table)||(coord_state_reg == coord_state_empty_hash_fifo))
         );
    /** Hash Result FIFO <<< end**/

    /** begin >>> head window buffer flow control **/
    // assign output_head_window_buffer_write_enable = input_head_window_buffer_write_enable && (coord_state_reg == coord_state_idle);
    /** head window buffer flow control <<< end **/


    /** begin >>> reorganize slot resp **/
    wire [`MATCH_PU_NUM-1:0] slot_resp_valid_internal [`HASH_ISSUE_WIDTH-1:0];
    wire [`MATCH_PU_NUM*`TABLE_ADDR_TAG_BITS-1:0] slot_resp_addr_tag_internal [`HASH_ISSUE_WIDTH-1:0];
    wire [`MATCH_PU_NUM*MATCH_LEN_BITS-1:0] slot_resp_match_len_internal [`HASH_ISSUE_WIDTH-1:0];
    wire [`MATCH_PU_NUM-1:0] slot_resp_extp_internal [`HASH_ISSUE_WIDTH-1:0];
    genvar i, j;
    generate;
        for(i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
            for (j = 0; j < `MATCH_PU_NUM; j = j + 1) begin
                assign slot_resp_valid_internal[i][j] = slot_resp_valid[i*`MATCH_PU_NUM + j];
                assign slot_resp_addr_tag_internal[i][j*`TABLE_ADDR_TAG_BITS +: `TABLE_ADDR_TAG_BITS] = slot_resp_addr_tag[i*`MATCH_PU_NUM*`TABLE_ADDR_TAG_BITS + j*`TABLE_ADDR_TAG_BITS +: `TABLE_ADDR_TAG_BITS];
                assign slot_resp_match_len_internal[i][j*MATCH_LEN_BITS +: MATCH_LEN_BITS] = slot_resp_match_len[i*`MATCH_PU_NUM*MATCH_LEN_BITS + j*MATCH_LEN_BITS +: MATCH_LEN_BITS];
                assign slot_resp_extp_internal[i][j] = slot_resp_extp[i*`MATCH_PU_NUM + j];
            end
        end
    endgenerate
    /** reorganize slot resp <<< end **/

    /** begin >>> slot state machine **/
    wire [`TABLE_ADDR_TAG_BITS-1:0] table_addr_tag = table_head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2 +: `TABLE_ADDR_TAG_BITS];

    genvar rowIdx, slotIdx;
    generate
        for(rowIdx = 0; rowIdx < `HASH_ISSUE_WIDTH; rowIdx = rowIdx + 1) begin: slot_state_machine_row
            for (slotIdx = 0; slotIdx < `MATCH_PU_NUM; slotIdx = slotIdx + 1) begin: slot_state_machine_slot
                always @(posedge clk) begin
                    if (~rst_n) begin
                    end
                    else begin
                        if (coord_state_reg == coord_state_load_table) begin
                            if(slotIdx == 0) begin
                                // init slot row valid
                                slot_row_valid_reg[rowIdx] <= `TD |hash_result_fifo_output_hash_valid_vec[rowIdx*`ROW_SIZE +: `ROW_SIZE];
                            end
                            // set slot state, hist addr and match and init match len to 0
                            slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD hash_result_fifo_output_hash_valid_vec[rowIdx*`ROW_SIZE + slotIdx] ? slot_state_wait : slot_state_done;
                            slot_hist_addr_reg[rowIdx][slotIdx*`ADDR_WIDTH +: `ADDR_WIDTH] <= `TD hash_result_fifo_output_history_addr_vec[rowIdx*`ROW_SIZE*`ADDR_WIDTH + slotIdx*`ADDR_WIDTH +: `ADDR_WIDTH];
                            slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] <= `TD 0;
                        end
                        else begin
                            // slot state machine
                            case (slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS])
                                slot_state_wait: begin
                                    if (coord_state_reg == coord_state_issue_head && head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0] == rowIdx) begin
                                        if(pu_req_ready[slotIdx]) begin
                                            slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_pending;
                                            `ifdef MATCH_PE_SLOT_STATE_MACHINE_LOG
                                                $display("[MatchPESlotStateMachine] PE %d row %d slot %d send to pu at head_ptr=%d, wait->pending", MATCH_PE_IDX, rowIdx, slotIdx, head_ptr_reg);
                                            `endif 
                                        end
                                    end
                                    else if (coord_state_reg == coord_state_issue_spec && spec_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0] == rowIdx) begin
                                        if(pu_req_ready[slotIdx]) begin
                                            slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_pending;
                                            `ifdef MATCH_PE_SLOT_STATE_MACHINE_LOG
                                                $display("[MatchPESlotStateMachine] PE %d row %d slot %d send to pu at spec_ptr=%d, wait->pending", MATCH_PE_IDX, rowIdx, slotIdx, spec_ptr_reg);
                                            `endif 
                                        end
                                    end
                                end
                                slot_state_pending: begin
                                    if (slot_resp_valid[rowIdx * `MATCH_PU_NUM + slotIdx]) begin
                                        if(table_addr_tag != slot_resp_addr_tag_internal[rowIdx][slotIdx * `TABLE_ADDR_TAG_BITS +: `TABLE_ADDR_TAG_BITS]) begin
                                            // unfortunately addr tag not match, there maybe a bus conflict
                                            slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] <= `TD 0;
                                            slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_done;
                                        end
                                        else begin
                                            // addr tag match
                                            slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] <= `TD slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] + slot_resp_match_len_internal[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS];
                                            if(slot_resp_extp_internal[rowIdx][slotIdx]) begin
                                                slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_wait_ext;
                                            end
                                            else begin
                                                slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_done;
                                            end
                                        end
                                    end
                                end
                                slot_state_wait_ext: begin
                                    if (coord_state_reg == coord_state_issue_head && head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0] == rowIdx) begin
                                        if(pu_req_ready[slotIdx]) begin
                                            slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= `TD slot_state_pending_ext;
                                        end
                                    end
                                end
                                slot_state_pending_ext: begin
                                    if (slot_resp_valid[rowIdx * `MATCH_PU_NUM + slotIdx] && table_addr_tag == slot_resp_addr_tag_internal[rowIdx][slotIdx * `TABLE_ADDR_TAG_BITS +: `TABLE_ADDR_TAG_BITS]) begin
                                        slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] <= slot_match_len_reg[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS] + slot_resp_match_len_internal[rowIdx][slotIdx*MATCH_LEN_BITS +: MATCH_LEN_BITS];
                                        slot_state_reg[rowIdx][slotIdx*SLOT_STATE_BITS +: SLOT_STATE_BITS] <= slot_state_done;
                                    end
                                end
                                slot_state_done: begin
                                    // wait table load to clear
                                end
                            endcase
                        end
                    end
                end
            end
        end
    endgenerate

    /** slot state machine <<< end **/

    /** begin >>> coordinator state machine **/
    wire [`MATCH_PU_NUM*SLOT_STATE_BITS-1:0] head_slot_states = slot_state_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]];
    wire [`MATCH_PU_NUM-1:0] head_slot_done;
    wire [`MATCH_PU_NUM-1:0] head_slot_pending;
    wire [`MATCH_PU_NUM-1:0] head_slot_pending_ext;
    wire [`MATCH_PU_NUM-1:0] head_slot_wait;
    wire [`MATCH_PU_NUM-1:0] head_slot_wait_ext;
    wire [`MATCH_PU_NUM*SLOT_STATE_BITS-1:0] spec_slot_states = slot_state_reg[spec_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]];
    wire [`MATCH_PU_NUM-1:0] spec_slot_wait;
    wire [`MATCH_PU_NUM-1:0] spec_slot_wait_spec;

    wire [MATCH_LEN_BITS-1:0] head_slot_match_len[`MATCH_PU_NUM-1:0];
    wire [`ADDR_WIDTH-1:0] head_slot_history_addr[`MATCH_PU_NUM-1:0];

    wire [MATCH_LEN_BITS-1:0] best_match_len, best_match_len_intm0, best_match_len_intm1;
    wire [`ADDR_WIDTH-1:0] best_history_addr, best_history_intm0, best_history_intm1;

    assign best_match_len_intm0 = head_slot_match_len[0] >= head_slot_match_len[1] ? head_slot_match_len[0] : head_slot_match_len[1];
    assign best_match_len_intm1 = head_slot_match_len[2] >= head_slot_match_len[3] ? head_slot_match_len[2] : head_slot_match_len[3];
    assign best_match_len = best_match_len_intm0 >= best_match_len_intm1 ? best_match_len_intm0 : best_match_len_intm1;
    assign best_history_intm0 = head_slot_match_len[0] >= head_slot_match_len[1] ? head_slot_history_addr[0] : head_slot_history_addr[1];
    assign best_history_intm1 = head_slot_match_len[2] >= head_slot_match_len[3] ? head_slot_history_addr[2] : head_slot_history_addr[3];
    assign best_history_addr = best_match_len_intm0 >= best_match_len_intm1 ? best_history_intm0 : best_history_intm1;

    generate;
        for(j = 0; j < `MATCH_PU_NUM; j = j + 1) begin
            assign head_slot_done[j] = (head_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_done);
            assign head_slot_pending[j] = (head_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_pending);
            assign head_slot_pending_ext[j] = (head_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_pending_ext);
            assign head_slot_wait[j] = (head_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_wait);
            assign head_slot_wait_ext[j] = (head_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_wait_ext);
            assign spec_slot_wait[j] = (spec_slot_states[j*SLOT_STATE_BITS +: SLOT_STATE_BITS] == slot_state_wait);
            assign head_slot_match_len[j] = slot_match_len_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]][j*MATCH_LEN_BITS +: MATCH_LEN_BITS];
            assign head_slot_history_addr[j] = slot_hist_addr_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]][j*`ADDR_WIDTH +: `ADDR_WIDTH];
        end
    endgenerate

    wire [`HASH_ISSUE_WIDTH+`MIN_SPEC_GAP-1-1:0] row_valid_expand;
    wire [`HASH_ISSUE_WIDTH-1:0] spec_row_all_invalid;
    assign row_valid_expand[`HASH_ISSUE_WIDTH +: `MIN_SPEC_GAP-1] = {(`MIN_SPEC_GAP-1){1'b1}};
    generate;
        for (i = 0; i < `HASH_ISSUE_WIDTH; i = i+1) begin
            assign row_valid_expand[i] = slot_row_valid_reg[i];
            assign spec_row_all_invalid[i] = ~|(row_valid_expand[i +: `MIN_SPEC_GAP]);
        end
    endgenerate

    assign job_launch_ready = (coord_state_reg == coord_state_idle);
    assign input_block_barrier = (coord_state_reg != coord_state_idle);

    always @(posedge clk) begin
        if (~rst_n) begin
            coord_state_reg <= `TD coord_state_idle;
        end
        else begin
            case (coord_state_reg)
                coord_state_idle: begin
                    if (job_launch_valid) begin
                        head_ptr_reg <= `TD hash_result_fifo_output_head_addr;
                        job_head_addr_reg <= `TD hash_result_fifo_output_head_addr;
                        spec_ptr_reg <= `TD hash_result_fifo_output_head_addr + `MIN_SPEC_GAP;
                        prev_match_addr_reg <= `TD hash_result_fifo_output_head_addr;
                        job_delim_reg <= `TD job_delim;
                        coord_state_reg <= `TD coord_state_load_table;
                        empty_job_reg <= `TD 1;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d idle -> load_table, head_ptr=%d ", MATCH_PE_IDX, hash_result_fifo_output_head_addr);
`endif

                    end
                end
                coord_state_load_table: begin
                    // load hash result into job table, see slot state machine
                    if(hash_result_fifo_output_head_addr + `HASH_ISSUE_WIDTH > head_ptr_reg) begin
                        table_head_ptr_reg <= `TD hash_result_fifo_output_head_addr;
                        coord_state_reg <= `TD coord_state_issue_head;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: load_table -> issue_head, table_head_ptr=%d", MATCH_PE_IDX, hash_result_fifo_output_head_addr);
`endif

                    end
                end
                coord_state_issue_head: begin
                    if (!slot_row_valid_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]]) begin
                        head_ptr_reg <= `TD head_ptr_reg + 1;
                        coord_state_reg <= `TD coord_state_seek_valid_row;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG
                        $display("[MatchPECoordinatorStateMachine] PE %d: issue_head -> seek_valid_row", MATCH_PE_IDX);
`endif
                    end
                    else begin
                        // issue wait/wait_ext state slot, see pu req logic
                        if (&head_slot_done) begin
                            coord_state_reg <= `TD coord_state_commit;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG
                            $display("[MatchPECoordinatorStateMachine] PE %d: issue_head -> commit, head_ptr=%d", MATCH_PE_IDX, head_ptr_reg);
`endif
                        end
                        else if (~|(head_slot_wait | head_slot_wait_ext)) begin
                            if(head_ptr_reg + `MIN_SPEC_GAP < table_head_ptr_reg + `HASH_ISSUE_WIDTH) begin
                                spec_ptr_reg <= `TD head_ptr_reg + `MIN_SPEC_GAP;
                                coord_state_reg <= `TD coord_state_issue_spec;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG
                                $display("[MatchPECoordinatorStateMachine] PE %d: issue_head -> issue_spec, head_ptr=%d", MATCH_PE_IDX, head_ptr_reg);
`endif
                            end
                            else begin
                                coord_state_reg <= `TD coord_state_wait_done;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG
                                $display("[MatchPECoordinatorStateMachine] PE %d: issue_head -> wait_done, head_ptr=%d", MATCH_PE_IDX, head_ptr_reg);
`endif
                            end
                        end
                    end
                end
                coord_state_seek_valid_row: begin
                    if (head_ptr_reg >= job_head_addr_reg + JOB_LEN) begin
                        coord_state_reg <= `TD coord_state_end_of_job;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: seek_valid_row -> end_of_job @head_ptr=%d", MATCH_PE_IDX, head_ptr_reg);
`endif

                    end
                    else if (head_ptr_reg >= table_head_ptr_reg + `HASH_ISSUE_WIDTH) begin
                        coord_state_reg <= `TD coord_state_load_table;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: seek_valid_row -> load_table", MATCH_PE_IDX);
`endif

                    end
                    else if (slot_row_valid_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]]) begin
                        spec_ptr_reg <= `TD head_ptr_reg + `MIN_SPEC_GAP;
                        coord_state_reg <= `TD coord_state_issue_head;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: seek_valid_row -> issue_head @head_ptr=%d", MATCH_PE_IDX, head_ptr_reg);
`endif

                    end
                    else if (spec_row_all_invalid[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]]) begin
                        head_ptr_reg <= `TD head_ptr_reg + `MIN_SPEC_GAP;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: seek_valid_row head_ptr += MIN_SPEC_GAP goto %d", MATCH_PE_IDX, head_ptr_reg + `MIN_SPEC_GAP);
`endif

                    end
                    else begin
                        head_ptr_reg <= `TD head_ptr_reg + 1;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: seek_valid_row head_ptr += 1 goto %d", MATCH_PE_IDX, head_ptr_reg + 1);
`endif

                    end
                end
                coord_state_issue_spec: begin
                    // issue wait state slot, see pu request logic
                    if(|head_slot_wait_ext) begin
                        coord_state_reg <= `TD coord_state_issue_head;
                    end
                    else if (&head_slot_done) begin
                        coord_state_reg <= `TD coord_state_commit;
                    end
                    else if (~(|spec_slot_wait)) begin
                        if (spec_ptr_reg + 1 < table_head_ptr_reg + `HASH_ISSUE_WIDTH) begin
                            spec_ptr_reg <= `TD spec_ptr_reg + 1;
                        end
                        else begin
                            coord_state_reg <= `TD coord_state_wait_done;
                        end
                    end
                end
                coord_state_wait_done: begin
                    if (|head_slot_wait_ext) begin
                        coord_state_reg <= `TD coord_state_issue_head;
                    end
                    else if (&head_slot_done) begin
                        coord_state_reg <= `TD coord_state_commit;
                    end
                end
                coord_state_commit: begin
                    // commit match result, see commit result logic
                    if (best_match_len < `MIN_MATCH_LEN) begin
                        if (head_ptr_reg + 1 >= job_head_addr_reg + JOB_LEN) begin
                            head_ptr_reg <= `TD head_ptr_reg + 1;
                            coord_state_reg <= `TD coord_state_end_of_job;
                        end
                        else if (head_ptr_reg + 1 >= table_head_ptr_reg + `HASH_ISSUE_WIDTH) begin
                            head_ptr_reg <= `TD head_ptr_reg + 1;
                            spec_ptr_reg <= `TD head_ptr_reg + 1 + `MIN_SPEC_GAP;
                            coord_state_reg <= `TD coord_state_load_table;
                        end
                        else begin
                            head_ptr_reg <= `TD head_ptr_reg + 1;
                            spec_ptr_reg <= `TD head_ptr_reg + 1 + `MIN_SPEC_GAP;
                            coord_state_reg <= `TD coord_state_issue_head;
                        end
                    end
                    else if (commit_ready) begin
                        prev_match_addr_reg <= `TD head_ptr_reg + best_match_len;
                        if(head_ptr_reg + best_match_len >= job_head_addr_reg + JOB_LEN) begin
                            coord_state_reg <= `TD coord_state_empty_hash_fifo;
                        end
                        else if (head_ptr_reg + best_match_len >= table_head_ptr_reg + `HASH_ISSUE_WIDTH) begin
                            head_ptr_reg <= `TD head_ptr_reg + best_match_len;
                            spec_ptr_reg <= `TD head_ptr_reg + best_match_len + `MIN_SPEC_GAP;
                            coord_state_reg <= `TD coord_state_load_table;
                        end
                        else begin
                            head_ptr_reg <= `TD head_ptr_reg + best_match_len;
                            spec_ptr_reg <= `TD head_ptr_reg + best_match_len + `MIN_SPEC_GAP;
                            coord_state_reg <= `TD coord_state_issue_head;
                        end
                    end
                end
                coord_state_end_of_job: begin
                    // commit empty result, see commit result logic
                    if (commit_ready) begin
                        coord_state_reg <= `TD coord_state_idle;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: end_of_job -> idle", MATCH_PE_IDX);
`endif

                    end
                end
                coord_state_empty_hash_fifo: begin
                    if(!hash_result_fifo_output_valid) begin
                        coord_state_reg <= `TD coord_state_idle;
`ifdef MATCH_PE_COORD_STATE_MACHINE_LOG

                        $display("[MatchPECoordinatorStateMachine] PE %d: empty_hash_fifo -> idle", MATCH_PE_IDX);
`endif

                    end
                end
            endcase
        end
    end
    /** coordinator state machine <<< end **/

    /** begin >> pu request logic **/
    assign pu_req_valid = (coord_state_reg == coord_state_issue_head) ? (head_slot_wait | head_slot_wait_ext) : ((coord_state_reg == coord_state_issue_spec ? spec_slot_wait : 0));
    assign pu_req_head_addr = (coord_state_reg == coord_state_issue_head) ? head_ptr_reg : spec_ptr_reg;
    assign pu_req_hist_addr = (coord_state_reg == coord_state_issue_head) ? slot_hist_addr_reg[head_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]] : slot_hist_addr_reg[spec_ptr_reg[`HASH_ISSUE_WIDTH_LOG2-1:0]];
    assign pu_req_is_ext = {`MATCH_PU_NUM{(coord_state_reg == coord_state_issue_head)}} & head_slot_wait_ext;
    /** pu request logic <<< end **/

    /** begin >>> commit logic **/
    assign commit_valid = ((coord_state_reg == coord_state_commit) && (best_match_len >= `MIN_MATCH_LEN)) || (coord_state_reg == coord_state_end_of_job);
    assign commit_job_delim = job_delim_reg;
    assign commit_end_of_job = ((coord_state_reg == coord_state_commit) && (head_ptr_reg + best_match_len >= job_head_addr_reg + JOB_LEN)) || (coord_state_reg == coord_state_end_of_job);
    assign commit_has_overlap = (head_ptr_reg + best_match_len >= job_head_addr_reg + JOB_LEN) && !(coord_state_reg == coord_state_end_of_job);
    assign commit_overlap_len = (head_ptr_reg + best_match_len) - (job_head_addr_reg + JOB_LEN);
    assign commit_lit_len = head_ptr_reg - prev_match_addr_reg;
    assign commit_match_start_addr = head_ptr_reg;
    assign commit_match_len = (coord_state_reg == coord_state_end_of_job) ? 0 : (best_match_len >= `MIN_MATCH_LEN) ? best_match_len : 0;
    assign commit_history_addr = best_history_addr;
    /** commit logic <<< end **/

endmodule
