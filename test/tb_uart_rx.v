`default_nettype none
`timescale 1ns / 1ps

module tb_uart_rx;
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_klug_protoemu dut (
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

    // fw/uart_rx_frame.py bit_ticks=8
    localparam [15:0] W00 = 16'hE080;
    localparam [15:0] W01 = 16'h2080;
    localparam [15:0] W02 = 16'h2300;
    localparam [15:0] W03 = 16'h07A2;
    localparam [15:0] W04 = 16'h4701;
    localparam [15:0] W05 = 16'h4701;
    localparam [15:0] W06 = 16'h4701;
    localparam [15:0] W07 = 16'h4701;
    localparam [15:0] W08 = 16'h4701;
    localparam [15:0] W09 = 16'h4701;
    localparam [15:0] W10 = 16'h4701;
    localparam [15:0] W11 = 16'h4701;
    localparam [15:0] W12 = 16'h00AE;
    localparam [15:0] W13 = 16'h0001;
    localparam [15:0] W14 = 16'h8020;
    localparam [15:0] W15 = 16'h0001;

    integer errors;
    integer b;
    integer bitv;
    reg [7:0] rev;

    task uart_bit;
        input val;
        integer t;
        begin
            for (t = 0; t < 8; t = t + 1) begin
                uio_in[0] = val;
                @(posedge clk);
            end
        end
    endtask

    initial begin
        errors = 0;
        ui_in = 0;
        uio_in = 8'hFF;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        imem_wr(W00);
        imem_wr(W01);
        imem_wr(W02);
        imem_wr(W03);
        imem_wr(W04);
        imem_wr(W05);
        imem_wr(W06);
        imem_wr(W07);
        imem_wr(W08);
        imem_wr(W09);
        imem_wr(W10);
        imem_wr(W11);
        imem_wr(W12);
        imem_wr(W13);
        imem_wr(W14);
        imem_wr(W15);

        start0;
        repeat (16) @(posedge clk);

        uart_bit(1'b0);
        for (b = 0; b < 8; b = b + 1) begin
            bitv = (8'h55 >> b) & 1;
            uart_bit(bitv[0]);
        end
        uart_bit(1'b1);
        repeat (32) @(posedge clk);

        host(3'd7, 4'd10);
        rev = {uo_out[0], uo_out[1], uo_out[2], uo_out[3],
               uo_out[4], uo_out[5], uo_out[6], uo_out[7]};
        if (rev !== 8'h55) begin
            $display("FAIL UART RX peek-10 raw=%h rev=%h", uo_out, rev);
            errors = errors + 1;
        end else
            $display("PASS UART RX peek-10");

        if (errors) begin
            $display("UART RX TB FAILED");
            $finish(1);
        end
        $display("UART RX TB OK");
        $finish(0);
    end
endmodule
