`include "util.vh"
// SRAM 2 Ports
module sram2p #(parameter AWIDTH = 12, DWIDTH = 72, NBPIPE=3)
    (input wire clk,
     input wire rst_n,
     input wire mem_enable,
     input wire write_enable,
     input wire [AWIDTH-1:0] write_address, //<addra>
     input wire [DWIDTH-1:0] write_data,
     input wire [AWIDTH-1:0] read_address, //<addrb>
     output wire [DWIDTH-1:0] read_data);


    (* ram_style = "ultra" *)
    reg [DWIDTH-1:0] mem[(1<<AWIDTH)-1:0];        // Memory Declaration
    reg [DWIDTH-1:0] mem_reg;


    // RAM : Both READ and WRITE have a latency of one
    always @ (posedge clk)begin
        if(mem_enable) begin
            if(write_enable) begin
                mem[write_address] <= write_data;
            end
            mem_reg <= mem[read_address];
        end
    end

    generate
        if (NBPIPE > 0) begin
            reg [DWIDTH-1:0] mem_pipe_reg[NBPIPE-1:0];    // Pipelines for memory
            reg mem_en_pipe_reg[NBPIPE:0];                // Pipelines for memory enable
            integer          i;
            // The enable of the RAM goes through a pipeline to produce a
            // series of pipelined enable signals required to control the data
            // pipeline.
            always @ (posedge clk) begin
                mem_en_pipe_reg[0] <= mem_enable;
                for (i=0; i < NBPIPE; i=i+1)
                    mem_en_pipe_reg[i+1] <= mem_en_pipe_reg[i];
            end

            // RAM output data goes through a pipeline.
            always @ (posedge clk)begin
                if (mem_en_pipe_reg[0])
                    mem_pipe_reg[0] <= mem_reg;
            end

            always @ (posedge clk) begin
                for (i = 0; i < NBPIPE-1; i = i+1)
                    if (mem_en_pipe_reg[i+1])
                        mem_pipe_reg[i+1] <= mem_pipe_reg[i];
            end

            assign read_data = mem_pipe_reg[NBPIPE-1];
        end
        else begin
            assign read_data = mem_reg;
        end
    endgenerate


endmodule
