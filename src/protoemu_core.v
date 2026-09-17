`default_nettype none

`ifndef PROTOEMU_SM1
`define PROTOEMU_SM1 0
`endif

// One SM on the CMOS5L 6x4 die. SM1 is generate-off (PROTOEMU_SM1).
// 32 x 16 flop IMEM (Yosys generic >8k at 64). Capture is 32 x 24 flop
// {pin,oe,hold}, no SRAM macro.
module protoemu_core #(
    parameter SM1 = `PROTOEMU_SM1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  ui_in,
    output reg  [7:0]  uo_out,
    input  wire [7:0]  uio_in,
    output wire [7:0]  uio_out,
    output wire [7:0]  uio_oe
);
    localparam integer IMEM_WORDS = 32;
    localparam integer CAP_DEPTH  = 32;
    localparam integer WPTR_W     = 6;

    reg [15:0] imem [0:IMEM_WORDS-1];
    reg [4:0]  host_addr;
    reg [15:0] shifter;
    reg        strobe_q;
    reg        start0, start1;
    reg        cap_en, replay_en;
    reg [15:0] div0_int, div1_int;
    reg [7:0]  div0_frac, div1_frac;
    reg [3:0]  peek_sel;
    reg [WPTR_W-1:0] cap_wptr;
    reg        cap_mode;
    reg        last_sclk;
    reg [4:0]  dump_idx;
    reg [4:0]  replay_idx;
    reg [7:0]  hold_cnt;
    reg [23:0] dump_q;

    wire strobe = ui_in[7];
    wire strobe_rise = strobe & ~strobe_q;
    wire [2:0] cmd = ui_in[6:4];
    wire [3:0] nib = ui_in[3:0];
    wire [3:0] peek_now = (strobe_rise && cmd == 3'd7) ? nib : peek_sel;

    wire tick0, tick1;
    protoemu_clkdiv u_div0 (
        .clk(clk), .rst_n(rst_n), .run(start0),
        .div_int(div0_int), .div_frac(div0_frac), .tick(tick0)
    );

    wire [15:0] tx0_rdata, rx0_rdata;
    wire tx0_empty, tx0_full, rx0_empty, rx0_full;
    wire [2:0] tx0_lvl, rx0_lvl;
    wire tx0_pop, rx0_push;
    wire [15:0] rx0_wdata;
    reg  host_fifo0, host_fifo1;
    reg  host_rx0_pop;
    reg  [15:0] host_fifo_data;

    protoemu_fifo4 u_tx0 (
        .clk(clk), .rst_n(rst_n),
        .push(host_fifo0), .wdata(host_fifo_data), .pop(tx0_pop),
        .rdata(tx0_rdata), .empty(tx0_empty), .full(tx0_full), .level(tx0_lvl)
    );
    protoemu_fifo4 u_rx0 (
        .clk(clk), .rst_n(rst_n),
        .push(rx0_push), .wdata(rx0_wdata), .pop(host_rx0_pop),
        .rdata(rx0_rdata), .empty(rx0_empty), .full(rx0_full), .level(rx0_lvl)
    );

    wire [7:0] pc0, pc1, pout0, poe0, pout1, poe1;
    wire [15:0] x0, y0, isr0, osr0, x1, y1, isr1, osr1;
    wire [4:0] isr_cnt0, osr_cnt0;
    wire irq_set0, irq_clr0, irq_set1, irq_clr1;
    wire [2:0] irq_idx0, irq_idx1;
    reg  [7:0] irq_flags;

    wire [7:0] pin_resolved = (poe0 | poe1) & (pout1 | (pout0 & ~poe1))
                            | (~(poe0 | poe1) & uio_in);

    // 1W1R packed file. [23:16] pins, [15:8] oe, [7:0] inclusive hold.
    // Current record lives in flops; RAM write only on commit (new event or halt).
    reg [23:0] cap_mem [0:CAP_DEPTH-1];
    reg        cur_valid;
    reg [7:0]  cur_pins, cur_oe, cur_hold;
    reg        replay_first;
    wire [4:0] cap_raddr;
    wire cap_replay_strobe = strobe_rise && (cmd == 3'd5) && nib[3];
    wire cap_more = ({1'b0, replay_idx} + 1'b1 < cap_wptr);
    wire cap_adv = replay_en && cap_more
                 && ((replay_first && dump_q[7:0] <= 8'd1)
                     || (!replay_first && hold_cnt <= 8'd1));
    assign cap_raddr = (replay_en || cap_replay_strobe)
                     ? (cap_replay_strobe ? 5'd0
                        : (cap_adv ? (replay_idx + 5'd1) : replay_idx))
                     : dump_idx;
    wire cap_sclk_rise = !pin_resolved[3] && pin_resolved[1] && !last_sclk;
    wire cap_edge_evt = !cur_valid || (pin_resolved != cur_pins) || (uio_oe != cur_oe);
    wire cap_new_evt = cap_mode ? cap_sclk_rise : cap_edge_evt;
    wire cap_room = cap_wptr != CAP_DEPTH[WPTR_W-1:0];
    wire cap_halt_c = strobe_rise && (cmd == 3'd5) && !nib[2] && cap_en && cur_valid
                    && cap_room;
    wire cap_run_c = cap_en && !replay_en && !cap_halt_c && cur_valid && cap_new_evt
                   && cap_room;

    assign uio_out = replay_en ? dump_q[23:16]
                   : ((pout1 & poe1) | (pout0 & poe0 & ~poe1));
    assign uio_oe  = replay_en ? dump_q[15:8] : (poe0 | poe1);

    protoemu_sm u_sm0 (
        .clk(clk), .rst_n(rst_n), .start(start0), .tick(tick0),
        .instr(imem[pc0[4:0]]), .pc(pc0), .x(x0), .y(y0), .isr(isr0), .osr(osr0),
        .isr_cnt(isr_cnt0), .osr_cnt(osr_cnt0),
        .pin_out(pout0), .pin_oe(poe0), .pin_in(pin_resolved),
        .irq_in(irq_flags), .irq_set(irq_set0), .irq_clr(irq_clr0), .irq_idx(irq_idx0),
        .tx_data(tx0_rdata), .tx_empty(tx0_empty), .tx_pop(tx0_pop),
        .rx_data(rx0_wdata), .rx_push(rx0_push), .rx_full(rx0_full)
    );

    generate
        if (SM1) begin : g_sm1
            wire [15:0] tx1_rdata, rx1_rdata, rx1_wdata;
            wire tx1_empty, tx1_full, rx1_empty, rx1_full;
            wire [2:0] tx1_lvl, rx1_lvl;
            wire tx1_pop, rx1_push;
            wire [4:0] isr_cnt1, osr_cnt1;

            protoemu_clkdiv u_div1 (
                .clk(clk), .rst_n(rst_n), .run(start1),
                .div_int(div1_int), .div_frac(div1_frac), .tick(tick1)
            );
            protoemu_fifo4 u_tx1 (
                .clk(clk), .rst_n(rst_n),
                .push(host_fifo1), .wdata(host_fifo_data), .pop(tx1_pop),
                .rdata(tx1_rdata), .empty(tx1_empty), .full(tx1_full), .level(tx1_lvl)
            );
            protoemu_fifo4 u_rx1 (
                .clk(clk), .rst_n(rst_n),
                .push(rx1_push), .wdata(rx1_wdata), .pop(1'b0),
                .rdata(rx1_rdata), .empty(rx1_empty), .full(rx1_full), .level(rx1_lvl)
            );
            protoemu_sm u_sm1 (
                .clk(clk), .rst_n(rst_n), .start(start1), .tick(tick1),
                .instr(imem[pc1[4:0]]), .pc(pc1), .x(x1), .y(y1), .isr(isr1), .osr(osr1),
                .isr_cnt(isr_cnt1), .osr_cnt(osr_cnt1),
                .pin_out(pout1), .pin_oe(poe1), .pin_in(pin_resolved),
                .irq_in(irq_flags), .irq_set(irq_set1), .irq_clr(irq_clr1), .irq_idx(irq_idx1),
                .tx_data(tx1_rdata), .tx_empty(tx1_empty), .tx_pop(tx1_pop),
                .rx_data(rx1_wdata), .rx_push(rx1_push), .rx_full(rx1_full)
            );
        end else begin : g_no_sm1
            assign tick1 = 1'b0;
            assign pc1 = 8'd0;
            assign pout1 = 8'd0;
            assign poe1 = 8'd0;
            assign x1 = 16'd0;
            assign y1 = 16'd0;
            assign isr1 = 16'd0;
            assign osr1 = 16'd0;
            assign irq_set1 = 1'b0;
            assign irq_clr1 = 1'b0;
            assign irq_idx1 = 3'd0;
        end
    endgenerate

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            strobe_q <= 1'b0;
            shifter <= 16'd0;
            host_addr <= 5'd0;
            start0 <= 1'b0;
            start1 <= 1'b0;
            cap_en <= 1'b0;
            replay_en <= 1'b0;
            div0_int <= 16'd1;
            div1_int <= 16'd1;
            div0_frac <= 8'd0;
            div1_frac <= 8'd0;
            peek_sel <= 4'd0;
            host_fifo0 <= 1'b0;
            host_fifo1 <= 1'b0;
            host_rx0_pop <= 1'b0;
            host_fifo_data <= 16'd0;
            irq_flags <= 8'd0;
            cap_wptr <= {WPTR_W{1'b0}};
            cap_mode <= 1'b0;
            last_sclk <= 1'b0;
            dump_idx <= 5'd0;
            replay_idx <= 5'd0;
            hold_cnt <= 8'd0;
            dump_q <= 24'd0;
            cur_valid <= 1'b0;
            cur_pins <= 8'd0;
            cur_oe <= 8'd0;
            cur_hold <= 8'd0;
            replay_first <= 1'b0;
            uo_out <= 8'd0;
            for (i = 0; i < IMEM_WORDS; i = i + 1)
                imem[i] <= 16'd0;
        end else begin
            strobe_q <= strobe;
            host_fifo0 <= 1'b0;
            host_fifo1 <= 1'b0;
            host_rx0_pop <= 1'b0;
            if (irq_set0) irq_flags[irq_idx0] <= 1'b1;
            if (irq_clr0) irq_flags[irq_idx0] <= 1'b0;
            if (irq_set1) irq_flags[irq_idx1] <= 1'b1;
            if (irq_clr1) irq_flags[irq_idx1] <= 1'b0;

            if (strobe_rise) begin
                case (cmd)
                    3'd0: shifter <= {shifter[11:0], nib};
                    3'd1: begin
                        imem[host_addr] <= shifter;
                        host_addr <= host_addr + 5'd1;
                    end
                    3'd2: host_addr <= shifter[4:0];
                    3'd3: begin
                        host_fifo_data <= shifter;
                        host_fifo0 <= 1'b1;
                    end
                    3'd4: begin
                        host_fifo_data <= shifter;
                        host_fifo1 <= 1'b1;
                    end
                    3'd5: begin
                        start0    <= nib[0];
                        start1    <= nib[1];
                        cap_en    <= nib[2];
                        replay_en <= nib[3];
                        if (nib[2]) begin
                            cap_wptr <= {WPTR_W{1'b0}};
                            dump_idx <= 5'd0;
                            replay_idx <= 5'd0;
                            cur_valid <= 1'b0;
                        end
                        if (nib[3]) begin
                            replay_idx <= 5'd0;
                            replay_first <= 1'b1;
                            hold_cnt <= 8'd0;
                        end
                        if (!nib[2] && cap_en && cur_valid
                                && cap_wptr != CAP_DEPTH[WPTR_W-1:0]) begin
                            cap_wptr <= cap_wptr + 1'b1;
                            cur_valid <= 1'b0;
                        end
                    end
                    3'd6: begin
                        if (nib[0] == 1'b0) begin
                            div0_int <= shifter;
                            div0_frac <= {4'd0, nib[3:1], 1'b0};
                        end else begin
                            div1_int <= shifter;
                            div1_frac <= {4'd0, nib[3:1], 1'b0};
                        end
                    end
                    default: begin
                        peek_sel <= nib;
                        if (nib == 4'd10)
                            host_rx0_pop <= 1'b1;
                        if (nib == 4'd14 && !replay_en)
                            dump_idx <= dump_idx + 5'd1;
                        if (nib == 4'd15) begin
                            dump_idx <= 5'd0;
                            cap_mode <= shifter[0];
                        end
                    end
                endcase
            end

            dump_q <= cap_mem[cap_raddr];
            last_sclk <= pin_resolved[1];
            if (cap_halt_c || cap_run_c)
                cap_mem[cap_wptr[4:0]] <= {cur_pins, cur_oe, cur_hold};

            if (cap_en && !replay_en
                    && !(strobe_rise && cmd == 3'd5 && !nib[2])) begin
                if (cap_new_evt) begin
                    if (cur_valid && cap_room) begin
                        cap_wptr <= cap_wptr + 1'b1;
                        if (cap_wptr != 6'd31) begin
                            cur_pins <= pin_resolved;
                            cur_oe <= uio_oe;
                            cur_hold <= 8'd1;
                        end else
                            cur_valid <= 1'b0;
                    end else if (!cur_valid && cap_room) begin
                        cur_valid <= 1'b1;
                        cur_pins <= pin_resolved;
                        cur_oe <= uio_oe;
                        cur_hold <= 8'd1;
                    end
                end else if (cur_valid && cur_hold != 8'hFF)
                    cur_hold <= cur_hold + 8'd1;
            end

            if (replay_en && !cap_replay_strobe) begin
                if (replay_first) begin
                    if (dump_q[7:0] <= 8'd1) begin
                        if (cap_more)
                            replay_idx <= replay_idx + 5'd1;
                        else begin
                            replay_first <= 1'b0;
                            hold_cnt <= 8'd1;
                        end
                    end else begin
                        replay_first <= 1'b0;
                        hold_cnt <= dump_q[7:0] - 8'd1;
                    end
                end else if (hold_cnt > 8'd1)
                    hold_cnt <= hold_cnt - 8'd1;
                else if (cap_more) begin
                    replay_idx <= replay_idx + 5'd1;
                    replay_first <= 1'b1;
                end
            end

            case (peek_now)
                4'd0: uo_out <= {3'b000, pc0[4:0]};
                4'd1: uo_out <= x0[7:0];
                4'd2: uo_out <= y0[7:0];
                4'd3: uo_out <= isr0[7:0];
                4'd4: uo_out <= osr0[7:0];
                4'd5: uo_out <= {rx0_lvl, tx0_lvl[2:0], rx0_empty, tx0_empty};
                4'd6: uo_out <= {2'b00, cap_wptr};
                4'd7: uo_out <= pin_resolved;
                4'd8: uo_out <= pc1;
                4'd9: uo_out <= x1[7:0];
                4'd10: uo_out <= rx0_rdata[7:0];
                4'd11: uo_out <= dump_q[23:16];
                4'd12: uo_out <= dump_q[15:8];
                4'd13: uo_out <= dump_q[7:0];
                default: uo_out <= pin_resolved;
            endcase
        end
    end
endmodule
