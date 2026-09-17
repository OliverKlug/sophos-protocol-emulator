`default_nettype none
`timescale 1ns / 1ps

// Short SPI mode-0 into the 32-slot shadow, then replay_en. Edge mode, not JEDEC.
module tb_spi_cap;
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
    `include "test/spi_cap.vh"

    integer errors;
    integer i;
    integer wptr;
    integer prev_sclk;
    integer nbit;
    integer acc;
    wire sclk = uio_oe[1] ? uio_out[1] : 1'b0;
    wire mosi = uio_oe[0] ? uio_out[0] : 1'b0;

    initial begin
        errors = 0;
        ui_in = 0;
        uio_in = 8'hFF;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        for (i = 0; i < N_SPI_CAP; i = i + 1)
            imem_wr(SPI_CAP_IMEM[i]);
        fifo_push(SPI_CAP_TX);
        start0_cap;
        repeat (80) @(posedge clk);
        halt;

        host(3'd7, 4'd6);
        @(posedge clk);
        wptr = uo_out;
        if (wptr > 32) begin
            $display("FAIL CAP wptr %0d overflow", wptr);
            errors = errors + 1;
        end

        replay0;
        prev_sclk = 0;
        nbit = 0;
        acc = 0;
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            @(negedge clk);
            if ((uio_oe[1:0] === 2'b11) && (prev_sclk == 0) && (sclk == 1) && (nbit < SPI_CAP_BITS)) begin
                acc = acc | (mosi << nbit);
                nbit = nbit + 1;
            end
            prev_sclk = sclk;
        end
        if (nbit !== SPI_CAP_BITS || acc !== SPI_CAP_TX) begin
            $display("FAIL SPI CAP bits n=%0d acc=%h want n=%0d %h",
                nbit, acc, SPI_CAP_BITS, SPI_CAP_TX);
            errors = errors + 1;
        end else
            $display("PASS SPI CAP replay");

        if (errors) begin
            $display("SPI CAP TB FAILED");
            $finish(1);
        end
        $display("SPI CAP TB OK");
        $finish(0);
    end
endmodule
