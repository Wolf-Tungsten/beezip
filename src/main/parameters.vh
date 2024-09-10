`ifndef PARAMETERS_V
`define PARAMETERS_V

`define TD #1
// Parameters
`define HASH_ISSUE_WIDTH_LOG2 5
`define HASH_ISSUE_WIDTH (2**`HASH_ISSUE_WIDTH_LOG2)
`define ADDR_WIDTH 23
`define ROW_SIZE_LOG2 2
`define ROW_SIZE (2 ** `ROW_SIZE_LOG2)
`define HASH_COVER_BYTES 5
`define HASH_BITS 17
`define NUM_HASH_PE_LOG2 5
`define NUM_HASH_PE (2**`NUM_HASH_PE_LOG2)
`define HASH_BANK_ROW_LOG2 (`HASH_BITS-`NUM_HASH_PE_LOG2)
`define HASH_BANK_ROW (2**`HASH_BANK_ROW_LOG2)
`define WINDOW_LOG 20
`define WINDOW_SIZE (2**`WINDOW_LOG)

`define META_HISTORY_LEN 15
`define META_MATCH_LEN_WIDTH ($clog2(`META_HISTORY_LEN)+1) // 2**META_MATCH_LEN_WIDTH >= META_HISTORY_LEN

`define HASH_PE_SRAM_NBPIPE 1

`define HASH_CROSSBAR_FACTOR 8

`define NUM_JOB_PE_LOG2 4
`define NUM_JOB_PE (2**`NUM_JOB_PE_LOG2)
`define NUM_MATCH_PE_LOG2 4
`define NUM_MATCH_PE (2**`NUM_MATCH_PE_LOG2)
`define JOB_LEN_LOG2 6
`define JOB_LEN (2**`JOB_LEN_LOG2)

`define MATCH_ENGINE_DATA_FIFO_DEPTH 64

// new parameter

`define MATCH_PE_WIDTH_LOG2 `HASH_ISSUE_WIDTH_LOG2
`define MATCH_PE_WIDTH (2**`MATCH_PE_WIDTH_LOG2)
`define MATCH_PE_DEPTH_LOG2 16 // TODO

`define MAX_MATCH_LEN_LOG2 12
`define MATCH_LEN_WIDTH (`MAX_MATCH_LEN_LOG2+1)
`define MAX_MATCH_LEN (2**`MAX_MATCH_LEN_LOG2)
`define MIN_MATCH_LEN 4

`define LAZY_MATCH_LEN 3
`define LAZY_MATCH_LEN_LOG2 ($clog2(`LAZY_MATCH_LEN))

`define SEQ_LL_BITS 17
`define SEQ_ML_BITS (`MAX_MATCH_LEN_LOG2+1) // 7
`define SEQ_OFFSET_BITS `WINDOW_LOG // 20
`define SEQ_FIFO_DEPTH 8

`define SEQ_PACKET_SIZE 4

`endif
