`default_nettype none
`timescale 1ns / 1ps

// USB LS bit-layer TX. Host clkdiv INT=8 so fifo_push (~15 clk) never
// PULL-stalls a 3-tick bit. Not INT=1: that starves the depth-4 FIFO.
module tb_usb;
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
    initial uio_in = 8'h01; // LS idle J: D-=1 D+=0 (pullup, not driven)

    `include "test/tb_host.vh"
    `include "test/usb_pkts.vh"

    localparam [15:0] W00 = 16'hE0A7;
    localparam [15:0] W01 = 16'h80A0;
    localparam [15:0] W02 = 16'h6080;
    localparam [15:0] W03 = 16'h0001;

    localparam integer BIT_TICKS = 24; // 3 SM ops * INT=8
    localparam [1:0] J = 2'b01;
    localparam [1:0] K = 2'b10;
    localparam [1:0] SE0 = 2'b00;
    localparam [1:0] SE1 = 2'b11;

    integer errors;
    integer nsym;
    reg [1:0] sym [0:127];
    integer nbytes;
    integer body [0:15];
    integer nrz [0:255];

    wire [1:0] line = {
        uio_oe[1] ? uio_out[1] : uio_in[1],
        uio_oe[0] ? uio_out[0] : uio_in[0]
    };

    task wait_fifo_space;
        begin
            host(3'd7, 4'd5);
            while (uo_out[4:2] == 3'd4) begin
                repeat (8) @(posedge clk);
                host(3'd7, 4'd5);
            end
        end
    endtask

    task send_n;
        input integer n;
        input integer which;
        integer i;
        reg [15:0] w;
        begin
            for (i = 0; i < n; i = i + 1) begin
                if (which == 0) w = PKT_ACK[i];
                else if (which == 1) w = PKT_D0FF[i];
                else w = PKT_D000[i];
                if (i == 4)
                    start0;
                if (i >= 4)
                    wait_fifo_space;
                fifo_push(w);
            end
            if (n <= 4)
                start0;
        end
    endtask

    task sample_wire;
        integer armed, waitc, ticks;
        begin
            nsym = 0;
            armed = 0;
            waitc = 0;
            ticks = 0;
            while (ticks < 8000) begin
                @(posedge clk);
                ticks = ticks + 1;
                if (!armed) begin
                    if (uio_oe[1:0] === 2'b11 && line === K) begin
                        armed = 1;
                        waitc = BIT_TICKS / 2;
                    end
                end else if (waitc != 0) begin
                    waitc = waitc - 1;
                    if (waitc == 0) begin
                        if (uio_oe[1:0] === 2'b00) begin
                            ticks = 8000;
                        end else begin
                            if (nsym > 127) begin
                                $display("FAIL USB LS EOP");
                                errors = errors + 1;
                                ticks = 8000;
                            end else begin
                                if (line === SE1) begin
                                    $display("FAIL USB LS SE1");
                                    errors = errors + 1;
                                end
                                sym[nsym] = line;
                                nsym = nsym + 1;
                                waitc = BIT_TICKS;
                            end
                        end
                    end
                end
            end
            if (!armed) begin
                $display("FAIL USB LS SYNC");
                errors = errors + 1;
            end
        end
    endtask

    function [15:0] crc_step;
        input [15:0] crc;
        input [7:0] b;
        integer k;
        reg [15:0] c;
        begin
            c = crc ^ {8'h00, b};
            for (k = 0; k < 8; k = k + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 16'hA001;
                else
                    c = c >> 1;
            end
            crc_step = c;
        end
    endfunction

    task destuff_decode;
        integer i, ones, nrzi, prev, nbit, k, b, eop, fail;
        begin
            nbytes = 0;
            fail = 0;
            i = 0;
            while (i < nsym && sym[i] === J)
                i = i + 1;
            if (i >= nsym) begin
                $display("FAIL USB LS SYNC");
                errors = errors + 1;
                fail = 1;
            end
            prev = J;
            nbit = 0;
            ones = 0;
            eop = -1;
            while (!fail && i < nsym) begin
                if (sym[i] === SE1) begin
                    $display("FAIL USB LS SE1");
                    errors = errors + 1;
                    fail = 1;
                end else if (sym[i] === SE0) begin
                    eop = i;
                    i = nsym;
                end else begin
                    nrzi = (sym[i] !== prev) ? 0 : 1;
                    prev = sym[i];
                    if (ones == 6) begin
                        if (nrzi != 0) begin
                            $display("FAIL USB LS stuff");
                            errors = errors + 1;
                            fail = 1;
                        end
                        ones = 0;
                    end else begin
                        nrz[nbit] = nrzi;
                        nbit = nbit + 1;
                        ones = nrzi ? ones + 1 : 0;
                    end
                    i = i + 1;
                end
            end
            if (!fail && (eop < 0 || eop + 2 >= nsym)) begin
                $display("FAIL USB LS EOP");
                errors = errors + 1;
                fail = 1;
            end
            if (!fail && (sym[eop] !== SE0 || sym[eop + 1] !== SE0 || sym[eop + 2] !== J)) begin
                $display("FAIL USB LS EOP");
                errors = errors + 1;
                fail = 1;
            end
            if (!fail && (nbit % 8)) begin
                $display("FAIL USB LS SYNC");
                errors = errors + 1;
                fail = 1;
            end
            if (!fail) begin
                for (i = 0; i < nbit / 8; i = i + 1) begin
                    b = 0;
                    for (k = 0; k < 8; k = k + 1)
                        b = b | (nrz[i * 8 + k] << k);
                    body[i] = b;
                end
                nbytes = nbit / 8;
                if (nbytes < 2 || body[0] != 8'h80) begin
                    $display("FAIL USB LS SYNC");
                    errors = errors + 1;
                    fail = 1;
                end
            end
            if (!fail && (((body[1] & 15) !== ((~body[1] >> 4) & 15)))) begin
                $display("FAIL USB LS PID");
                errors = errors + 1;
            end
        end
    endtask

    task check_crc_data;
        integer i, npl;
        reg [15:0] crc, got, residue;
        begin
            if (nbytes < 4) begin
                $display("FAIL USB LS CRC");
                errors = errors + 1;
            end else begin
                npl = nbytes - 4;
                crc = 16'hFFFF;
                for (i = 0; i < npl; i = i + 1)
                    crc = crc_step(crc, body[2 + i] & 255);
                crc = crc ^ 16'hFFFF;
                got = ((body[nbytes - 1] & 255) << 8) | (body[nbytes - 2] & 255);
                if (got !== crc) begin
                    $display("FAIL USB LS CRC got %h want %h", got, crc);
                    errors = errors + 1;
                end
                residue = 16'hFFFF;
                for (i = 0; i < npl + 2; i = i + 1)
                    residue = crc_step(residue, body[2 + i] & 255);
                if (residue !== 16'hB001) begin
                    $display("FAIL USB LS CRC residue %h", residue);
                    errors = errors + 1;
                end
            end
        end
    endtask

    task run_pkt;
        input integer n;
        input integer which;
        integer err0;
        begin
            err0 = errors;
            fork
                send_n(n, which);
                sample_wire;
            join
            destuff_decode;
            if (which == 0) begin
                if (nbytes !== 2 || body[0] !== 8'h80 || body[1] !== 8'hD2) begin
                    $display("FAIL USB LS PID ACK %0h %0h", body[0], body[1]);
                    errors = errors + 1;
                end
            end else begin
                check_crc_data;
                if (which == 1) begin
                    if (nbytes !== 5 || body[2] !== 8'hFF || body[3] !== 8'h00 || body[4] !== 8'hFF) begin
                        $display("FAIL USB LS CRC FF swapped?");
                        errors = errors + 1;
                    end
                end else begin
                    if (nbytes !== 5 || body[2] !== 8'h00 || body[3] !== 8'h40 || body[4] !== 8'hBF) begin
                        $display("FAIL USB LS CRC 00");
                        errors = errors + 1;
                    end
                end
            end
            halt;
            repeat (2 * BIT_TICKS) @(posedge clk);
            if (errors == err0)
                $display("USB LS pkt %0d ok nsym=%0d", which, nsym);
        end
    endtask

    initial begin
        errors = 0;
        ui_in = 0;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        imem_wr(W00); imem_wr(W01); imem_wr(W02); imem_wr(W03);
        shift16(16'd8);
        host(3'd6, 4'b0000);

        run_pkt(N_ACK, 0);
        run_pkt(N_D0FF, 1);
        run_pkt(N_D000, 2);

        if (!errors)
            $display("PASS USB LS");
        else begin
            $display("USB LS TB FAILED");
            $finish(1);
        end
        $finish(0);
    end
endmodule
