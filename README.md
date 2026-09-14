# ProtoEmu

Reprogrammable pin machine for the [Jane Street Tiny Tapeout contest](https://blog.janestreet.com/protocol-emulator-asic-competition/) (deadline 2027-01-18). One 16-bit SM on a CMOS5L 6×4, PIO-style delay/side-set, per-SM clkdiv, capture/replay. UART / SPI / I2C / JTAG / SWD are firmware, not hard IP.

Apache-2.0. Tree started from [ttihp-verilog-template](https://github.com/TinyTapeout/ttihp-verilog-template.git). This GitHub remote is a private working copy, not the Tiny Tapeout template.

## What is actually green

See `docs/STATUS.md`. Short version: ISA + firmware + Python/OCaml SAT + Icarus UART 0x55 + opcode lockstep are local. A routed CMOS5L 6×4 at 20 ns is the Phase 2 exit and is not ticked until GHA `gds` + UART GLS are green.

## Quick check

```
./sim/check.sh
```

Needs Python 3 and Icarus Verilog. On a machine with the local switch:

```
eval "$(opam env --switch=ocaml-base-compiler.5.3.0)"
./sim/check.sh          # also OCaml SAT/UART + SBY decode
yosys -s sim/synth.ys   # generic cells, not IHP
```

A character leaves `uio[0]`. That is the week-1 gate (Verilog SM). Hardcaml Cyclesim was the preferred path and missed the week-1 window; there will not be a January rewrite of the SM.

## Layout

| Path | What |
|---|---|
| `ISA.md` | Frozen 16-bit encoding |
| `src/` | TT wrapper, one SM (SM1 generate-off), host, no SRAM on the die |
| `fw/` | UART TX/RX, SPI 4 modes, I2C, JTAG, SWD, PS/2, USB LS-shaped |
| `sim/` | Python golden, SAT-on-decode, `check.sh` |
| `ocaml/` | OCaml ISA + SAT + UART-ops golden (fallback) |
| `formal/` | SymbiYosys field-split + opcode-step |
| `host/loader.py` | Nibble stream for the TT RP2040 |
| `docs/` | Status, host protocol, verify, writeup, 8×4 email, P&R handoff, citations |

## Docs

- `docs/STATUS.md` — phase ticks, only what was run
- `docs/HOST.md` — `ui_in` nibble commands
- `docs/VERIFY.md` — commands and pass strings
- `docs/PHASE0_CONSTRAINTS.md` — PDK / tile / pin sheet with cited numbers
- `docs/WRITEUP.md` — Jane Street-facing writeup (draft)
- `docs/info.md` — Tiny Tapeout datasheet
- `docs/EMAIL_8x4.md` — sent mail (CMOS5L has no 8×4 DEF)

`info.yaml` is `tiles: "6x4"`. Reopen 8×4 only if Jane Street ships a CMOS5L DEF.
