`default_nettype none

// Field split identity. Same packing as ISA.md / sim/isa.py / src/sm.v.
module decode_check (
    input wire [15:0] w
);
    wire [2:0] op    = w[15:13];
    wire       side  = w[12];
    wire [3:0] delay = w[11:8];
    wire [7:0] pay   = w[7:0];
    wire [15:0] rebuilt = {op, side, delay, pay};

    always @* begin
        assert (rebuilt == w);
        assert (op <= 3'd7);
        assert (delay <= 4'd15);
    end
endmodule
