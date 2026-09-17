`default_nettype none
`timescale 1ns / 1ps

// JEDEC 0x9F through the 32-slot shadow in SCLK-qualified capture mode.
module tb_jedec_cap;
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
    `include "test/jedec_cap.vh"

    integer errors;
    integer i;
    integer wptr;
    integer pin;
    integer nbit;
    integer acc;
    integer b0, b1, b2;
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
        for (i = 0; i < N_JEDEC_IMEM; i = i + 1)
            imem_wr(JEDEC_CAP_IMEM[i]);
        shift16(16'd1);
        host(3'd7, 4'd15);
        fifo_push(16'h00F9);
        start0_cap;
        repeat (160) @(posedge clk);
        halt;

        host(3'd7, 4'd6);
        @(posedge clk);
        wptr = uo_out;
        if (wptr !== 32) begin
            $display("FAIL JEDEC CAP wptr %0d != 32", wptr);
            errors = errors + 1;
        end

        nbit = 0;
        acc = 0;
        for (i = 0; i < 32; i = i + 1) begin
            host(3'd7, 4'd11);
            @(posedge clk);
            pin = uo_out;
            if (nbit >= 8 && nbit < 32)
                acc = (acc << 1) | ((pin >> 2) & 1);
            nbit = nbit + 1;
            host(3'd7, 4'd14);
        end
        b0 = (acc >> 16) & 8'hFF;
        b1 = (acc >> 8) & 8'hFF;
        b2 = acc & 8'hFF;
        if (b0 !== 8'hEF || b1 !== 8'h40 || b2 !== 8'h16) begin
            $display("FAIL JEDEC CAP ID %h %h %h", b0, b1, b2);
            errors = errors + 1;
        end else if (!saw_9f) begin
            $display("FAIL JEDEC CAP flash did not see 0x9F");
            errors = errors + 1;
        end else
            $display("PASS JEDEC CAP");

        if (errors) begin
            $display("JEDEC CAP TB FAILED");
            $finish(1);
        end
        $display("JEDEC CAP TB OK");
        $finish(0);
    end
endmodule
