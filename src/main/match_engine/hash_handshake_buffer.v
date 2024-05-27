`include "../parameters.vh"
module hash_handshake_buffer #(parameter HASH_ISSUE_WIDTH=`HASH_ISSUE_WIDTH,
                                   ROW_SIZE=`ROW_SIZE, ADDR_WIDTH=`ADDR_WIDTH)
    (input wire clk,
     input wire rst_n,
     input wire input_valid,
     input wire [ADDR_WIDTH-1:0] input_head_addr,
     input wire [HASH_ISSUE_WIDTH*ROW_SIZE-1:0] input_valid_array,
     input wire [HASH_ISSUE_WIDTH*ROW_SIZE*ADDR_WIDTH-1:0] input_history_addr_array,
     output wire input_ready,

     input wire read_req_valid,
     input wire [ADDR_WIDTH-1:0] read_req_addr,
     output wire read_resp_valid,
     output wire [ADDR_WIDTH-1:0] read_resp_addr,
     output wire [ROW_SIZE-1:0] read_valid_array,
     output wire [ROW_SIZE*ADDR_WIDTH-1:0] read_history_addr_array
    );

    // reg
    reg [ADDR_WIDTH-1:0] head_addr_reg;
    reg [HASH_ISSUE_WIDTH*ROW_SIZE-1:0] input_valid_array_reg;
    reg [HASH_ISSUE_WIDTH*ROW_SIZE*ADDR_WIDTH-1:0] input_history_addr_array_reg;
    reg read_resp_valid_reg;
    reg [ADDR_WIDTH-1:0] read_resp_addr_reg;
    reg [ROW_SIZE-1:0] read_valid_array_reg;
    reg [ROW_SIZE*ADDR_WIDTH-1:0] read_history_addr_array_reg;

    localparam IDX_WIDTH = $clog2(HASH_ISSUE_WIDTH);
    wire [ADDR_WIDTH-1:0] read_bias = read_req_addr-head_addr_reg;
    wire [IDX_WIDTH-1:0] read_idx = read_bias[IDX_WIDTH-1:0];

    assign input_ready = read_req_valid && (read_req_addr >= (head_addr_reg+HASH_ISSUE_WIDTH));
    assign read_resp_valid = read_resp_valid_reg;
    assign read_resp_addr = read_resp_addr_reg;
    assign read_valid_array = read_valid_array_reg;
    assign read_history_addr_array = read_history_addr_array_reg;
    integer i;
    always @(posedge clk) begin
        if(!rst_n) begin
            head_addr_reg <= 1'b0;
            read_resp_valid_reg <= 1'b0;
        end
        else begin
            if(read_req_valid) begin
                if(read_req_addr >= head_addr_reg && read_req_addr < (head_addr_reg+HASH_ISSUE_WIDTH)) begin
                    read_resp_valid_reg <= 1'b1;
                    read_resp_addr_reg <= read_req_addr;
                    read_valid_array_reg <= input_valid_array_reg[read_idx*ROW_SIZE +: ROW_SIZE];
                    read_history_addr_array_reg <= input_history_addr_array_reg[read_idx*ROW_SIZE*ADDR_WIDTH +: ROW_SIZE*ADDR_WIDTH];
                end
                else if (read_req_addr >= (head_addr_reg+HASH_ISSUE_WIDTH)) begin
                    read_resp_valid_reg <= 1'b0;
                    
                    if(input_valid) begin
                        head_addr_reg <= input_head_addr;
                        input_valid_array_reg <= input_valid_array;
                        input_history_addr_array_reg <= input_history_addr_array;
                        // for(i=0; i < HASH_ISSUE_WIDTH; i=i+1) begin
                        //     input_valid_array_reg[i] <= input_valid_array[(i+1)*HASH_ISSUE_WIDTH-1 -: HASH_ISSUE_WIDTH];
                        //     input_history_addr_array_reg[i] <= input_history_addr_array[(i+1)*HASH_ISSUE_WIDTH*ADDR_WIDTH-1 -: HASH_ISSUE_WIDTH*ADDR_WIDTH];
                        // end
                    end
                end
            end
        end
    end

endmodule
