`default_nettype none

// Flop stand-in for RM_IHPSG13_1P_1024x8. CMOS5L macro is a prior, not a drop-in.
// Bytes 0..511 IMEM image, 512..1023 capture.
module protoemu_sram_flop (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [9:0]  addr,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata
);
    reg [7:0] mem [0:1023];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 8'd0;
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 8'd0;
        end else begin
            rdata <= mem[addr];
            if (we)
                mem[addr] <= wdata;
        end
    end
endmodule
