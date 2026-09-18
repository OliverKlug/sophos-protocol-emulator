# Sophos

Jane Street [protocol emulator ASIC](https://blog.janestreet.com/protocol-emulator-asic-competition/) for Tiny Tapeout on IHP 130 nm CMOS5L. Contest deadline 18 January 2027. Open-source Verilog. Not the antivirus company.

Public repo: [github.com/OliverKlug/sophos-protocol-emulator](https://github.com/OliverKlug/sophos-protocol-emulator).

A reprogrammable pin state machine, in the same family as RP2040 PIO and TI PRU: UART, SPI, I2C, JTAG, and USB LS bit-layer TX are firmware, not hard IP. Capture/replay is the reverse-engineering instrument. 6×4 tiles (`info.yaml`). Silicon top `tt_um_klug_sophos`.

Apache-2.0. Tree started from [ttihp-verilog-template](https://github.com/TinyTapeout/ttihp-verilog-template.git).

## What is actually green

Closed die is SHA `691c728`. GHA [run 35215850540](https://github.com/OliverKlug/sophos-protocol-emulator/actions/runs/35215850540): `gds`, `precheck`, and `gl_test` green. STA 25 ns / 40 MHz, vio 0, slow setup +0.79 ns, hold +0.13 ns, 11624 stdcells, 22.2% util. One SM, 32×16 IMEM, 32-slot capture. Ledger: `docs/STATUS.md`. Criteria: `docs/CRITERIA.md`. Submit kit: `docs/SUBMIT.md`.

The workflow badge can be red while those three jobs are green. That is GitHub Pages (`viewer`), not silicon. Enable Pages yourself: Settings → Pages → Source = GitHub Actions. Anish confirmed 6×4 until they ship 8×4.

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
| `docs/` | Ledger, criteria, host, verify, writeup, submit kit, citations |

## Docs

- `docs/STATUS.md` — closed SHA, STA, skip list
- `docs/CRITERIA.md` — Jane Street sentence map
- `docs/SUBMIT.md` — freeze SHA and how to click submit when the form exists
- `docs/HOST.md` — `ui_in` nibble commands
- `docs/VERIFY.md` — commands and pass strings
- `docs/WRITEUP.md` — Jane Street-facing memo
- `docs/info.md` — Tiny Tapeout datasheet
- `docs/CHANGELOG.md` — SHA-tagged history
- `docs/EMAIL_8x4.md` — 8×4 mail; Anish: stay on 6×4

`info.yaml` is `tiles: "6x4"`. Reopen 8×4 only if Jane Street mails that the CMOS5L DEF exists.
