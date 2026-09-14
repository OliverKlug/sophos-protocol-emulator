# P&R handoff (Phase 2 / Phase 5)

LibreLane and the IHP PDK are not on this machine. Yosys 0.69 generic synth (`sim/synth.ys`) is the hello-world cell count, not a routed 8x4 and not STA. The October gate is still a LibreLane run when the PDK is on disk. Do not treat the ABC count as a GDS.

## Die

From `tt-support-tools` `tech/ihp-sg13g2/tile_sizes.yaml` (read 2026-09-14):

```
8x4: "0 0 1724.16 710.64"
```

`src/user_config.json` sets `DIE_AREA` to the **sg13g2** 8x4 string, `CLOCK_PERIOD` 20 ns. CMOS5L `tile_sizes.yaml` has no 8x4 and no matching DEF (`docs/citations/`, email sent). Do not run LibreLane against this DIE_AREA and call it CMOS5L.

## What to run (when the PDK is on disk)

```
export PDK=ihp-sg13g2   # or ihp-sg13cmos5l once TT ships it
./tt/tt_tool.py --create-user-config --ihp
# LibreLane harden, STA 20 ns
```

SRAM: flop stand-in `protoemu_sram_flop` (1024x8). Blackbox `RM_IHPSG13_1P_1024x8_c2_bm_bist` is in `src/sram_ihp_blackbox.v`. Do not instantiate a second macro. CMOS5L PDN/CTS hold is the known killer.

## Area (Yosys 0.69 generic, 2026-09-14)

`yosys -s sim/synth.ys`. Memories exploded to flops (`imem`, `cap_*_mem`, `sram_flop`). No IHP liberty, no CTS, no 20 ns proof.

| Object | Generic cells | Notes |
|---|---|---|
| `tt_um_klug_protoemu` hierarchy | 36902 | includes flop SRAM |
| `protoemu_sram_flop` | 28997 (8192 DFFE) | stand-in; IHP macro deletes this |
| `protoemu_sm` (one instance) | 2134 | two copies in the core |
| `protoemu_clkdiv` | 351 | per SM |
| `protoemu_fifo4` | 255 | four of them |

Cut order if GPL dies: drop SM1, then capture depth, then IMEM depth. Never cut WAIT / OE / side-set / clkdiv. The flop SRAM is the cell bomb; instantiating `RM_IHPSG13_1P_1024x8_c2_bm_bist` is the first real area cut, not a second macro.

## Claimed board rates (not TinyQV 64 MHz)

Close STA at 50 MHz. Claim UART to a few Mbaud, SPI master a few MHz, I2C 100/400 kHz. USB LS only if the pad is clean at 12 MHz.

## GLS

`test/tb_uart.v` is the RTL check (Icarus 13.0, PASS UART TX 0x55). Gate-level netlist is the LibreLane `nl/*.nl.v` once hardened. No PDK here, so no GLS run.
