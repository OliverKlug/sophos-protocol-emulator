`default_nettype none
`timescale 1ns / 1ps

// UART TX 0x55 into the 32-slot hold-this shadow. Host dump + timed replay.
module tb_cap;
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_klug_sophos dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    `include "test/tb_host.vh"
    `include "test/uart_cap.vh"

    localparam [15:0] P0 = 16'hE001;
    localparam [15:0] P1 = 16'hE061;
    localparam [15:0] P2 = 16'h80A0;
    localparam [15:0] P3 = 16'hE000;
    localparam [15:0] P4 = 16'h6001;
    localparam [15:0] P5 = 16'h6001;
    localparam [15:0] P6 = 16'h6001;
    localparam [15:0] P7 = 16'h6001;
    localparam [15:0] P8 = 16'h6001;
    localparam [15:0] P9 = 16'h6001;
    localparam [15:0] PA = 16'h6001;
    localparam [15:0] PB = 16'h6001;
    localparam [15:0] PC = 16'hE001;
    localparam [15:0] PD = 16'h0002;

    integer errors;
    integer i, h;
    integer wptr;
    integer pin, oe, hold;
    integer got_pin [0:31];
    integer got_oe [0:31];

    initial begin
        errors = 0;
        ui_in = 0;
        uio_in = 8'h01;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        imem_wr(P0); imem_wr(P1); imem_wr(P2); imem_wr(P3);
        imem_wr(P4); imem_wr(P5); imem_wr(P6); imem_wr(P7);
        imem_wr(P8); imem_wr(P9); imem_wr(PA); imem_wr(PB);
        imem_wr(PC); imem_wr(PD);
        fifo_push(16'h0055);
        start0_cap;
        repeat (48) @(posedge clk);
        halt;

        host(3'd7, 4'd6);
        @(posedge clk);
        wptr = uo_out;
        if (wptr !== N_UART_CAP) begin
            $display("FAIL CAP wptr %0d != %0d", wptr, N_UART_CAP);
            errors = errors + 1;
        end else
            $display("PASS UART CAP");

        for (i = 0; i < N_UART_CAP; i = i + 1) begin
            host(3'd7, 4'd11);
            @(posedge clk);
            pin = uo_out;
            host(3'd7, 4'd12);
            @(posedge clk);
            oe = uo_out;
            host(3'd7, 4'd13);
            @(posedge clk);
            hold = uo_out;
            if (pin !== UART_CAP_PIN[i] || oe !== UART_CAP_OE[i]) begin
                $display("FAIL CAP dump [%0d] pin %h oe %h want %h %h",
                    i, pin, oe, UART_CAP_PIN[i], UART_CAP_OE[i]);
                errors = errors + 1;
            end
            if (hold === 8'd0) begin
                $display("FAIL CAP dump [%0d] hold 0", i);
                errors = errors + 1;
            end
            got_pin[i] = pin;
            got_oe[i] = oe;
            host(3'd7, 4'd14);
        end
        if (!errors)
            $display("PASS CAP dump");

        replay0;
        @(posedge clk);
        for (i = 0; i < N_UART_CAP; i = i + 1) begin
            for (h = 0; h < 256; h = h + 1) begin
                @(negedge clk);
                if (uio_out === got_pin[i] && uio_oe === got_oe[i])
                    h = 256;
                @(posedge clk);
            end
            if (uio_out !== got_pin[i] || uio_oe !== got_oe[i]) begin
                $display("FAIL CAP replay [%0d] out %h oe %h want %h %h",
                    i, uio_out, uio_oe, got_pin[i], got_oe[i]);
                errors = errors + 1;
            end
        end
        if (!errors)
            $display("PASS CAP timed replay");

        if (errors) begin
            $display("CAP TB FAILED");
            $finish(1);
        end
        $display("CAP TB OK");
        $finish(0);
    end
endmodule
