`include "parameters.vh"
`include "util.vh"

module seq_serializer (
    input wire clk,
    input wire rst_n,

    input wire i_valid,
    input wire [`SEQ_LL_BITS-1:0] i_ll,
    input wire [`SEQ_ML_BITS-1:0] i_ml,
    input wire [`SEQ_OFFSET_BITS-1:0] i_offset,
    input wire i_eoj,
    input wire [`SEQ_ML_BITS-1:0] i_overlap_len,
    input wire i_delim,
    output wire i_ready,

    output wire o_valid,
    output wire [`SEQ_LL_BITS-1:0] o_ll,
    output wire [`SEQ_ML_BITS-1:0] o_ml,
    output wire [`SEQ_OFFSET_BITS-1:0] o_offset,
    output wire o_delim,
    input wire o_ready
);

    wire [`SEQ_LL_BITS-1:0] i_ml_ext = `ZERO_EXTEND(i_ml, `SEQ_LL_BITS);
    wire [`SEQ_LL_BITS-1:0] i_overlap_len_ext = `ZERO_EXTEND(i_overlap_len, `SEQ_LL_BITS);
    wire [`SEQ_LL_BITS-1:0] i_in_job_len = i_ll + i_ml_ext - i_overlap_len_ext;
    reg next_seq_valid_reg;
    reg [`SEQ_LL_BITS-1:0] this_seq_ll_reg, next_seq_ll_reg;
    reg [`SEQ_LL_BITS-1:0] this_seq_ml_reg, next_seq_ml_reg;
    reg [`SEQ_OFFSET_BITS-1:0] this_seq_offset_reg, next_seq_offset_reg;
    reg this_seq_has_overlap_reg, next_seq_has_overlap_reg;
    reg this_seq_has_gap_reg, next_seq_has_gap_reg;
    reg [`SEQ_LL_BITS-1:0] this_seq_overlap_len_reg, next_seq_overlap_len_reg;
    reg this_seq_delim_reg, next_seq_delim_reg;

    reg [4:0] state_reg;
    localparam S_PASS = 0;
    localparam S_WELD = 1;
    localparam S_FLUSH = 2;
    localparam S_FLUSH_CONT = 3;
    localparam S_FLUSH_ONE_THEN_WELD = 4;
    
    wire i_has_overlap = i_overlap_len != 0;
    wire i_has_gap = i_ml == 0;
    
    always @(posedge clk) begin
        if(~rst_n) begin
            state_reg <= 5'b0001;
        end else begin
            state_reg <= 5'b0;
            case (1'b1) 
                state_reg[S_PASS]: begin
                    if(i_valid & i_eoj) begin
                        next_seq_valid_reg <= 1'b0;
                        if(i_delim) begin
                            this_seq_ll_reg <= i_ll;
                            if(i_ml != 0) begin
                                $fatal("illegal delim");
                            end
                            this_seq_ml_reg <= '0;
                            this_seq_offset_reg <= '0;
                            this_seq_has_overlap_reg <= 1'b0;
                            this_seq_has_gap_reg <= 1'b0;
                            this_seq_overlap_len_reg <= 0;
                            this_seq_delim_reg <= 1'b1;
                            state_reg[S_FLUSH] <= 1'b1;
                        end else begin
                            this_seq_ll_reg <= i_ll;
                            this_seq_ml_reg <= i_ml_ext;
                            this_seq_offset_reg <= i_offset;
                            this_seq_has_gap_reg <= i_has_gap;
                            this_seq_has_overlap_reg <= i_has_overlap;
                            this_seq_overlap_len_reg <= i_overlap_len_ext;
                            this_seq_delim_reg <= 1'b0;
                            if(i_has_gap | i_has_overlap) begin
                                state_reg[S_WELD] <= 1'b1;
                            end else begin
                                state_reg[S_FLUSH] <= 1'b1;
                            end
                        end
                    end else begin
                        state_reg[S_PASS] <= 1'b1;
                    end
                end
                state_reg[S_WELD]: begin
                    if(i_valid) begin
                        case (1'b1)
                            this_seq_has_gap_reg: begin 
                                if(i_eoj) begin
                                    if(i_delim) begin
                                        this_seq_ll_reg <= this_seq_ll_reg + i_ll;
                                        this_seq_delim_reg <= 1'b1;
                                        state_reg[S_FLUSH] <= 1'b1;
                                    end else begin
                                        if(i_has_gap) begin
                                            this_seq_ll_reg <= this_seq_ll_reg + i_ll;
                                            state_reg[S_WELD] <= 1'b1;
                                        end else if (i_has_overlap) begin
                                            this_seq_ll_reg <= this_seq_ll_reg + i_ll;
                                            this_seq_ml_reg <= i_ml_ext;
                                            this_seq_offset_reg <= i_offset;
                                            this_seq_has_gap_reg <= 1'b0;
                                            this_seq_has_overlap_reg <= 1'b1;
                                            this_seq_overlap_len_reg <= i_overlap_len_ext;
                                            this_seq_delim_reg <= 1'b0;
                                            state_reg[S_WELD] <= 1'b1;
                                        end else begin
                                            this_seq_ll_reg <= this_seq_ll_reg + i_ll;
                                            this_seq_ml_reg <= i_ml_ext;
                                            this_seq_offset_reg <= i_offset;
                                            next_seq_valid_reg <= 1'b0;
                                            state_reg[S_FLUSH] <= 1'b1;
                                        end
                                    end
                                end else begin
                                    this_seq_ll_reg <= this_seq_ll_reg + i_ll;
                                    this_seq_ml_reg <= i_ml_ext;
                                    this_seq_offset_reg <= i_offset;
                                    next_seq_valid_reg <= 1'b0;
                                    state_reg[S_FLUSH] <= 1'b1;
                                end
                            end
                            this_seq_has_overlap_reg: begin 
                                if(i_eoj) begin
                                    if(i_delim) begin
                                        if (this_seq_overlap_len_reg <= i_ll) begin
                                            this_seq_delim_reg <= 1'b0;
                                            next_seq_ll_reg <= i_ll - this_seq_overlap_len_reg;
                                            next_seq_ml_reg <= '0;
                                            next_seq_offset_reg <= '0;
                                            next_seq_delim_reg <= 1'b1;
                                            next_seq_valid_reg <= 1'b1;
                                            state_reg[S_FLUSH] <= 1'b1;
                                        end else begin
                                            if(this_seq_ml_reg - this_seq_overlap_len_reg >= `MIN_MATCH_LEN) begin
                                                this_seq_ml_reg <= this_seq_ml_reg - this_seq_overlap_len_reg;
                                                this_seq_delim_reg <= 1'b0;
                                                next_seq_ll_reg <= i_ll;
                                                next_seq_ml_reg <= '0;
                                                next_seq_offset_reg <= '0;
                                                next_seq_delim_reg <= 1'b1;
                                                next_seq_valid_reg <= 1'b1;
                                                state_reg[S_FLUSH] <= 1'b1;
                                            end else begin
                                                this_seq_ll_reg <= this_seq_ll_reg + this_seq_ml_reg - this_seq_overlap_len_reg + i_ll;
                                                this_seq_ml_reg <= '0;
                                                this_seq_offset_reg <= '0;
                                                this_seq_delim_reg <= 1'b1;
                                                next_seq_valid_reg <= 1'b0;
                                                state_reg[S_FLUSH] <= 1'b1;
                                            end
                                        end
                                    end else begin
                                        // TODO Check here
                                        if(i_has_gap) begin
                                            if(this_seq_overlap_len_reg < i_ll) begin
                                                next_seq_ll_reg <= i_ll - this_seq_overlap_len_reg;
                                                next_seq_ml_reg <= '0;
                                                next_seq_offset_reg <= '0;
                                                next_seq_has_gap_reg <= 1'b1;
                                                next_seq_has_overlap_reg <= 1'b0;
                                                next_seq_overlap_len_reg <= 0;
                                                next_seq_delim_reg <= 1'b0;
                                                state_reg[S_FLUSH_ONE_THEN_WELD] <= 1'b1;
                                            end else if (this_seq_overlap_len_reg == i_ll) begin
                                                state_reg[S_FLUSH] <= 1'b1;
                                            end else begin
                                                this_seq_overlap_len_reg <= this_seq_overlap_len_reg - i_ll;
                                                state_reg[S_WELD] <= 1'b1;
                                            end
                                        end else begin
                                            if(this_seq_overlap_len_reg < i_in_job_len) begin
                                                next_seq_ll_reg <= i_in_job_len - this_seq_overlap_len_reg;
                                                next_seq_ml_reg <= '0;
                                                next_seq_offset_reg <= '0;
                                                next_seq_has_gap_reg <= 1'b1;
                                                next_seq_has_overlap_reg <= 1'b0;
                                                next_seq_overlap_len_reg <= 0;
                                                next_seq_delim_reg <= 1'b0;
                                                state_reg[S_FLUSH_ONE_THEN_WELD] <= 1'b1;
                                            end else if (this_seq_overlap_len_reg == i_in_job_len) begin
                                                state_reg[S_FLUSH] <= 1'b1;
                                            end else begin
                                                this_seq_overlap_len_reg <= this_seq_overlap_len_reg - i_in_job_len;
                                                state_reg[S_WELD] <= 1'b1;
                                            end
                                        end
                                    end
                                end else begin
                                    if (this_seq_overlap_len_reg <= i_ll) begin
                                        next_seq_valid_reg <= 1'b1;
                                        next_seq_ll_reg <= i_ll - this_seq_overlap_len_reg;
                                        next_seq_ml_reg <= i_ml_ext;
                                        next_seq_offset_reg <= i_offset;
                                        next_seq_delim_reg <= 1'b0;
                                        state_reg[S_FLUSH] <= 1'b1;
                                    end else if (this_seq_overlap_len_reg <= i_ll + i_ml_ext - `MIN_MATCH_LEN) begin
                                        next_seq_valid_reg <= 1'b1;
                                        next_seq_ll_reg <= '0;
                                        next_seq_ml_reg <= i_ml_ext + i_ll - this_seq_overlap_len_reg; //i_ml_ext - (this_seq_overlap_len_reg - i_ll)
                                        next_seq_offset_reg <= i_offset;
                                        next_seq_delim_reg <= 1'b0;
                                        state_reg[S_FLUSH] <= 1'b1;
                                    end else if (this_seq_overlap_len_reg <= i_ll + i_ml_ext) begin
                                        next_seq_ll_reg <= i_ll + i_ml_ext - this_seq_overlap_len_reg;
                                        next_seq_ml_reg <= '0;
                                        next_seq_offset_reg <= '0;
                                        next_seq_delim_reg <= 1'b0;
                                        next_seq_has_gap_reg <= 1'b1;
                                        next_seq_has_overlap_reg <= 1'b0;
                                        next_seq_overlap_len_reg <= 0;
                                        state_reg[S_FLUSH_ONE_THEN_WELD] <= 1'b1;
                                    end else begin
                                        this_seq_overlap_len_reg <= this_seq_overlap_len_reg - i_ll - i_ml_ext;
                                        state_reg[S_WELD] <= 1'b1;
                                    end
                                end
                            end 
                            default: begin
                                $fatal("seq_serializer: unexpected state");
                            end
                        endcase
                    end
                end
                state_reg[S_FLUSH]: begin
                    if(o_ready) begin
                        if(next_seq_valid_reg) begin
                            state_reg[S_FLUSH_CONT] <= 1'b1;
                            this_seq_ll_reg <= next_seq_ll_reg;
                            this_seq_ml_reg <= next_seq_ml_reg;
                            this_seq_offset_reg <= next_seq_offset_reg;
                            this_seq_delim_reg <= next_seq_delim_reg;
                        end else begin
                            state_reg[S_PASS] <= 1'b1;
                        end
                    end
                end
                state_reg[S_FLUSH_CONT]: begin
                    if(o_ready) begin
                        state_reg[S_PASS] <= 1'b1;
                    end
                end
                state_reg[S_FLUSH_ONE_THEN_WELD]: begin
                    if(o_ready) begin
                        state_reg[S_WELD] <= 1'b1;
                        this_seq_ll_reg <= next_seq_ll_reg;
                        this_seq_ml_reg <= next_seq_ml_reg;
                        this_seq_offset_reg <= next_seq_offset_reg;
                        this_seq_delim_reg <= next_seq_delim_reg;
                        this_seq_has_gap_reg <= next_seq_has_gap_reg;
                        this_seq_has_overlap_reg <= next_seq_has_overlap_reg;
                        this_seq_overlap_len_reg <= next_seq_overlap_len_reg;
                    end
                end
            endcase
        end
    end


endmodule