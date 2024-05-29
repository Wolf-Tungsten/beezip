`include "parameters.vh"
`include "log.vh"

module match_pe #(parameter MATCH_PE_IDX=0) (

    input wire clk,
    input wire rst_n,

    input wire i_match_req_valid,
    input wire [`ADDR_WIDTH-1:0] i_match_req_head_addr,
    input wire [`ADDR_WIDTH-1:0] i_match_req_history_addr,
    input wire [`NUM_JOB_PE_LOG2-1:0] i_match_req_job_pe_id,
    output wire o_match_req_ready
);

    

endmodule