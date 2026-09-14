# Status (only what was run and passed)

As of 2026-09-15. Do not treat a checkbox here as a LibreLane GDS.

## Phase 0 — contest lock

Checked:

- Template clone from `ttihp-verilog-template`, top `tt_um_klug_protoemu`, `tiles: "8x4"`.
- Email sent to `asic-competition@janestreet.com` (copy in `EMAIL_8x4.md`). Waiting on a reply.
- CMOS5L tools (branch `ihp-sg13cmos5l`, copied into `docs/citations/`): **no `8x4` key**, **no `tt_block_8x4_pgvdd.def`**. Height-4 DEFs stop at `6x4`. The 8-wide floorplan is `8x2`. The `1724.16 x 710.64` 8x4 number is `ihp-sg13g2` on `main`, a different PDK.
- Generic Yosys 0.69 hello-world: `yosys -s sim/synth.ys` elaborates. 36902 generic cells with flop SRAM. Not STA. Not IHP.

Not checked: Jane Street accepting 8x4 on CMOS5L. No open March 2027 TT CMOS5L row.

## Phase 1 — UART out of a pin

Checked (week-1 fallback, not Hardcaml Cyclesim):

- Icarus 13.0 `test/tb_uart.v`: `PASS UART TX 0x55`, peek PC live.
- Python golden `sample_uart_tx`.
- OCaml 5.3 `ocaml/uart_tx.ml`: 0x55 on pin0 (TX-ops only).

Not checked: Hardcaml Cyclesim of an SM. That rewrite is off the table.

## Phase 2 — ISA freeze + first P&R

Checked:

- `ISA.md` 16-bit pack, clkdiv, PINOE, JMP 0..31.
- Python + OCaml 65536-word encode/decode bijection.
- SBY `formal/decode.sby` (smtbmc z3) on the field-split identity.
- Firmware UART TX/RX.

Not checked: routed 8x4 at 20 ns. No IHP PDK, no LibreLane run. Flop SRAM stand-in only. **This phase is not closed.**

## Phase 3 — protocols as programs

Checked in Python golden:

- Two identical SM instances.
- SPI master modes 0–3 × 8/16 MOSI bits.
- I2C START, `WAIT SCL=1` stretch, NAK stall, never drive SDA high.
- JTAG / SWD / PS/2 / USB LS-shaped programs assemble.

Not checked: FT232 UART, W25Q JEDEC, stretching I2C slave, OpenOCD IDCODE. No board.

## Phase 4 — capture / replay

Checked:

- UART TX capture → RX replay (host bit-reverses the left-shifted ISR).
- Capture expand keeps start+8 data.
- Halted SMs: pin changes move capture wptr only.
- Icarus peek mux (PC).

Not checked: RTL capture SRAM dump vs golden lockstep on the host nibble.

## Phase 5 — FPGA / GLS / STA

Not checked. No FPGA, no Verilator, no LibreLane GLS, no 20 ns proof.

## Phase 6 — stretch

USB LS-shaped firmware exists. No analog PHY. Not a HID demo.

## Deliverables

In tree: ISA, writeup, TT `docs/info.md`, SAT artifacts, host loader, firmware. Contest submit is 2027-01-18, not now.
