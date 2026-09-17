`default_nettype none
`timescale 1ns / 1ps

module tb_spi;
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

    // fw/spi_jedec.py
    localparam [15:0] W00 = 16'hE06B;
    localparam [15:0] W01 = 16'hE0A1;
    localparam [15:0] W02 = 16'hE082;
    localparam [15:0] W03 = 16'hE008;
    localparam [15:0] W04 = 16'h80A0;
    localparam [15:0] W05 = 16'hA0D6;
    localparam [15:0] W06 = 16'hE000;
    localparam [15:0] W07 = 16'hE02F;
    localparam [15:0] W08 = 16'h6001;
    localparam [15:0] W09 = 16'h5001;
    localparam [15:0] W10 = 16'h0048;
    localparam [15:0] W11 = 16'h8000;
    localparam [15:0] W12 = 16'hE02F;
    localparam [15:0] W13 = 16'h6001;
    localparam [15:0] W14 = 16'h5001;
    localparam [15:0] W15 = 16'h004D;
    localparam [15:0] W16 = 16'h8000;
    localparam [15:0] W17 = 16'hE008;
    localparam [15:0] W18 = 16'h0004;

    integer errors;
    integer i;
    reg sclk_q, cs_q;
    reg [7:0] shift_in;
    integer n_in, n_out;
    reg [23:0] reply;
    reg miso;
    integer got_cmd;
    integer saw_9f;
    wire sclk = uio_oe[1] ? uio_out[1] : 1'b0;
    wire mosi = uio_oe[0] ? uio_out[0] : 1'b0;
    wire cs   = uio_oe[3] ? uio_out[3] : 1'b1;

    always @* begin
        uio_in = 8'hFF;
        uio_in[2] = miso;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_q <= 1'b0;
            cs_q <= 1'b1;
            shift_in <= 8'd0;
            n_in <= 0;
            n_out <= 0;
            reply <= 24'hEF4016;
            miso <= 1'b1;
            got_cmd <= -1;
            saw_9f <= 0;
        end else begin
            if (cs) begin
                n_in <= 0;
                n_out <= 0;
                shift_in <= 8'd0;
                miso <= 1'b1;
                got_cmd <= -1;
            end else begin
                if (cs_q && !cs) begin
                    n_in <= 0;
                    n_out <= 0;
                    shift_in <= 8'd0;
                    got_cmd <= -1;
                    miso <= 1'b1;
                end
                if (!sclk_q && sclk) begin
                    if (got_cmd < 0) begin
                        shift_in <= {shift_in[6:0], mosi};
                        if (n_in == 7) begin
                            got_cmd <= {shift_in[6:0], mosi};
                            if ({shift_in[6:0], mosi} == 8'h9F) begin
                                n_out <= 24;
                                reply <= 24'hEF4016;
                                saw_9f <= 1;
                            end
                        end
                        n_in <= n_in + 1;
                    end
                end
                if (sclk_q && !sclk) begin
                    if (got_cmd == 8'h9F && n_out > 0) begin
                        n_out <= n_out - 1;
                        miso <= reply[n_out - 1];
                    end
                end
            end
            sclk_q <= sclk;
            cs_q <= cs;
        end
    end

    initial begin
        errors = 0;
        ui_in = 0;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        imem_wr(W00); imem_wr(W01); imem_wr(W02); imem_wr(W03);
        imem_wr(W04); imem_wr(W05); imem_wr(W06); imem_wr(W07);
        imem_wr(W08); imem_wr(W09); imem_wr(W10); imem_wr(W11);
        imem_wr(W12); imem_wr(W13); imem_wr(W14); imem_wr(W15);
        imem_wr(W16); imem_wr(W17); imem_wr(W18);

        fifo_push(16'h00F9);
        start0;
        repeat (160) @(posedge clk);

        host(3'd7, 4'd10);
        if (uo_out !== 8'hEF) begin
            $display("FAIL SPI MISO first %h != EF (loopback?)", uo_out);
            errors = errors + 1;
        end
        host(3'd7, 4'd10);
        if (uo_out !== 8'h16) begin
            $display("FAIL SPI MISO second %h != 16", uo_out);
            errors = errors + 1;
        end
        if (!saw_9f) begin
            $display("FAIL SPI flash cmd %0d", got_cmd);
            errors = errors + 1;
        end
        if (!errors)
            $display("PASS SPI MISO");

        if (errors) begin
            $display("SPI TB FAILED");
            $finish(1);
        end
        $display("SPI TB OK");
        $finish(0);
    end
endmodule
