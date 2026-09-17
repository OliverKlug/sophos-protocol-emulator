`default_nettype none
`timescale 1ns / 1ps

module tb_uart;
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

    task host;
        input [2:0] cmd;
        input [3:0] nib;
        begin
            @(negedge clk);
            ui_in = {1'b0, cmd, nib};
            @(negedge clk);
            ui_in[7] = 1'b1;
            @(negedge clk);
            ui_in[7] = 1'b0;
        end
    endtask

    task shift16;
        input [15:0] w;
        begin
            host(3'd0, w[15:12]);
            host(3'd0, w[11:8]);
            host(3'd0, w[7:4]);
            host(3'd0, w[3:0]);
        end
    endtask

    task imem_wr;
        input [15:0] w;
        begin
            shift16(w);
            host(3'd1, 4'd0);
        end
    endtask

    integer errors;
    integer i;
    integer j;
    reg [79:0] trace;
    integer found;

    // fw/uart_tx.py idle-before-OE
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

    initial begin
        errors = 0;
        ui_in = 0;
        uio_in = 8'hFF;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        shift16(16'd0);
        host(3'd2, 4'd0);

        imem_wr(P0);
        imem_wr(P1);
        imem_wr(P2);
        imem_wr(P3);
        imem_wr(P4);
        imem_wr(P5);
        imem_wr(P6);
        imem_wr(P7);
        imem_wr(P8);
        imem_wr(P9);
        imem_wr(PA);
        imem_wr(PB);
        imem_wr(PC);
        imem_wr(PD);

        shift16(16'h0055);
        host(3'd3, 4'd0);
        host(3'd5, 4'b0001);

        trace = 0;
        for (i = 0; i < 40; i = i + 1) begin
            @(posedge clk);
            trace = {trace[78:0], uio_out[0]};
        end
        found = 0;
        for (j = 0; j <= 30; j = j + 1) begin
            if (trace[j+9 -: 10] == 10'b0101010101)
                found = 1;
        end
        if (!found) begin
            $display("FAIL UART 0x55 not in trace %b", trace);
            errors = errors + 1;
        end else
            $display("PASS UART TX 0x55");

        host(3'd7, 4'd0);
        @(posedge clk);
        if (uo_out == 8'd0) begin
            $display("FAIL peek PC still 0");
            errors = errors + 1;
        end else
            $display("PASS peek PC %0d", uo_out);

        if (errors) begin
            $display("UART TB FAILED");
            $finish(1);
        end
        $display("UART TB OK");
        $finish(0);
    end
endmodule
