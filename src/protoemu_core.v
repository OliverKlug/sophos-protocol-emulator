`default_nettype none

// Two identical SMs, flop IMEM (dual read), one 1024x8 flop SRAM split for capture.
module protoemu_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  ui_in,
    output reg  [7:0]  uo_out,
    input  wire [7:0]  uio_in,
    output wire [7:0]  uio_out,
    output wire [7:0]  uio_oe
);
    reg [15:0] imem [0:255];
    reg [7:0]  host_addr;
    reg [15:0] shifter;
    reg        strobe_q;
    reg        start0, start1;
    reg        cap_en, replay_en;
    reg [15:0] div0_int, div1_int;
    reg [7:0]  div0_frac, div1_frac;
    reg [3:0]  peek_sel;
    reg [6:0]  cap_wptr;
    reg [6:0]  cap_rptr;
    reg [7:0]  last_pins;
    reg [7:0]  last_oe;
    reg [7:0]  delta_cnt;

    wire strobe = ui_in[7];
    wire strobe_rise = strobe & ~strobe_q;
    wire [2:0] cmd = ui_in[6:4];
    wire [3:0] nib = ui_in[3:0];

    wire tick0, tick1;
    protoemu_clkdiv u_div0 (
        .clk(clk), .rst_n(rst_n), .run(start0),
        .div_int(div0_int), .div_frac(div0_frac), .tick(tick0)
    );
    protoemu_clkdiv u_div1 (
        .clk(clk), .rst_n(rst_n), .run(start1),
        .div_int(div1_int), .div_frac(div1_frac), .tick(tick1)
    );

    wire [15:0] tx0_rdata, tx1_rdata, rx0_rdata, rx1_rdata;
    wire tx0_empty, tx1_empty, tx0_full, tx1_full;
    wire rx0_empty, rx1_empty, rx0_full, rx1_full;
    wire [2:0] tx0_lvl, tx1_lvl, rx0_lvl, rx1_lvl;
    wire tx0_pop, tx1_pop, rx0_push, rx1_push;
    wire [15:0] rx0_wdata, rx1_wdata;
    reg  host_fifo0, host_fifo1;
    reg  [15:0] host_fifo_data;

    protoemu_fifo4 u_tx0 (
        .clk(clk), .rst_n(rst_n),
        .push(host_fifo0), .wdata(host_fifo_data), .pop(tx0_pop),
        .rdata(tx0_rdata), .empty(tx0_empty), .full(tx0_full), .level(tx0_lvl)
    );
    protoemu_fifo4 u_tx1 (
        .clk(clk), .rst_n(rst_n),
        .push(host_fifo1), .wdata(host_fifo_data), .pop(tx1_pop),
        .rdata(tx1_rdata), .empty(tx1_empty), .full(tx1_full), .level(tx1_lvl)
    );
    protoemu_fifo4 u_rx0 (
        .clk(clk), .rst_n(rst_n),
        .push(rx0_push), .wdata(rx0_wdata), .pop(1'b0),
        .rdata(rx0_rdata), .empty(rx0_empty), .full(rx0_full), .level(rx0_lvl)
    );
    protoemu_fifo4 u_rx1 (
        .clk(clk), .rst_n(rst_n),
        .push(rx1_push), .wdata(rx1_wdata), .pop(1'b0),
        .rdata(rx1_rdata), .empty(rx1_empty), .full(rx1_full), .level(rx1_lvl)
    );

    wire [7:0] pc0, pc1, pout0, poe0, pout1, poe1;
    wire [15:0] x0, y0, isr0, osr0, x1, y1, isr1, osr1;
    wire [4:0] isr_cnt0, osr_cnt0, isr_cnt1, osr_cnt1;
    wire irq_set0, irq_clr0, irq_set1, irq_clr1;
    wire [2:0] irq_idx0, irq_idx1;
    reg  [7:0] irq_flags;

    wire [7:0] pin_resolved = (poe0 | poe1) & (pout1 | (pout0 & ~poe1))
                            | (~(poe0 | poe1) & uio_in);

    // SM1 wins pin conflicts (identical ISA, higher instance).
    reg [7:0] cap_pin_mem [0:127];
    reg [7:0] cap_oe_mem [0:127];
    reg [6:0] replay_idx;
    reg [7:0] replay_hold_pins;
    reg [7:0] replay_hold_oe;

    assign uio_out = replay_en ? replay_hold_pins
                   : ((pout1 & poe1) | (pout0 & poe0 & ~poe1));
    assign uio_oe  = replay_en ? replay_hold_oe : (poe0 | poe1);

    protoemu_sm u_sm0 (
        .clk(clk), .rst_n(rst_n), .start(start0), .tick(tick0),
        .instr(imem[pc0]), .pc(pc0), .x(x0), .y(y0), .isr(isr0), .osr(osr0),
        .isr_cnt(isr_cnt0), .osr_cnt(osr_cnt0),
        .pin_out(pout0), .pin_oe(poe0), .pin_in(pin_resolved),
        .irq_in(irq_flags), .irq_set(irq_set0), .irq_clr(irq_clr0), .irq_idx(irq_idx0),
        .tx_data(tx0_rdata), .tx_empty(tx0_empty), .tx_pop(tx0_pop),
        .rx_data(rx0_wdata), .rx_push(rx0_push), .rx_full(rx0_full)
    );
    protoemu_sm u_sm1 (
        .clk(clk), .rst_n(rst_n), .start(start1), .tick(tick1),
        .instr(imem[pc1]), .pc(pc1), .x(x1), .y(y1), .isr(isr1), .osr(osr1),
        .isr_cnt(isr_cnt1), .osr_cnt(osr_cnt1),
        .pin_out(pout1), .pin_oe(poe1), .pin_in(pin_resolved),
        .irq_in(irq_flags), .irq_set(irq_set1), .irq_clr(irq_clr1), .irq_idx(irq_idx1),
        .tx_data(tx1_rdata), .tx_empty(tx1_empty), .tx_pop(tx1_pop),
        .rx_data(rx1_wdata), .rx_push(rx1_push), .rx_full(rx1_full)
    );

    wire        sram_we;
    wire [9:0]  sram_addr;
    wire [7:0]  sram_wdata;
    wire [7:0]  sram_rdata;
    protoemu_sram_flop u_sram (
        .clk(clk), .rst_n(rst_n), .we(sram_we),
        .addr(sram_addr), .wdata(sram_wdata), .rdata(sram_rdata)
    );

    // Capture: 128 x 4-byte records at SRAM[512..].
    // record: {delta, pins, oe, {tick1,tick0,start1,start0,0}}
    reg        cap_wr;
    reg [9:0]  cap_addr;
    reg [7:0]  cap_wdata;
    reg [1:0]  cap_phase;
    reg        replay_go;
    reg [1:0]  replay_phase;
    reg [7:0]  replay_pins;
    reg [7:0]  replay_oe;

    assign sram_we    = cap_wr;
    assign sram_addr  = cap_addr;
    assign sram_wdata = cap_wdata;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            strobe_q <= 1'b0;
            shifter <= 16'd0;
            host_addr <= 8'd0;
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
            host_fifo_data <= 16'd0;
            irq_flags <= 8'd0;
            cap_wptr <= 7'd0;
            cap_rptr <= 7'd0;
            last_pins <= 8'd0;
            last_oe <= 8'd0;
            delta_cnt <= 8'd0;
            cap_wr <= 1'b0;
            cap_addr <= 10'd0;
            cap_wdata <= 8'd0;
            cap_phase <= 2'd0;
            replay_go <= 1'b0;
            replay_phase <= 2'd0;
            replay_pins <= 8'd0;
            replay_oe <= 8'd0;
            replay_idx <= 7'd0;
            replay_hold_pins <= 8'd0;
            replay_hold_oe <= 8'd0;
            uo_out <= 8'd0;
            for (i = 0; i < 256; i = i + 1)
                imem[i] <= 16'd0;
            for (i = 0; i < 128; i = i + 1) begin
                cap_pin_mem[i] <= 8'd0;
                cap_oe_mem[i] <= 8'd0;
            end
        end else begin
            strobe_q <= strobe;
            host_fifo0 <= 1'b0;
            host_fifo1 <= 1'b0;
            cap_wr <= 1'b0;
            if (irq_set0) irq_flags[irq_idx0] <= 1'b1;
            if (irq_clr0) irq_flags[irq_idx0] <= 1'b0;
            if (irq_set1) irq_flags[irq_idx1] <= 1'b1;
            if (irq_clr1) irq_flags[irq_idx1] <= 1'b0;

            if (strobe_rise) begin
                case (cmd)
                    3'd0: shifter <= {shifter[11:0], nib};
                    3'd1: begin
                        imem[host_addr] <= shifter;
                        host_addr <= host_addr + 8'd1;
                    end
                    3'd2: host_addr <= shifter[7:0];
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
                            cap_wptr <= 7'd0;
                            delta_cnt <= 8'd0;
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
                    default: peek_sel <= nib;
                endcase
            end

            // Capture on pin change or delta saturate, 4-beat write into SRAM[512+].
            if (cap_en && cap_wptr != 7'd127 && cap_phase == 2'd0 && !replay_en) begin
                if ((pin_resolved != last_pins) || (uio_oe != last_oe) || (delta_cnt == 8'hFF)) begin
                    cap_phase <= 2'd1;
                    cap_wr <= 1'b1;
                    cap_addr <= 10'd512 + {cap_wptr, 2'b00};
                    cap_wdata <= delta_cnt;
                    last_pins <= pin_resolved;
                    last_oe <= uio_oe;
                    delta_cnt <= 8'd0;
                end else begin
                    delta_cnt <= delta_cnt + 8'd1;
                end
            end else if (cap_phase == 2'd1) begin
                cap_wr <= 1'b1;
                cap_addr <= 10'd512 + {cap_wptr, 2'b00} + 10'd1;
                cap_wdata <= last_pins;
                cap_phase <= 2'd2;
            end else if (cap_phase == 2'd2) begin
                cap_wr <= 1'b1;
                cap_addr <= 10'd512 + {cap_wptr, 2'b00} + 10'd2;
                cap_wdata <= last_oe;
                cap_phase <= 2'd3;
            end else if (cap_phase == 2'd3) begin
                cap_wr <= 1'b1;
                cap_addr <= 10'd512 + {cap_wptr, 2'b00} + 10'd3;
                cap_wdata <= {tick1, tick0, start1, start0, 4'd0};
                cap_phase <= 2'd0;
                cap_pin_mem[cap_wptr] <= last_pins;
                cap_oe_mem[cap_wptr] <= last_oe;
                cap_wptr <= cap_wptr + 7'd1;
            end

            if (replay_en) begin
                replay_hold_pins <= cap_pin_mem[replay_idx];
                replay_hold_oe <= cap_oe_mem[replay_idx];
                if (replay_idx + 7'd1 < cap_wptr)
                    replay_idx <= replay_idx + 7'd1;
            end else
                replay_idx <= 7'd0;

            case (peek_sel)
                4'd0: uo_out <= pc0;
                4'd1: uo_out <= x0[7:0];
                4'd2: uo_out <= y0[7:0];
                4'd3: uo_out <= isr0[7:0];
                4'd4: uo_out <= osr0[7:0];
                4'd5: uo_out <= {rx0_lvl, tx0_lvl[2:0], rx0_empty, tx0_empty};
                4'd6: uo_out <= {1'b0, cap_wptr};
                4'd7: uo_out <= pin_resolved;
                4'd8: uo_out <= pc1;
                4'd9: uo_out <= x1[7:0];
                4'd10: uo_out <= rx0_rdata[7:0];
                4'd11: uo_out <= rx1_rdata[7:0];
                default: uo_out <= pin_resolved;
            endcase
        end
    end
endmodule
