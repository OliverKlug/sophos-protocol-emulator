# Status (only what was run and passed)

As of 2026-09-15. Do not treat a checkbox here as a LibreLane GDS.

## Phase 0 — contest lock

Checked:

- Template clone from `ttihp-verilog-template`, top `tt_um_klug_protoemu`.
- Email sent to `asic-competition@janestreet.com` (copy in `EMAIL_8x4.md`). Waiting on a reply.
- CMOS5L tools: **no `8x4` key**, **no `tt_block_8x4_pgvdd.def`**. Height-4 DEFs stop at `6x4`. Live `info.yaml` is `tiles: "6x4"`.

Not checked: Jane Street shipping an 8×4 CMOS5L DEF.

## Phase 1 — UART out of a pin

Checked (week-1 fallback, not Hardcaml Cyclesim):

- Icarus 13.0 `test/tb_uart.v`: `PASS UART TX 0x55`, peek PC live.
- Python golden `sample_uart_tx`.
- OCaml 5.3 `ocaml/uart_tx.ml`: 0x55 on pin0 (TX-ops only).

Not checked: Hardcaml Cyclesim of an SM. That rewrite is off the table.

## Phase 2 — CMOS5L 6×4 harden and opcode formal

Local, not a silicon tick:

- Area cut: 32×16 IMEM (64 was >8k generic Yosys), SM1 generate-off, no `u_sram`, capture depth 16, RX0 pop on peek-10.
- Golden STATUS `{tx_empty, rx_full, osre}`, PC wrap 31.
- `formal/step.sby` + `sim/lockstep.py` / `test/tb_sm_lockstep.v` (8×8×32, delay 0/1/15).
- Floor: `tiles: "6x4"`, DIE_AREA `0 0 1289.28 710.64`, `RT_MAX_LAYER: Metal4`, PDN 50/2.1, action `@ihp-cmos5l` / `ihp-sg13cmos5l`.
- GL Makefile includes `sg13cmos5l_udp.v`. Vector is UART 0x55.

**Not ticked.** Phase 2 stays open until the CMOS5L `gds` job is green and UART GLS passes. Viewer/Pages is not a silicon exit.

## Phase 3 — protocols as programs

Checked in Python golden:

- SPI master modes 0–3 × 8/16 MOSI bits.
- I2C START, `WAIT SCL=1` stretch, NAK stall, never drive SDA high.
- JTAG / SWD / PS/2 / USB LS-shaped programs assemble.
- Two-SM golden path still exists (`Core(sm1=True)`). It is not on this die.

Not checked: FT232 UART, W25Q JEDEC, stretching I2C slave, OpenOCD IDCODE. No board.

## Phase 4 — capture / replay

Checked:

- UART TX capture → RX replay (host bit-reverses the left-shifted ISR).
- Capture expand keeps start+8 data.
- Halted SM0: pin changes move capture wptr only.
- Icarus peek mux (PC).

Not checked: RTL capture dump vs golden lockstep on the host nibble.

## Phase 5 — FPGA / GLS / STA

Not checked. No FPGA, no Verilator, no LibreLane GLS on this machine, no 20 ns proof.

## Phase 6 — stretch

USB LS-shaped firmware exists. No analog PHY. Not a HID demo.

## Deliverables

In tree: ISA, writeup, TT `docs/info.md`, SAT artifacts, host loader, firmware. Contest submit is 2027-01-18, not now.
