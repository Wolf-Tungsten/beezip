`include "parameters.vh"

module job_match_pe_cluster #(parameter JOB_PE_IDX = 0) (
    input wire clk,
    input wire rst_n,

    input wire hash_batch_valid,
    input wire [`ADDR_WIDTH-1:0] hash_batch_head_addr,
    input wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_history_valid,
    input wire [`HASH_ISSUE_WIDTH*`ADDR_WIDTH-1:0] hash_batch_history_addr,
    input wire [`HASH_ISSUE_WIDTH*`META_MATCH_LEN_WIDTH-1:0] hash_batch_meta_match_len,
    input wire [`HASH_ISSUE_WIDTH-1:0] hash_batch_meta_match_can_ext,
    input wire hash_batch_delim,
    output wire hash_batch_ready,

    // output seq port
    output wire seq_valid,
    output wire [`SEQ_LL_BITS-1:0] seq_ll,
    output wire [`SEQ_ML_BITS-1:0] seq_ml,
    output wire [`SEQ_OFFSET_BITS-1:0] seq_offset,
    output wire seq_eoj,
    output wire [`SEQ_ML_BITS-1:0] seq_overlap_len,
    output wire seq_delim,
    input wire seq_ready,

    // shared match pe request port
    output wire [`NUM_SHARED_MATCH_PE-1:0] shared_match_req_valid,
    input wire [`NUM_SHARED_MATCH_PE-1:0] shared_match_req_ready,
    output wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] shared_match_req_head_addr,
    output wire [`NUM_SHARED_MATCH_PE*`ADDR_WIDTH-1:0] shared_match_req_history_addr,
    output wire [`NUM_SHARED_MATCH_PE*`LAZY_LEN_LOG2-1:0] shared_match_req_tag,

    // shared match pe response port
    input wire shared_match_resp_valid,
    output wire shared_match_resp_ready,
    input wire [`NUM_SHARED_MATCH_PE*`LAZY_LEN_LOG2-1:0] shared_match_resp_tag,
    input wire [`NUM_SHARED_MATCH_PE*`MATCH_LEN_WIDTH-1:0] shared_match_resp_match_len,

    // local match pe write port
    input wire [`ADDR_WIDTH-1:0] match_pe_write_addr,
    input wire [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data,
    input wire match_pe_write_enable
);
    // add rst_n pipe reg
    reg rst_n_reg;
    always @(posedge clk) begin
        rst_n_reg = rst_n;
    end

    wire match_req_group_valid;
    wire [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_head_addr;
    wire [`LAZY_LEN*`ADDR_WIDTH-1:0] match_req_group_history_addr;
    wire [`LAZY_LEN*`NUM_MATCH_REQ_CH-1:0] match_req_group_router_map;
    wire [`LAZY_LEN-1:0] match_req_group_strb;
    wire match_req_group_ready;

    wire match_resp_group_valid;
    wire match_resp_group_ready;
    wire [`LAZY_LEN*`MATCH_LEN_WIDTH-1:0] match_resp_group_match_len;
    
    job_pe job_pe_inst (
        .clk(clk),
        .rst_n(rst_n_reg),
        .hash_batch_valid(hash_batch_valid),
        .hash_batch_head_addr(hash_batch_head_addr),
        .hash_batch_history_valid(hash_batch_history_valid),
        .hash_batch_history_addr(hash_batch_history_addr),
        .hash_batch_meta_match_len(hash_batch_meta_match_len),
        .hash_batch_meta_match_can_ext(hash_batch_meta_match_can_ext),
        .hash_batch_delim(hash_batch_delim),
        .hash_batch_ready(hash_batch_ready),

        .match_req_group_valid(match_req_group_valid),
        .match_req_group_head_addr(match_req_group_head_addr),
        .match_req_group_history_addr(match_req_group_history_addr),
        .match_req_group_router_map(match_req_group_router_map),
        .match_req_group_strb(match_req_group_strb),
        .match_req_group_ready(match_req_group_ready),

        .match_resp_group_valid(match_resp_group_valid),
        .match_resp_group_ready(match_resp_group_ready),
        .match_resp_group_match_len(match_resp_group_match_len),

        .seq_valid(seq_valid),
        .seq_ll(seq_ll),
        .seq_ml(seq_ml),
        .seq_offset(seq_offset),
        .seq_eoj(seq_eoj),
        .seq_overlap_len(seq_overlap_len),
        .seq_delim(seq_delim),
        .seq_ready(seq_ready)
    );

    wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_req_valid;
    wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_req_ready;
    wire [`NUM_LOCAL_MATCH_PE*`ADDR_WIDTH-1:0] local_match_req_head_addr;
    wire [`NUM_LOCAL_MATCH_PE*`ADDR_WIDTH-1:0] local_match_req_history_addr;
    wire [`NUM_LOCAL_MATCH_PE*`LAZY_LEN_LOG2-1:0] local_match_req_tag;

    match_req_scheduler match_req_scheduler_inst (
        .clk(clk),
        .rst_n(rst_n_reg),
        .match_req_group_valid(match_req_group_valid),
        .match_req_group_ready(match_req_group_ready),
        .match_req_group_head_addr(match_req_group_head_addr),
        .match_req_group_history_addr(match_req_group_history_addr),
        .match_req_group_router_map(match_req_group_router_map),
        .match_req_group_strb(match_req_group_strb),
        .match_req_valid({shared_match_req_valid, local_match_req_valid}),
        .match_req_ready({shared_match_req_ready, local_match_req_ready}),
        .match_req_head_addr({shared_match_req_head_addr, local_match_req_head_addr}),
        .match_req_history_addr({shared_match_req_history_addr, local_match_req_history_addr}),
        .match_req_tag({shared_match_req_tag, local_match_req_tag})
    );

    wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_resp_valid;
    wire [`NUM_LOCAL_MATCH_PE-1:0] local_match_resp_ready;
    wire [`NUM_LOCAL_MATCH_PE*`MATCH_LEN_WIDTH-1:0] local_match_resp_match_len;
    wire [`NUM_LOCAL_MATCH_PE*`LAZY_LEN_LOG2-1:0] local_match_resp_tag;

    // add reg for match pe write
    reg [`ADDR_WIDTH-1:0] match_pe_write_addr_reg;
    reg [`MATCH_PE_WIDTH*8-1:0] match_pe_write_data_reg;
    reg match_pe_write_enable_reg;

    always @(posedge clk) begin
        match_pe_write_addr_reg <= match_pe_write_addr;
        match_pe_write_data_reg <= match_pe_write_data;
        match_pe_write_enable_reg <= match_pe_write_enable;
    end

    genvar i;
    generate
        for(i = 0; i < `NUM_LOCAL_MATCH_PE; i = i + 1) begin
            match_pe #(.TAG_BITS(`LAZY_LEN_LOG2), .SIZE_LOG2(`MATCH_PE_SIZE_LOG2(i))) local_match_pe_inst (
                .clk(clk),
                .rst_n(rst_n_reg),
                .match_req_valid(local_match_req_valid[i]),
                .match_req_ready(local_match_req_ready[i]),
                .match_req_tag(local_match_req_tag[i*`LAZY_LEN_LOG2 +: `LAZY_LEN_LOG2]),
                .match_req_head_addr(local_match_req_head_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .match_req_history_addr(local_match_req_history_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),

                .match_resp_valid(local_match_resp_valid[i]),
                .match_resp_ready(local_match_resp_ready[i]),
                .match_resp_tag(local_match_resp_tag[i*`LAZY_LEN_LOG2 +: `LAZY_LEN_LOG2]),
                .match_resp_match_len(local_match_resp_match_len[i*`MATCH_LEN_WIDTH +: `MATCH_LEN_WIDTH]),

                .write_addr(match_pe_write_addr_reg),
                .write_data(match_pe_write_data_reg),
                .write_enable(match_pe_write_enable_reg)
            );
        end
    endgenerate

    // match_resp_sync
    match_resp_sync match_resp_sync_inst (
        .clk(clk),
        .rst_n(rst_n_reg),

        .req_group_valid(match_req_group_valid),
        .req_group_strb(match_req_group_strb),

        .resp_valid({shared_match_resp_valid, local_match_resp_valid}),
        .resp_ready({shared_match_resp_ready, local_match_resp_ready}),
        .resp_tag({shared_match_resp_tag, local_match_resp_tag}),
        .resp_match_len({shared_match_resp_match_len, local_match_resp_match_len}),

        .resp_group_valid(match_resp_group_valid),
        .resp_group_ready(match_resp_group_ready),
        .resp_group_match_len(match_resp_group_match_len)
    );

endmodule

