# Sophos

Jane Street [protocol emulator ASIC](https://blog.janestreet.com/protocol-emulator-asic-competition/) for Tiny Tapeout on IHP 130 nm CMOS5L. Contest deadline 18 January 2027. Open-source Verilog. Not the antivirus company.

A reprogrammable pin state machine, in the same family as RP2040 PIO and TI PRU: UART, SPI, I2C, JTAG, and USB LS bit-layer TX are firmware, not hard IP. Capture/replay is the reverse-engineering instrument. 6×4 tiles (`info.yaml`). Silicon top `tt_um_klug_sophos`.

Apache-2.0. Tree started from [ttihp-verilog-template](https://github.com/TinyTapeout/ttihp-verilog-template.git).

## What is actually green

See `docs/STATUS.md`. CMOS5L 6×4 GDS + UART 0x55 GLS + precheck passed on GHA at 25 ns / 40 MHz (SHA `8e4ef83`, then still named `tt_um_klug_protoemu`). Capture dump and USB LS are on this tree; the renamed top needs a new GDS. Anish confirmed 6×4 until they ship 8×4.

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

A character leaves `uio[0]`. That is the week-1 gate (Verilog SM). Hardcaml Cyclesim missed the week-1 window; there will not be a January rewrite of the SM.

## Layout

| Path | What |
|---|---|
| `ISA.md` | Frozen 16-bit encoding |
| `src/` | TT wrapper, one SM (SM1 generate-off), host, no SRAM on the die |
| `fw/` | UART TX / frame RX, SPI 4 modes + JEDEC, I2C master, JTAG IDCODE, USB LS bit-layer TX; SWD/PS2 pin-dances |
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
- `docs/EMAIL_8x4.md` — 8×4 mail; Anish: stay on 6×4

`info.yaml` is `tiles: "6x4"`. Reopen 8×4 only if Jane Street mails that the CMOS5L DEF exists.
