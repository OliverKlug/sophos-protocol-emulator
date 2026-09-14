`default_nettype none

module protoemu_fifo4 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        push,
    input  wire [15:0] wdata,
    input  wire        pop,
    output wire [15:0] rdata,
    output wire        empty,
    output wire        full,
    output wire [2:0]  level
);
    reg [15:0] mem [0:3];
    reg [2:0]  wptr;
    reg [2:0]  rptr;

    assign level = wptr - rptr;
    assign empty = (wptr == rptr);
    assign full  = (level == 3'd4);
    assign rdata = mem[rptr[1:0]];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 3'd0;
            rptr <= 3'd0;
            mem[0] <= 16'd0;
            mem[1] <= 16'd0;
            mem[2] <= 16'd0;
            mem[3] <= 16'd0;
        end else begin
            if (push && !full) begin
                mem[wptr[1:0]] <= wdata;
                wptr <= wptr + 3'd1;
            end
            if (pop && !empty)
                rptr <= rptr + 3'd1;
        end
    end
endmodule
