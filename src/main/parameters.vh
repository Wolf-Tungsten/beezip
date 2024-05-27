`ifndef PARAMETERS_V
`define PARAMETERS_V

`define TD #1
// Parameters
`define HASH_ISSUE_WIDTH_LOG2 4
`define HASH_ISSUE_WIDTH (2**`HASH_ISSUE_WIDTH_LOG2)
`define ADDR_WIDTH 23
`define ROW_SIZE 4
`define HASH_TAG_BITS 8
`define HASH_COVER_BYTES 5
`define HASH_BITS 26
`define NUM_HASH_PE_LOG2 5
`define NUM_HASH_PE (2**`NUM_HASH_PE_LOG2)
`define HASH_BANK_ROW_LOG2 (`HASH_BITS-`NUM_HASH_PE_LOG2-`HASH_TAG_BITS)
`define HASH_BANK_ROW (2**`HASH_BANK_ROW_LOG2)
`define WINDOW_LOG 19
`define WINDOW_SIZE (2**`WINDOW_LOG)

`define MATCH_PE_NUM_LOG2 4
`define MATCH_PE_NUM (2**`MATCH_PE_NUM_LOG2)
`define JOB_ISSUE_LEN_LOG2 2
`define JOB_ISSUE_LEN (2**`JOB_ISSUE_LEN_LOG2)
`define JOB_LEN_LOG2 (`JOB_ISSUE_LEN_LOG2 + `HASH_ISSUE_WIDTH_LOG2)
`define JOB_LEN (2**`JOB_LEN_LOG2)
`define TABLE_ADDR_TAG_BITS 4
`define MIN_SPEC_GAP 5

`define MATCH_ENGINE_DATA_FIFO_DEPTH 64

`define MATCH_PU_NUM_LOG2 2
`define MATCH_PU_NUM (2**`MATCH_PU_NUM_LOG2)  // should equal to ROW_SIZE

`define MAX_MATCH_LEN_LOG2 (`HASH_ISSUE_WIDTH_LOG2+`JOB_ISSUE_LEN_LOG2)
`define MAX_MATCH_LEN (2**`MAX_MATCH_LEN_LOG2)
`define MIN_MATCH_LEN 4

`define MATCH_PU_0_SIZE_LOG2 10
`define MATCH_PU_0_SIZE (2**`MATCH_PU_0_SIZE_LOG2)
`define MATCH_PU_1_SIZE_LOG2 15
`define MATCH_PU_1_SIZE (2**`MATCH_PU_1_SIZE_LOG2)
`define MATCH_PU_2_SIZE_LOG2 15
`define MATCH_PU_2_SIZE (2**`MATCH_PU_2_SIZE_LOG2)
`define MATCH_PU_3_SIZE_LOG2 `WINDOW_LOG
`define MATCH_PU_3_SIZE (2**`MATCH_PU_3_SIZE_LOG2)

`define MATCH_BURST_WIDTH `HASH_ISSUE_WIDTH
`define MATCH_BURST_LEN_LOG2 2
`define MATCH_BURST_LEN  (2**`MATCH_BURST_LEN_LOG2)

`define OUTPUT_LIT_LEN_BITS 16
`define OUTPUT_MATCH_LEN_BITS (`MAX_MATCH_LEN_LOG2+1)
`define OUTPUT_OFFSET_BITS `WINDOW_LOG
`define JOB_SEQ_FIFO_DEPTH 8

`endif