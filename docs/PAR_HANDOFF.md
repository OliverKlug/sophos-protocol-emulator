# P&R handoff (Phase 2 / Phase 5)

LibreLane and the IHP PDK are not on this machine. Yosys generic synth (`sim/synth.ys`) is the hello-world cell count, not a routed 6×4 and not STA. The silicon gate is the GitHub `gds` job on `@ihp-cmos5l`.

## Die

CMOS5L `tile_sizes.yaml` (cited in `docs/citations/`):

```
6x4: "0 0 1289.28 710.64"
```

`src/user_config.json` sets that DIE_AREA, `FP_DEF_TEMPLATE` `tt_block_6x4_pgvdd.def`, `RT_MAX_LAYER: Metal4`. `src/config.json` PDN is Gremlin CMOS5L prior: `FP_PDN_VPITCH` 50.0, `FP_PDN_VWIDTH` 2.1. `CLOCK_PERIOD` 25 ns (20 ns missed slow setup by 3.89 ns).

`src/user_config.8x4.json` is archive only. Do not harden it.

## What is on the die

One SM (`PROTOEMU_SM1=0`). 32×16 flop IMEM (64 was >8k generic Yosys). Capture 32 live records `{pin,oe,hold}` (flop shadows; halt commits the current slot). No `RM_IHPSG13_1P_1024x8_c2_bm_bist`: CMOS5L `sg13cmos5l_sram` is a symlink to sg13g2 macros that use TopMetal2.

`src/sram_flop.v` stays in the tree and is not in the harden file list. `src/sram_ihp_blackbox.v` is unused.

## Area

`yosys -s sim/synth.ys` (2026-09-17): **9994** generic cells after 32×24 capture, no `sram_flop` in the hierarchy. Prior 15-slot die was 7830. Not STA.

Cut order if GPL dies: IMEM 32, then capture 8, then stop. Hold: density 60→80. Do not switch back to sg13g2.

## Claimed board rates (not TinyQV 64 MHz)

Close STA at 40 MHz (25 ns). Claim UART to a few Mbaud, SPI master a few MHz, I2C 100/400 kHz. USB LS is 1.5 Mbps, not 12 MHz FS. INT=27 FRAC=0 is −1.23%, inside LS function `TLDRATE` ±1.5% (USB 2.0 §7.1.11), outside hub/host `TLDRATHS` ±0.05%. Do not claim a hub clock or 500 ppm. Board UART stays pad-limited. Do not claim 50 MHz: that constraint failed slow-corner setup.

## GLS

RTL: `test/tb_uart.v` (Icarus, PASS UART TX 0x55). USB LS: `test/tb_usb.v` (Icarus, PASS USB LS). Capture: `tb_cap.v` / `tb_jedec_cap.v`. Gate-level: GHA `gl_test` on `8e4ef83` ran UART-only `test.test_uart_0x55`. This RTL adds capture dump to that same test (`TESTS=1`). SPI/I2C/USB/JEDEC stay Icarus RTL, not `test.py`. New GDS not signed off.

## STA (signoff, not generic Yosys)

From run 35023276762 `GDS_logs` (SHA `8e4ef83`, 15-slot capture): `create_clock -period 25.0000`. Overall / slow setup WS +0.50 ns, hold WS +0.11 ns. Post-P&R stdcells 8284, util 15.5%. Generic `sim/synth.ys` is now 9994 for 32-slot capture. That is not STA. New GDS not signed off.
