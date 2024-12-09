`ifndef PARAMETERS_V
`define PARAMETERS_V

`define TD
// Parameters
`define HASH_ISSUE_WIDTH_LOG2 4
`define HASH_ISSUE_WIDTH (2**`HASH_ISSUE_WIDTH_LOG2)
`define ADDR_WIDTH 23
`define ROW_SIZE_LOG2 3
`define ROW_SIZE (2 ** `ROW_SIZE_LOG2)
`define HASH_COVER_BYTES 5
`define HASH_BITS (18-`ROW_SIZE_LOG2)
`define NUM_HASH_PE_LOG2 5
`define NUM_HASH_PE (2**`NUM_HASH_PE_LOG2)
`define HASH_BANK_ROW_LOG2 (`HASH_BITS-`NUM_HASH_PE_LOG2)
`define HASH_BANK_ROW (2**`HASH_BANK_ROW_LOG2)
`define WINDOW_LOG 20
`define WINDOW_SIZE (2**`WINDOW_LOG)

`define META_HISTORY_LEN 13
`define META_MATCH_LEN_WIDTH ($clog2(`META_HISTORY_LEN)+1) // 2**META_MATCH_LEN_WIDTH >= META_HISTORY_LEN

`define HASH_PE_SRAM_NBPIPE 1

`define HASH_CROSSBAR_FACTOR 8

`define NUM_JOB_PE_LOG2 5
`define NUM_JOB_PE (2**`NUM_JOB_PE_LOG2)
`define JOB_LEN_LOG2 6
`define JOB_LEN (2**`JOB_LEN_LOG2)
`define SHARED_MATCH_PE_SLICE_SIZE_LOG2 (`WINDOW_LOG-`NUM_JOB_PE_LOG2)

`define MESH_X_SIZE_LOG2 3
`define MESH_X_SIZE (2**`MESH_X_SIZE_LOG2)
`define MESH_Y_SIZE_LOG2 (`NUM_JOB_PE_LOG2 + 1 - `MESH_X_SIZE_LOG2)
`define MESH_Y_SIZE (2**`MESH_Y_SIZE_LOG2)
`define MESH_W (2*`ADDR_WIDTH+`NUM_JOB_PE_LOG2+`LAZY_LEN_LOG2)
`define MATCH_ENGINE_DATA_FIFO_DEPTH 64

// new parameter


`define MATCH_PE_0_SIZE_LOG2 12
`define MATCH_PE_1_SIZE_LOG2 15
`define MATCH_PE_2_SIZE_LOG2 16
`define MATCH_PE_3_SIZE_LOG2 20

`define MATCH_BURST_LEN 2
`define MATCH_PE_WIDTH_LOG2 `HASH_ISSUE_WIDTH_LOG2
`define MATCH_PE_WIDTH (2**`MATCH_PE_WIDTH_LOG2)
`define MATCH_PE_DEPTH_LOG2 16 // TODO

`define MAX_MATCH_LEN_LOG2 (`NUM_JOB_PE_LOG2 + `JOB_LEN_LOG2 - 1) // Note: NUM_JOB_PE_LOG2 + JOB_LEN_LOG2 for safe -1
`define MAX_MATCH_LEN (2**`MAX_MATCH_LEN_LOG2)
`define MATCH_LEN_WIDTH (`MAX_MATCH_LEN_LOG2+1)
`define MIN_MATCH_LEN 4

`define LAZY_LEN 4
`define LAZY_LEN_LOG2 ($clog2(`LAZY_LEN))
`define NUM_LOCAL_MATCH_PE 3
`define NUM_SHARED_MATCH_PE 1
`define NUM_MATCH_REQ_CH (`NUM_LOCAL_MATCH_PE + `NUM_SHARED_MATCH_PE)

`define SEQ_LL_BITS 17
`define SEQ_ML_BITS (`MATCH_LEN_WIDTH)
`define SEQ_OFFSET_BITS `WINDOW_LOG
`define SEQ_OFFSET_BITS_LOG2 $clog2(`SEQ_OFFSET_BITS)
`define SEQ_FIFO_DEPTH 8

`define SEQ_PACKET_SIZE 4

`endif
