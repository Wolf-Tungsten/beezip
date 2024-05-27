`timescale 100ps / 1ps
`default_nettype none
`include "parameters.vh"

module beezip_sim;

  localparam block_size = 128 * 1024;
  localparam max_input_buffer = 128 * 1024 * 1024;
  reg [`HASH_ISSUE_WIDTH_LOG2+1-1:0] cfg_max_queued_req_num = 1;
  /** load input file **/
  // load whole file into input_file_buf and record file length in input_file_len
  string
      input_file_path, output_seq_path, output_index_path, output_vcd_path, output_throughput_path, beezip_mode;
  integer input_fd, output_seq_fd, output_index_fd, output_throughput_fd;
  reg [7:0] input_file_buf  [max_input_buffer-1:0];
  reg [7:0] input_read_byte;
  integer input_file_len, trimmed_input_file_len, code, i;
  integer input_job_count, output_job_count;
  reg [31:0] block_seq_count;
  initial begin
    if (!$value$plusargs("input_file=%s", input_file_path)) begin
      $display("Error: input_file not specified");
      $finish;
    end
    if (!$value$plusargs("beezip_mode=%s", beezip_mode)) begin
      $display("Error: beezip_mode not specified");
      $finish;
    end
    if (beezip_mode == "fast") begin
      cfg_max_queued_req_num = 1;
    end else if (beezip_mode == "balanced") begin
      cfg_max_queued_req_num = 2;
    end else if (beezip_mode == "better") begin
      cfg_max_queued_req_num = 4;
    end else begin
      $display("Error: beezip_mode not supported");
      $finish;
    end
    output_seq_path = $sformatf("%s.seq", input_file_path);
    output_index_path = $sformatf("%s.index", input_file_path);
    output_vcd_path = $sformatf("%s.vcd", input_file_path);
    output_throughput_path = $sformatf("%s.throughput", input_file_path);
    input_fd = $fopen(input_file_path, "rb");
    output_seq_fd = $fopen(output_seq_path, "wb");
    output_index_fd = $fopen(output_index_path, "wb");
    output_throughput_fd = $fopen(output_throughput_path, "w");
    if (input_fd == 0) begin
      $display("Error: input_file not found");
      $finish;
    end
    input_file_len = 0;
    while (!$feof(input_fd)) begin
      input_file_buf[input_file_len] = $fgetc(input_fd);
      input_file_len = input_file_len + 1;
    end
    $fclose(input_fd);
    trimmed_input_file_len = input_file_len - (input_file_len % `JOB_LEN);
    input_job_count = trimmed_input_file_len / `JOB_LEN;
    output_job_count = input_job_count - 1;
  end

  /** connect dut **/
  reg clk, rst_n;

  reg input_valid, input_delim;
  wire input_ready;
  reg [`HASH_ISSUE_WIDTH*8-1:0] input_data;

  wire output_valid;
  wire [64*4-1:0] output_seq_quad;
  reg [63:0] output_seq;
  reg output_ready;

  beezip dut (
      .clk  (clk),
      .rst_n(rst_n),

      .cfg_max_queued_req_num(cfg_max_queued_req_num),

      .input_valid(input_valid),
      .input_ready(input_ready),
      .input_delim(input_delim),
      .input_data (input_data),

      .output_valid(output_valid),
      .output_seq_quad(output_seq_quad),
      .output_ready(output_ready)
  );

  initial begin
    $dumpfile("beezip_sim.vcd");
    $dumpvars(0, beezip_sim);
    $display("Simulation start: %s, mode=%s", input_file_path, beezip_mode);
  end

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  integer input_file_ptr;
  initial begin
    // reset
    rst_n = 1'b0;
    input_valid = 1'b0;
    input_delim = 1'b0;
    input_data = 0;
    input_file_ptr = 0;
    #50 rst_n = 1'b1;

    @(negedge clk);
    input_valid = 1'b1;
    while (input_file_ptr < trimmed_input_file_len) begin
      integer i;
      for (i = 0; i < `HASH_ISSUE_WIDTH; i = i + 1) begin
        input_data[i*8+:8] = input_file_buf[input_file_ptr+i];
      end
      input_delim = (input_file_ptr > 0) && (((input_file_ptr + `HASH_ISSUE_WIDTH) % block_size == 0) || (input_file_ptr + `HASH_ISSUE_WIDTH == trimmed_input_file_len));
      while (!input_ready) @(posedge clk);
      @(negedge clk);
      input_file_ptr = input_file_ptr + `HASH_ISSUE_WIDTH;
    end
    input_valid = 1'b0;
  end

  integer output_watch_dog;
  integer output_job_head_addr;
  integer output_next_verify_addr;
  integer output_delim_count;

  reg [3:0] check_seq_reg;

  reg seq_valid;
  reg seq_delim;
  reg seq_end_of_job;
  reg seq_has_overlap;
  reg [3:0] seq_reserved;
  reg [7:0] seq_overlap_len;
  reg [15:0] seq_lit_len;
  reg [23:0] seq_offset;
  reg [7:0] seq_match_len;

  integer history_addr;
  real remain_process;

  task match_correctness_and_output();
    for (check_seq_reg = 0; check_seq_reg < 4; check_seq_reg = check_seq_reg + 1) begin
      output_seq = output_seq_quad[check_seq_reg*64+:64];
      {seq_match_len, seq_offset, seq_lit_len, seq_overlap_len, seq_reserved, seq_has_overlap, seq_end_of_job, seq_delim, seq_valid} = output_seq;
        if(seq_valid) begin
          output_next_verify_addr = output_next_verify_addr + seq_lit_len;
        history_addr = output_next_verify_addr - seq_offset;
        for (integer i = 0; i < seq_match_len; i = i + 1) begin
          if (input_file_buf[output_next_verify_addr+i] != input_file_buf[history_addr+i]) begin
            $display("Error: seq head_addr=%d, history_addr=%d, mismatch@i=%d",
                    output_next_verify_addr[`ADDR_WIDTH-1:0], history_addr[`ADDR_WIDTH-1:0], i);
            $finish;
          end
        end
        //output to seq file
        $fwrite(output_seq_fd, "%u", output_seq);
        block_seq_count = block_seq_count + 1;
        // end of job process
        if (seq_end_of_job) begin
          output_job_count = output_job_count - 1;
          if (output_job_count % 100 == 0) begin
            remain_process = (input_job_count + 0.0 - output_job_count) / input_job_count * 100;
            $display("%s: remain job %d / %d (%.3f%%)", input_file_path, output_job_count,
                    input_job_count, remain_process);
          end
          if (output_job_count == 0) begin
            $fwrite(output_index_fd, "%u", block_seq_count);
            $fwrite(output_throughput_fd, "input_length=%d, cycle=%d", trimmed_input_file_len,
                    $time / 10);
            $fclose(output_seq_fd);
            $fclose(output_index_fd);
            $fclose(output_throughput_fd);
            $finish;
          end else begin
            if (!seq_has_overlap) begin
              if (output_next_verify_addr != output_job_head_addr + `JOB_LEN) begin
                $display("Error: seq gap error!");
                $finish;
              end
            end else begin
              if(output_next_verify_addr + seq_match_len - seq_overlap_len != output_job_head_addr + `JOB_LEN) begin
                $display("Error: seq overlap error!");
                $finish;
              end
              output_next_verify_addr = output_next_verify_addr + seq_match_len - seq_overlap_len;
            end
            output_job_head_addr = output_job_head_addr + `JOB_LEN;

            if (output_job_head_addr % block_size == 0) begin
              $fwrite(output_index_fd, "%u", block_seq_count);
              block_seq_count = 0;
            end

          end
        end else begin
          output_next_verify_addr = output_next_verify_addr + seq_match_len;
        end
      end
    end
  endtask

  initial begin
    output_job_head_addr = 0;
    output_next_verify_addr = 0;
    output_delim_count = 0;
    block_seq_count = 0;
    output_ready = 1'b1;
    output_watch_dog = 0;

    while (1) begin
      @(posedge clk);
      if (output_valid) begin
        match_correctness_and_output();
        output_watch_dog = 0;
      end else begin
        output_watch_dog = output_watch_dog + 1;
        if (output_watch_dog > 1000000) begin
          $display("Error: output watch dog timeout!");
          $finish;
        end
      end
    end
  end
endmodule
