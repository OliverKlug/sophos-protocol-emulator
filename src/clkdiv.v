`default_nettype none

// f_sm = f_sys / (INT + FRAC/256). INT=0 treated as 1.
module protoemu_clkdiv (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        run,
    input  wire [15:0] div_int,
    input  wire [7:0]  div_frac,
    output reg         tick
);
    reg [23:0] phase;
    wire [15:0] intval = (div_int == 16'd0) ? 16'd1 : div_int;
    wire [23:0] thresh = {intval, div_frac};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 24'd0;
            tick <= 1'b0;
        end else if (!run) begin
            phase <= 24'd0;
            tick <= 1'b0;
        end else begin
            if (phase + 24'd256 >= thresh) begin
                phase <= phase + 24'd256 - thresh;
                tick <= 1'b1;
            end else begin
                phase <= phase + 24'd256;
                tick <= 1'b0;
            end
        end
    end
endmodule
