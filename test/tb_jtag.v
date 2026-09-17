`default_nettype none
`timescale 1ns / 1ps

module tb_jtag;
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

    // fw/jtag_shift.py IDCODE TAP walk
    localparam [15:0] W00 = 16'hE06B;
    localparam [15:0] W01 = 16'hE0A1;
    localparam [15:0] W02 = 16'hE082;
    localparam [15:0] W03 = 16'hE024;
    localparam [15:0] W04 = 16'hE008;
    localparam [15:0] W05 = 16'hF008;
    localparam [15:0] W06 = 16'h0044;
    localparam [15:0] W07 = 16'hE000;
    localparam [15:0] W08 = 16'hF000;
    localparam [15:0] W09 = 16'hE008;
    localparam [15:0] W10 = 16'hF008;
    localparam [15:0] W11 = 16'hE000;
    localparam [15:0] W12 = 16'hF000;
    localparam [15:0] W13 = 16'hE000;
    localparam [15:0] W14 = 16'hF000;
    localparam [15:0] W15 = 16'hE02F;
    localparam [15:0] W16 = 16'hE000;
    localparam [15:0] W17 = 16'h5001;
    localparam [15:0] W18 = 16'h0050;
    localparam [15:0] W19 = 16'h8000;
    localparam [15:0] W20 = 16'hE02F;
    localparam [15:0] W21 = 16'hE000;
    localparam [15:0] W22 = 16'h5001;
    localparam [15:0] W23 = 16'h0055;
    localparam [15:0] W24 = 16'h8000;
    localparam [15:0] W25 = 16'h0019;

    localparam [31:0] IDCODE = 32'h1234ABCD;
    localparam [3:0] ST_TLR=0, ST_RTI=1, ST_SELDR=2, ST_CAPDR=3, ST_SHDR=4,
                     ST_EX1DR=5, ST_SELIR=6, ST_OTHER=7;

    integer errors;
    reg tck_q;
    reg tdo;
    reg [31:0] shifter;
    reg [3:0] state;
    wire tck = uio_oe[1] ? uio_out[1] : 1'b0;
    wire tdi = uio_oe[0] ? uio_out[0] : 1'b0;
    wire tms = uio_oe[3] ? uio_out[3] : 1'b0;

    always @* begin
        uio_in = 8'hFF;
        uio_in[2] = tdo;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tck_q <= 1'b0;
            tdo <= 1'b1;
            shifter <= IDCODE;
            state <= ST_TLR;
        end else begin
            if (!tck_q && tck) begin
                case (state)
                    ST_TLR:   state <= tms ? ST_TLR : ST_RTI;
                    ST_RTI:   state <= tms ? ST_SELDR : ST_RTI;
                    ST_SELDR: state <= tms ? ST_SELIR : ST_CAPDR;
                    ST_CAPDR: begin
                        shifter <= IDCODE;
                        state <= tms ? ST_EX1DR : ST_SHDR;
                    end
                    ST_SHDR: begin
                        shifter <= {tdi, shifter[31:1]};
                        state <= tms ? ST_EX1DR : ST_SHDR;
                    end
                    ST_SELIR: state <= tms ? ST_TLR : ST_OTHER;
                    default:  state <= tms ? ST_TLR : ST_RTI;
                endcase
            end
            if (tck_q && !tck) begin
                if (state == ST_SHDR)
                    tdo <= shifter[0];
                else
                    tdo <= 1'b1;
            end
            tck_q <= tck;
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
        imem_wr(W16); imem_wr(W17); imem_wr(W18); imem_wr(W19);
        imem_wr(W20); imem_wr(W21); imem_wr(W22); imem_wr(W23);
        imem_wr(W24); imem_wr(W25);

        start0;
        repeat (200) @(posedge clk);

        host(3'd7, 4'd10);
        if (uo_out !== 8'hD5) begin
            $display("FAIL JTAG IDCODE lo %h != D5", uo_out);
            errors = errors + 1;
        end
        host(3'd7, 4'd10);
        if (uo_out !== 8'h48) begin
            $display("FAIL JTAG IDCODE hi %h != 48", uo_out);
            errors = errors + 1;
        end
        if (!errors)
            $display("PASS JTAG IDCODE");

        if (errors) begin
            $display("JTAG TB FAILED");
            $finish(1);
        end
        $display("JTAG TB OK");
        $finish(0);
    end
endmodule
