`default_nettype none
`timescale 1ns / 1ps

module tb_three_proto;
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

    localparam [15:0] U00 = 16'hE001;
    localparam [15:0] U01 = 16'hE061;
    localparam [15:0] U02 = 16'h80A0;
    localparam [15:0] U03 = 16'hE000;
    localparam [15:0] U04 = 16'h6001;
    localparam [15:0] U05 = 16'h6001;
    localparam [15:0] U06 = 16'h6001;
    localparam [15:0] U07 = 16'h6001;
    localparam [15:0] U08 = 16'h6001;
    localparam [15:0] U09 = 16'h6001;
    localparam [15:0] U0A = 16'h6001;
    localparam [15:0] U0B = 16'h6001;
    localparam [15:0] U0C = 16'hE001;
    localparam [15:0] U0D = 16'h0002;

    localparam [15:0] S00 = 16'hE063;
    localparam [15:0] S01 = 16'hE0A1;
    localparam [15:0] S02 = 16'hE082;
    localparam [15:0] S03 = 16'hE000;
    localparam [15:0] S04 = 16'h80A0;
    localparam [15:0] S05 = 16'hE027;
    localparam [15:0] S06 = 16'h6001;
    localparam [15:0] S07 = 16'h5001;
    localparam [15:0] S08 = 16'h0046;
    localparam [15:0] S09 = 16'h8000;
    localparam [15:0] S0A = 16'h0004;

    localparam [15:0] I00 = 16'hE060;
    localparam [15:0] I01 = 16'hE000;
    localparam [15:0] I02 = 16'hE061;
    localparam [15:0] I03 = 16'hE063;
    localparam [15:0] I04 = 16'hE027;
    localparam [15:0] I05 = 16'h80A0;
    localparam [15:0] I06 = 16'h6080;
    localparam [15:0] I07 = 16'h80A0;
    localparam [15:0] I08 = 16'h6080;
    localparam [15:0] I09 = 16'h2081;
    localparam [15:0] I0A = 16'h0045;
    localparam [15:0] I0B = 16'hE062;
    localparam [15:0] I0C = 16'hE060;
    localparam [15:0] I0D = 16'h2081;
    localparam [15:0] I0E = 16'h00B6;
    localparam [15:0] I0F = 16'hE062;
    localparam [15:0] I10 = 16'hE060;
    localparam [15:0] I11 = 16'hE061;
    localparam [15:0] I12 = 16'hE000;
    localparam [15:0] I13 = 16'hE063;
    localparam [15:0] I14 = 16'hE027;
    localparam [15:0] I15 = 16'h0005;
    localparam [15:0] I16 = 16'hE063;
    localparam [15:0] I17 = 16'hE000;
    localparam [15:0] I18 = 16'hE061;
    localparam [15:0] I19 = 16'h2081;
    localparam [15:0] I1A = 16'hE060;
    localparam [15:0] I1B = 16'h001A;

    integer errors;
    integer i, j, found, n_mosi, stretch_cnt, stall_seen;
    reg [79:0] trace;
    reg last_clk, last_sda, last_scl;
    reg [7:0] mosi_got;
    reg started, saw_start, need_ack, in_ack, ack_hi;
    integer bitc, stretch_left;
    reg slave_sda, slave_scl;
    wire sda_res = (uio_oe[0] && !uio_out[0]) ? 1'b0 : slave_sda;
    wire scl_res = (uio_oe[1] && !uio_out[1]) ? 1'b0 : slave_scl;
    wire sclk = uio_oe[1] ? uio_out[1] : 1'b0;
    wire mosi = uio_oe[0] ? uio_out[0] : 1'b0;

    integer i2c_mode;
    integer i2c_byte;
    integer od_bad;

    always @* begin
        uio_in = 8'hFF;
        if (i2c_mode) begin
            uio_in[0] = slave_sda;
            uio_in[1] = slave_scl;
        end
    end

    always @(posedge clk) begin
        if (i2c_mode && rst_n && dut.u_core.start0 && dut.u_core.u_sm0.pc >= 8'd2) begin
            if (saw_start && uio_oe[0] && uio_out[0])
                od_bad <= 1;
            if (last_scl && scl_res && last_sda && !sda_res) begin
                started <= 1'b1;
                saw_start <= 1'b1;
                bitc <= 0;
                need_ack <= 1'b0;
                in_ack <= 1'b0;
                ack_hi <= 1'b0;
                i2c_byte <= 0;
            end
            if (started && !last_scl && scl_res && !in_ack && !need_ack && stretch_left == 0 && slave_scl && bitc < 8) begin
                i2c_byte <= {i2c_byte[6:0], sda_res};
                if (bitc == 7)
                    need_ack <= 1'b1;
                bitc <= bitc + 1;
            end
            if (need_ack && last_scl && !scl_res) begin
                in_ack <= 1'b1;
                need_ack <= 1'b0;
                slave_sda <= 1'b0;
            end
            if (in_ack) begin
                slave_sda <= 1'b0;
                if (scl_res)
                    ack_hi <= 1'b1;
                if (ack_hi && last_scl && !scl_res) begin
                    in_ack <= 1'b0;
                    ack_hi <= 1'b0;
                    slave_sda <= 1'b1;
                end
            end
            if (started && uio_oe[1] && !uio_out[1] && stretch_left == 0 && !stall_seen) begin
                stretch_left <= 16;
                stall_seen <= 1;
            end
            if (stretch_left > 0) begin
                slave_scl <= 1'b0;
                stretch_left <= stretch_left - 1;
                if (stretch_left == 1)
                    slave_scl <= 1'b1;
            end
            last_sda <= sda_res;
            last_scl <= scl_res;
        end
    end

    initial begin
        errors = 0;
        ui_in = 0;
        i2c_mode = 0;
        slave_sda = 1;
        slave_scl = 1;
        started = 0;
        saw_start = 0;
        need_ack = 0;
        in_ack = 0;
        ack_hi = 0;
        bitc = 0;
        stretch_left = 0;
        stall_seen = 0;
        od_bad = 0;
        last_sda = 1;
        last_scl = 1;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        set_addr(5'd0);
        imem_wr(U00); imem_wr(U01); imem_wr(U02); imem_wr(U03);
        imem_wr(U04); imem_wr(U05); imem_wr(U06); imem_wr(U07);
        imem_wr(U08); imem_wr(U09); imem_wr(U0A); imem_wr(U0B);
        imem_wr(U0C); imem_wr(U0D);
        fifo_push(16'h0055);
        start0;
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
            $display("FAIL three proto UART 0x55");
            errors = errors + 1;
        end

        halt;
        repeat (4) @(posedge clk);
        set_addr(5'd0);
        imem_wr(S00); imem_wr(S01); imem_wr(S02); imem_wr(S03);
        imem_wr(S04); imem_wr(S05); imem_wr(S06); imem_wr(S07);
        imem_wr(S08); imem_wr(S09); imem_wr(S0A);
        fifo_push(16'h00A5);
        start0;
        last_clk = 0;
        n_mosi = 0;
        mosi_got = 0;
        for (i = 0; i < 80; i = i + 1) begin
            @(posedge clk);
            if (!last_clk && sclk && n_mosi < 8) begin
                mosi_got[n_mosi] = mosi;
                n_mosi = n_mosi + 1;
            end
            last_clk = sclk;
        end
        if (n_mosi < 8 || mosi_got !== 8'hA5) begin
            $display("FAIL three proto SPI MOSI %h bits=%0d", mosi_got, n_mosi);
            errors = errors + 1;
        end

        halt;
        repeat (4) @(posedge clk);
        set_addr(5'd0);
        imem_wr(I00); imem_wr(I01); imem_wr(I02); imem_wr(I03);
        imem_wr(I04); imem_wr(I05); imem_wr(I06); imem_wr(I07);
        imem_wr(I08); imem_wr(I09); imem_wr(I0A); imem_wr(I0B);
        imem_wr(I0C); imem_wr(I0D); imem_wr(I0E); imem_wr(I0F);
        imem_wr(I10); imem_wr(I11); imem_wr(I12); imem_wr(I13);
        imem_wr(I14); imem_wr(I15); imem_wr(I16); imem_wr(I17);
        imem_wr(I18); imem_wr(I19); imem_wr(I1A); imem_wr(I1B);
        i2c_mode = 1;
        slave_sda = 1;
        slave_scl = 1;
        started = 0;
        saw_start = 0;
        need_ack = 0;
        in_ack = 0;
        ack_hi = 0;
        bitc = 0;
        stretch_left = 0;
        stall_seen = 0;
        last_sda = 1;
        last_scl = 1;
        fifo_push(16'h0200);
        fifo_push(16'h0000);
        fifo_push(16'h0300);
        fifo_push(16'h0100);
        start0;
        fifo_push(16'h0200);
        fifo_push(16'h0000);
        fifo_push(16'h0300);
        fifo_push(16'h0100);
        repeat (16) @(posedge clk);
        fifo_push(16'h0300);
        fifo_push(16'h0100);
        fifo_push(16'h0200);
        fifo_push(16'h0000);
        repeat (16) @(posedge clk);
        fifo_push(16'h0300);
        fifo_push(16'h0100);
        fifo_push(16'h0200);
        fifo_push(16'h0000);
        repeat (200) @(posedge clk);
        if (od_bad) begin
            $display("FAIL three proto I2C OD");
            errors = errors + 1;
        end
        if (!saw_start) begin
            $display("FAIL three proto I2C START");
            errors = errors + 1;
        end
        if (i2c_byte[7:0] !== 8'hA5) begin
            $display("FAIL three proto I2C byte %h bitc=%0d", i2c_byte[7:0], bitc);
            errors = errors + 1;
        end
        if (!stall_seen) begin
            $display("FAIL three proto I2C stretch");
            errors = errors + 1;
        end

        if (errors) begin
            $display("three proto TB FAILED");
            $finish(1);
        end
        $display("PASS three proto host-load");
        $finish(0);
    end
endmodule
