`default_nettype none
`timescale 1ns / 1ps

// Drive protoemu_sm alone. Expect file from sim/lockstep.py (same cube).
module tb_sm_lockstep;
    reg clk;
    reg rst_n;
    reg start;
    reg tick;
    reg [15:0] instr;
    wire [7:0] pc;
    wire [15:0] x, y, isr, osr;
    wire [4:0] isr_cnt, osr_cnt;
    wire [7:0] pin_out, pin_oe;
    wire irq_set, irq_clr;
    wire [2:0] irq_idx;
    wire tx_pop, rx_push;
    wire [15:0] rx_data;

    protoemu_sm dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tick(tick),
        .instr(instr), .pc(pc), .x(x), .y(y), .isr(isr), .osr(osr),
        .isr_cnt(isr_cnt), .osr_cnt(osr_cnt),
        .pin_out(pin_out), .pin_oe(pin_oe), .pin_in(8'd0),
        .irq_in(8'd0), .irq_set(irq_set), .irq_clr(irq_clr), .irq_idx(irq_idx),
        .tx_data(16'd0), .tx_empty(1'b1), .tx_pop(tx_pop),
        .rx_data(rx_data), .rx_push(rx_push), .rx_full(1'b0)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer fd, n, i, k, errors;
    integer delay, n_ticks, exp_pop, exp_push;
    integer instr_i, pc_i, x_i, y_i, isr_i, osr_i, pins_i, oe_i;
    reg [1023:0] path;

    initial begin
        errors = 0;
        if (!$value$plusargs("expect=%s", path))
            path = "sim/lockstep_expect.txt";
        fd = $fopen(path, "r");
        if (fd == 0) begin
            $display("FAIL lockstep missing %s", path);
            $finish(1);
        end
        if ($fscanf(fd, "%d\n", n) != 1) begin
            $display("FAIL lockstep bad header");
            $finish(1);
        end
        for (i = 0; i < n; i = i + 1) begin
            if ($fscanf(fd, "%h %d %d %h %h %h %h %h %h %h %d %d\n",
                        instr_i, delay, n_ticks, pc_i, x_i, y_i, isr_i, osr_i,
                        pins_i, oe_i, exp_pop, exp_push) != 12) begin
                $display("FAIL lockstep bad row %0d", i);
                errors = errors + 1;
                i = n;
            end else begin
                instr = instr_i[15:0];
                start = 0;
                tick = 1;
                rst_n = 0;
                @(negedge clk);
                @(negedge clk);
                rst_n = 1;
                @(negedge clk);
                start = 1;
                for (k = 0; k < n_ticks; k = k + 1)
                    @(posedge clk);
                @(negedge clk);
                if (pc[4:0] !== pc_i[4:0] || x !== x_i[15:0] || y !== y_i[15:0]
                    || isr !== isr_i[15:0] || osr !== osr_i[15:0]
                    || pin_out !== pins_i[7:0] || pin_oe !== oe_i[7:0]
                    || tx_pop !== exp_pop[0] || rx_push !== exp_push[0]) begin
                    $display("FAIL lockstep i=%0d instr=%04x got pc=%0x x=%0x y=%0x isr=%0x osr=%0x pins=%0x oe=%0x pop=%0d push=%0d",
                             i, instr, pc, x, y, isr, osr, pin_out, pin_oe, tx_pop, rx_push);
                    $display("         exp pc=%0x x=%0x y=%0x isr=%0x osr=%0x pins=%0x oe=%0x pop=%0d push=%0d",
                             pc_i, x_i, y_i, isr_i, osr_i, pins_i, oe_i, exp_pop, exp_push);
                    errors = errors + 1;
                    i = n;
                end
            end
        end
        $fclose(fd);
        if (errors) begin
            $display("FAIL lockstep");
            $finish(1);
        end
        $display("PASS lockstep cases=%0d", n);
        $finish(0);
    end
endmodule
