# Phase 0 constraint sheet

Cited 2026-09-14, CMOS5L tools re-read 2026-09-15. Do not budget from the Jane Street blog's "~1 mm2" line.

## PDK / shuttle

- Contest: IHP 130 nm CMOS5L via Tiny Tapeout, `tiles: 8x4`, deadline 2027-01-18. Source: https://blog.janestreet.com/protocol-emulator-asic-competition/
- Template cloned: https://github.com/TinyTapeout/ttihp-verilog-template.git (Apache-2.0)
- Template `info.yaml` comment: valid tiles `1x1, 1x2, 2x2, 3x2, 4x2, 6x2 or 8x2`. **8x4 is not listed.**
- Harden flow Jane Street named (`tt-gds-action@ihp-cmos5l` → `tt-support-tools` branch `ihp-sg13cmos5l`): local clone 2026-09-15. `tech/ihp-sg13cmos5l/tile_sizes.yaml` has **no `8x4` key**. `def/` has no `tt_block_8x4_pgvdd.def`. Height-4 DEFs stop at `6x4`. 8-wide floorplan is `8x2` (`0 0 1724.16 313.74`). Copies: `docs/citations/`.
- `ihp-sg13g2` on `main` **does** list 8x4: `0 0 1724.16 710.64` (µm). That is the other PDK. Do not treat it as a CMOS5L DEF.
- 1x1 on both yamls is `202.08 x 154.98`, not the template comment `~167x108`.
- IHP CMOS5L repo: https://github.com/IHP-GmbH/ihp-sg13cmos5l
- TTIHP0p4 was a 2026-03-28 CMOS5L test shuttle, no chips. IHP foundry CMOS5L tape-in 2027-03-30 is not a Tiny Tapeout shuttle. No open March 2027 TT CMOS5L row on tinytapeout.com/chips as of this sheet.

**Action:** email sent (`docs/EMAIL_8x4.md`). Live harden is `tiles: "6x4"` / DIE_AREA `0 0 1289.28 710.64`. Reopen 8×4 only if Jane Street ships a CMOS5L DEF.

## Pins (do not scale with tiles)

`ui_in[7:0]`, `uo_out[7:0]`, `uio_in/out/oe[7:0]`, `clk`, `rst_n`, `ena`. Analog off.

This chip: host nibble on `ui_in`, protocol pins on `uio`, peek/debug on `uo_out`. See `docs/HOST.md`.

## Clock

LibreLane template `CLOCK_PERIOD: 20` (50 MHz STA). Claim board rates the pad will do. TinyQV 64 MHz is not an IHP prior. **STA has not been run.**

## SRAM

Prior: `RM_IHPSG13_1P_1024x8_c2_bm_bist` on sg13g2 (urish ttihp-sram-test). CMOS5L metal stack is shorter. Stand-in is a flop 1024x8 plus dual-read flop IMEM. One macro. No second macro until that die routes.

## HDL path (week-1 gate)

Named fallback (week-1 kill): Verilog SM + OCaml golden + SymbiYosys. This machine now has OCaml 5.3.0 / dune 3.24 / sby 0.69 / z3 5.1. Hardcaml was not used for the SM and will not replace it. Icarus 13.0 is the RTL sim. Yosys 0.69 generic synth is the hello-world cell count (`sim/synth.ys`). No IHP PDK / LibreLane here.
