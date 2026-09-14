`default_nettype none

// IHP foundry SRAM prior (sg13g2 silicon: urish ttihp-sram-test).
// CMOS5L metal stack is shorter; do not instantiate until one-macro P&R lands.
// Flop stand-in: protoemu_sram_flop.
(* blackbox *)
module RM_IHPSG13_1P_1024x8_c2_bm_bist (
    input  wire       A_CLK,
    input  wire       A_MEN,
    input  wire       A_WEN,
    input  wire       A_REN,
    input  wire [9:0] A_ADDR,
    input  wire [7:0] A_DIN,
    input  wire       A_DLY,
    output wire [7:0] A_DOUT,
    input  wire [7:0] A_BM,
    input  wire       A_BIST_CLK,
    input  wire       A_BIST_EN,
    input  wire       A_BIST_MEN,
    input  wire       A_BIST_WEN,
    input  wire       A_BIST_REN,
    input  wire [9:0] A_BIST_ADDR,
    input  wire [7:0] A_BIST_DIN,
    input  wire       A_BIST_DLY,
    input  wire [7:0] A_BIST_BM
);
endmodule
