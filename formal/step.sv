`default_nettype none

// Opcode-step relations that can fail. Immediate asserts: Yosys 0.69
// rejects concurrent `assert property (@(...))`.
module step_check (
    input wire        clk,
    input wire        rst_n,
    input wire        start,
    input wire        tick,
    input wire [15:0] instr,
    input wire [7:0]  pin_in,
    input wire [7:0]  irq_in,
    input wire [15:0] tx_data,
    input wire        tx_empty,
    input wire        rx_full
);
    wire [7:0]  pc;
    wire [15:0] x, y, isr, osr;
    wire [4:0]  isr_cnt, osr_cnt;
    wire [7:0]  pin_out, pin_oe;
    wire        irq_set, irq_clr;
    wire [2:0]  irq_idx;
    wire        tx_pop, rx_push;
    wire [15:0] rx_data;
    wire [3:0]  delay_cnt;
    wire        side_done;
    wire [2:0]  side_pin;
    wire [2:0]  in_base;

    protoemu_sm u_sm (
        .clk(clk), .rst_n(rst_n), .start(start), .tick(tick),
        .instr(instr), .pc(pc), .x(x), .y(y), .isr(isr), .osr(osr),
        .isr_cnt(isr_cnt), .osr_cnt(osr_cnt),
        .pin_out(pin_out), .pin_oe(pin_oe), .pin_in(pin_in),
        .irq_in(irq_in), .irq_set(irq_set), .irq_clr(irq_clr), .irq_idx(irq_idx),
        .tx_data(tx_data), .tx_empty(tx_empty), .tx_pop(tx_pop),
        .rx_data(rx_data), .rx_push(rx_push), .rx_full(rx_full),
        .delay_cnt(delay_cnt), .side_done(side_done),
        .side_pin(side_pin), .in_base(in_base)
    );

    wire [2:0] op    = instr[15:13];
    wire       side  = instr[12];
    wire [7:0] pay   = instr[7:0];
    wire [2:0] jmp_cond = pay[7:5];
    wire [4:0] jmp_tgt  = pay[4:0];
    wire       wait_pol = pay[7];
    wire [1:0] wait_src = pay[6:5];
    wire [4:0] wait_idx = pay[4:0];
    wire       is_pull  = pay[7];
    wire       pp_iff   = pay[6];
    wire       pp_block = pay[5];
    wire       osre     = (osr_cnt == 5'd0);

    wire wait_bit = (wait_src == 2'd0) ? pin_in[wait_idx[2:0]]
                  : (wait_src == 2'd1) ? irq_in[wait_idx[2:0]]
                  : pin_in[in_base];
    wire wait_met = (wait_bit == wait_pol);
    wire stall_wait = ((op == 3'd1) && !wait_met)
                   || ((op == 3'd6) && pay[6] && !pay[7] && !irq_in[pay[2:0]]);
    wire pull_stall = (op == 3'd4) && is_pull && pp_block && tx_empty && (!pp_iff || osre);
    wire push_stall = (op == 3'd4) && !is_pull && pp_block && rx_full && (!pp_iff || (isr_cnt != 5'd0));
    wire stall_pp = pull_stall || push_stall;

    wire pin_j = pin_in[in_base];
    wire jmp_taken = (jmp_cond == 3'd0) ? 1'b1
                   : (jmp_cond == 3'd1) ? (x == 16'd0)
                   : (jmp_cond == 3'd2) ? (x != 16'd0)
                   : (jmp_cond == 3'd3) ? (y == 16'd0)
                   : (jmp_cond == 3'd4) ? (y != 16'd0)
                   : (jmp_cond == 3'd5) ? pin_j
                   : (jmp_cond == 3'd6) ? osre
                   : (x != y);

    reg        seen;
    reg        p_start, p_tick, p_stall_w, p_stall_pp, p_jmp, p_side_fire;
    reg [3:0]  p_delay;
    reg [7:0]  p_pc;
    reg [4:0]  p_jmp_tgt;
    reg [2:0]  p_side_pin;
    reg        p_side;

    always @* assume (tick == 1'b1);
    initial assume (!rst_n);

    reg [1:0] live;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            live <= 2'b00;
            seen <= 1'b0;
            p_start <= 1'b0;
            p_tick <= 1'b0;
            p_stall_w <= 1'b0;
            p_stall_pp <= 1'b0;
            p_jmp <= 1'b0;
            p_side_fire <= 1'b0;
            p_delay <= 4'd0;
            p_pc <= 8'd0;
            p_jmp_tgt <= 5'd0;
            p_side_pin <= 3'd0;
            p_side <= 1'b0;
        end else begin
            live <= {live[0], 1'b1};
            seen <= 1'b1;
            p_start <= start;
            p_tick <= tick;
            p_stall_w <= stall_wait;
            p_stall_pp <= stall_pp;
            p_jmp <= (op == 3'd0) && jmp_taken;
            p_side_fire <= !side_done;
            p_delay <= delay_cnt;
            p_pc <= pc;
            p_jmp_tgt <= jmp_tgt;
            p_side_pin <= side_pin;
            p_side <= side;
        end
    end

    // posedge-only: SBY async2sync rejects asserts on async-reset always.
    always @(posedge clk) begin
        if (rst_n && seen && (live == 2'b11)) begin
            if (!p_start) begin
                assert (pc == 8'd0);
                assert (delay_cnt == 4'd0);
                assert (side_done == 1'b0);
            end
            if (p_start && p_tick && (p_delay != 4'd0)) begin
                assert (delay_cnt == (p_delay - 4'd1));
                assert (pc == p_pc);
                assert (!tx_pop);
                assert (!rx_push);
            end
            if (p_start && p_tick && (p_delay == 4'd0) && p_stall_w)
                assert (pc == p_pc);
            if (p_start && p_tick && (p_delay == 4'd0) && p_stall_pp) begin
                assert (pc == p_pc);
                assert (!tx_pop);
                assert (!rx_push);
            end
            if (p_start && p_tick && (p_delay == 4'd0) && !p_stall_w && !p_stall_pp && p_jmp)
                assert (pc[4:0] == p_jmp_tgt);
            if (p_start && p_tick && (p_delay == 4'd0) && p_side_fire)
                assert (pin_out[p_side_pin] == p_side);
        end
    end
endmodule
