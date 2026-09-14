# P&R handoff (Phase 2 / Phase 5)

LibreLane and the IHP PDK are not on this machine. Yosys generic synth (`sim/synth.ys`) is the hello-world cell count, not a routed 6×4 and not STA. The silicon gate is the GitHub `gds` job on `@ihp-cmos5l`.

## Die

CMOS5L `tile_sizes.yaml` (cited in `docs/citations/`):

```
6x4: "0 0 1289.28 710.64"
```

`src/user_config.json` sets that DIE_AREA, `FP_DEF_TEMPLATE` `tt_block_6x4_pgvdd.def`, `RT_MAX_LAYER: Metal4`. `src/config.json` PDN is Gremlin CMOS5L prior: `FP_PDN_VPITCH` 50.0, `FP_PDN_VWIDTH` 2.1. `CLOCK_PERIOD` 20 ns.

`src/user_config.8x4.json` is archive only. Do not harden it.

## What is on the die

One SM (`PROTOEMU_SM1=0`). 32×16 flop IMEM (64 was >8k generic Yosys). Capture 16 records, flop shadows only. No `RM_IHPSG13_1P_1024x8_c2_bm_bist`: CMOS5L `sg13cmos5l_sram` is a symlink to sg13g2 macros that use TopMetal2.

`src/sram_flop.v` stays in the tree and is not in the harden file list. `src/sram_ihp_blackbox.v` is unused.

## Area

`yosys -s sim/synth.ys` (2026-09-15): **7830** generic cells, no `sram_flop` in the hierarchy. Not STA.

Cut order if GPL dies: IMEM 32, then capture 8, then stop. Hold: density 60→80. Do not switch back to sg13g2.

## Claimed board rates (not TinyQV 64 MHz)

Close STA at 50 MHz. Claim UART to a few Mbaud, SPI master a few MHz, I2C 100/400 kHz. USB LS only if the pad is clean at 12 MHz. Board UART stays pad-limited.

## GLS

RTL: `test/tb_uart.v` (Icarus, PASS UART TX 0x55). Gate-level: `test/Makefile` GATES=yes must compile `sg13cmos5l_udp.v`. Vector is UART 0x55 via `test/test.py`, not idle `uo_out[0]==0`.
