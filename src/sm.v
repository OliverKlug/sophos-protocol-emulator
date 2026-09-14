`default_nettype none

// One protocol SM. Two identical instances in protoemu_core.
// SIDESET_COUNT=1: instr[12]=side, instr[11:8]=delay.
module protoemu_sm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        tick,
    input  wire [15:0] instr,
    output reg  [7:0]  pc,
    output reg  [15:0] x,
    output reg  [15:0] y,
    output reg  [15:0] isr,
    output reg  [15:0] osr,
    output reg  [4:0]  isr_cnt,
    output reg  [4:0]  osr_cnt,
    output reg  [7:0]  pin_out,
    output reg  [7:0]  pin_oe,
    input  wire [7:0]  pin_in,
    input  wire [7:0]  irq_in,
    output reg         irq_set,
    output reg         irq_clr,
    output reg  [2:0]  irq_idx,
    input  wire [15:0] tx_data,
    input  wire        tx_empty,
    output reg         tx_pop,
    output reg  [15:0] rx_data,
    output reg         rx_push,
    input  wire        rx_full
);
    wire [2:0] op    = instr[15:13];
    wire       side  = instr[12];
    wire [3:0] delay = instr[11:8];
    wire [7:0] pay   = instr[7:0];

    localparam OP_JMP = 3'd0, OP_WAIT = 3'd1, OP_IN = 3'd2, OP_OUT = 3'd3;
    localparam OP_PP  = 3'd4, OP_MOV  = 3'd5, OP_IRQ = 3'd6, OP_SET = 3'd7;

    reg [3:0] delay_cnt;
    reg       side_done;
    reg [2:0] in_base;
    reg [2:0] side_pin;

    wire [2:0] jmp_cond  = pay[7:5];
    wire [7:0] jmp_addr  = {3'b000, pay[4:0]};
    wire [2:0] wait_src  = {1'b0, pay[6:5]};
    wire       wait_pol  = pay[7];
    wire [4:0] wait_idx  = pay[4:0];
    wire [2:0] io_field  = pay[7:5];
    wire [4:0] io_count0 = pay[4:0];
    wire [4:0] io_count  = (io_count0 == 5'd0) ? 5'd16 : io_count0;
    wire       is_pull   = pay[7];
    wire       pp_iff    = pay[6];
    wire       pp_block  = pay[5];
    wire [1:0] mov_op    = pay[4:3];
    wire [2:0] mov_src   = pay[2:0];

    function [0:0] wait_bit;
        input [2:0] src;
        input [4:0] idx;
        begin
            case (src)
                3'd0: wait_bit = pin_in[idx[2:0]];
                3'd1: wait_bit = irq_in[idx[2:0]];
                default: wait_bit = pin_in[in_base];
            endcase
        end
    endfunction

    wire wait_met = (wait_bit(wait_src, wait_idx) == wait_pol);
    wire is_wait  = (op == OP_WAIT);
    wire irq_wait_op = (op == OP_IRQ) && pay[6] && !pay[7];
    wire stall_irq_wait = irq_wait_op && !irq_in[pay[2:0]];
    wire stall_wait = (is_wait && !wait_met) || stall_irq_wait;

    wire osre = (osr_cnt == 5'd0);
    wire pin_j = pin_in[in_base];

    function [0:0] jmp_taken;
        input [2:0] c;
        begin
            case (c)
                3'd0: jmp_taken = 1'b1;
                3'd1: jmp_taken = (x == 16'd0);
                3'd2: jmp_taken = (x != 16'd0);
                3'd3: jmp_taken = (y == 16'd0);
                3'd4: jmp_taken = (y != 16'd0);
                3'd5: jmp_taken = pin_j;
                3'd6: jmp_taken = osre;
                default: jmp_taken = (x != y);
            endcase
        end
    endfunction

    function [15:0] mov_read;
        input [2:0] s;
        begin
            case (s)
                3'd0: mov_read = {8'd0, pin_in};
                3'd1: mov_read = x;
                3'd2: mov_read = y;
                3'd3: mov_read = 16'd0;
                3'd4: mov_read = {13'd0, tx_empty, rx_full, osre};
                3'd5: mov_read = isr;
                3'd6: mov_read = osr;
                default: mov_read = {pin_oe, pin_out};
            endcase
        end
    endfunction

    function [15:0] apply_op;
        input [15:0] v;
        input [1:0] o;
        begin
            case (o)
                2'd1: apply_op = ~v;
                2'd2: apply_op = {v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],
                                  v[8],v[9],v[10],v[11],v[12],v[13],v[14],v[15]};
                default: apply_op = v;
            endcase
        end
    endfunction

    function [20:0] in_shift;
        input [15:0] old_isr;
        input [4:0]  old_cnt;
        input [7:0]  pins;
        input [2:0]  base;
        input [4:0]  n;
        integer k;
        reg [15:0] acc;
        reg [4:0]  cnt;
        begin
            acc = old_isr;
            cnt = old_cnt;
            for (k = 0; k < 16; k = k + 1) begin
                if (k < n) begin
                    acc = {acc[14:0], pins[(base + k[2:0]) & 3'd7]};
                    if (cnt != 5'd16) cnt = cnt + 5'd1;
                end
            end
            in_shift = {cnt, acc};
        end
    endfunction

    function [28:0] out_shift;
        input [7:0]  old_pins;
        input [15:0] old_osr;
        input [4:0]  old_cnt;
        input [4:0]  n;
        integer k;
        reg [7:0]  pins;
        reg [15:0] acc;
        reg [4:0]  cnt;
        begin
            pins = old_pins;
            acc = old_osr;
            cnt = old_cnt;
            for (k = 0; k < 16; k = k + 1) begin
                if (k < n) begin
                    pins[k[2:0]] = acc[0];
                    acc = {1'b0, acc[15:1]};
                    if (cnt != 5'd0) cnt = cnt - 5'd1;
                end
            end
            out_shift = {cnt, acc, pins};
        end
    endfunction

    wire [15:0] mov_val = apply_op(mov_read(mov_src), mov_op);
    wire [20:0] in_pins_next  = in_shift(isr, isr_cnt, pin_in, in_base, io_count);
    wire [28:0] out_pins_next = out_shift(pin_out, osr, osr_cnt, io_count);
    wire pull_ok  = is_pull  && (!pp_iff || osre) && (!tx_empty || !pp_block);
    wire pull_stall = is_pull && pp_block && tx_empty && (!pp_iff || osre);
    wire push_ok  = !is_pull && (!pp_iff || (isr_cnt != 5'd0)) && (!rx_full || !pp_block);
    wire push_stall = !is_pull && pp_block && rx_full && (!pp_iff || (isr_cnt != 5'd0));
    wire stall_pp = (op == OP_PP) && (pull_stall || push_stall);

    wire stall = stall_wait || stall_pp;
    wire do_exec = start && tick && (delay_cnt == 4'd0) && !stall;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 8'd0;
            x <= 16'd0;
            y <= 16'd0;
            isr <= 16'd0;
            osr <= 16'd0;
            isr_cnt <= 5'd0;
            osr_cnt <= 5'd0;
            pin_out <= 8'd0;
            pin_oe <= 8'd0;
            delay_cnt <= 4'd0;
            side_done <= 1'b0;
            in_base <= 3'd0;
            side_pin <= 3'd1;
            irq_set <= 1'b0;
            irq_clr <= 1'b0;
            irq_idx <= 3'd0;
            tx_pop <= 1'b0;
            rx_push <= 1'b0;
            rx_data <= 16'd0;
        end else begin
            irq_set <= 1'b0;
            irq_clr <= 1'b0;
            tx_pop <= 1'b0;
            rx_push <= 1'b0;
            if (!start) begin
                pc <= 8'd0;
                delay_cnt <= 4'd0;
                side_done <= 1'b0;
            end else if (tick) begin
                if (delay_cnt != 4'd0) begin
                    delay_cnt <= delay_cnt - 4'd1;
                end else begin
                    if (do_exec) begin
                        delay_cnt <= delay;
                        side_done <= 1'b0;
                        case (op)
                            OP_JMP: begin
                                if (jmp_cond == 3'd2) x <= (x == 16'd0) ? 16'd0 : (x - 16'd1);
                                if (jmp_cond == 3'd4) y <= (y == 16'd0) ? 16'd0 : (y - 16'd1);
                                if (jmp_taken(jmp_cond))
                                    pc <= jmp_addr;
                                else
                                    pc <= pc + 8'd1;
                            end
                            OP_WAIT: begin
                                pc <= pc + 8'd1;
                            end
                            OP_IN: begin
                                if (io_field == 3'd0 || io_field == 3'd7) begin
                                    isr_cnt <= in_pins_next[20:16];
                                    isr     <= in_pins_next[15:0];
                                end else begin
                                    case (io_field)
                                        3'd1: isr <= x;
                                        3'd2: isr <= y;
                                        3'd3: isr <= 16'd0;
                                        3'd4: isr <= isr;
                                        3'd5: isr <= osr;
                                        default: isr <= {13'd0, tx_empty, rx_full, osre};
                                    endcase
                                    isr_cnt <= io_count;
                                end
                                pc <= pc + 8'd1;
                            end
                            OP_OUT: begin
                                case (io_field)
                                    3'd0: begin
                                        osr_cnt <= out_pins_next[28:24];
                                        osr     <= out_pins_next[23:8];
                                        pin_out <= out_pins_next[7:0];
                                    end
                                    3'd1: x <= osr;
                                    3'd2: y <= osr;
                                    3'd3: pin_oe <= osr[7:0];
                                    3'd4: begin
                                        pin_out <= osr[7:0];
                                        pin_oe  <= osr[15:8];
                                        osr_cnt <= 5'd0;
                                    end
                                    3'd5: pc <= osr[7:0];
                                    3'd6: isr <= osr;
                                    default: ;
                                endcase
                                if (io_field != 3'd5)
                                    pc <= pc + 8'd1;
                            end
                            OP_PP: begin
                                if (is_pull && pull_ok) begin
                                    osr <= tx_data;
                                    osr_cnt <= 5'd16;
                                    tx_pop <= 1'b1;
                                end else if (!is_pull && push_ok) begin
                                    rx_data <= isr;
                                    rx_push <= 1'b1;
                                    isr <= 16'd0;
                                    isr_cnt <= 5'd0;
                                end
                                pc <= pc + 8'd1;
                            end
                            OP_MOV: begin
                                case (io_field)
                                    3'd0: pin_out <= mov_val[7:0];
                                    3'd1: x <= mov_val;
                                    3'd2: y <= mov_val;
                                    3'd3: pin_oe <= mov_val[7:0];
                                    3'd4: begin
                                        pin_out <= mov_val[7:0];
                                        pin_oe  <= mov_val[15:8];
                                    end
                                    3'd5: pc <= mov_val[7:0];
                                    3'd6: isr <= mov_val;
                                    default: ;
                                endcase
                                if (mov_src == 3'd6 && io_field != 3'd6)
                                    osr_cnt <= 5'd0;
                                if (io_field != 3'd5)
                                    pc <= pc + 8'd1;
                            end
                            OP_IRQ: begin
                                irq_idx <= pay[2:0];
                                if (pay[7]) irq_clr <= 1'b1;
                                else irq_set <= 1'b1;
                                pc <= pc + 8'd1;
                            end
                            default: begin // SET
                                case (io_field)
                                    3'd0: begin
                                        for (i = 0; i < 5; i = i + 1)
                                            pin_out[i] <= pay[i];
                                    end
                                    3'd1: x <= {11'd0, pay[4:0]};
                                    3'd2: y <= {11'd0, pay[4:0]};
                                    3'd3: begin
                                        for (i = 0; i < 5; i = i + 1)
                                            pin_oe[i] <= pay[i];
                                    end
                                    3'd4: in_base <= pay[2:0];
                                    3'd5: side_pin <= pay[2:0];
                                    default: ;
                                endcase
                                pc <= pc + 8'd1;
                            end
                        endcase
                    end else if (!side_done) begin
                        side_done <= 1'b1;
                    end
                    if (!side_done)
                        pin_out[side_pin] <= side;
                end
            end
        end
    end
endmodule
