# ProtoEmu writeup (Jane Street protocol-emulator ASIC)

Deadline target: 2027-01-18. Process: IHP CMOS5L via Tiny Tapeout, 8x4.

## What this is

A tiny ISA for reading pins, writing pins, waiting, and hitting a cycle. UART, SPI, and I2C are firmware. JTAG and SWD are firmware. Capture/replay is the product. SAT on every 16-bit encoding is how we show the decoder is not slop.

It is not three hardcoded peripherals. It is not a RISC-V. It is not a 32-word PIO clone.

## Week-1 HDL path

Hardcaml Cyclesim missed the week-1 window. The named fallback is the chip: Verilog SM, Python golden, OCaml ISA/UART golden (`ocaml/`), exhaustive SAT-on-decode in both languages, SBY on the field split (`formal/decode.sby`). Icarus 13.0: `test/tb_uart.v` prints `PASS UART TX 0x55`.

A January Hardcaml rewrite is not on the table.

## ISA (see ISA.md)

16-bit word. Delay and side-set share 5 bits, `SIDESET_COUNT=1`. Per-SM clkdiv, integer required, 8-bit fraction present. `PINOE` is the `{value, oe}` dest: 16-bit OSR in one beat. JMP target is always `payload[4:0]` (0..31). `jmp(32)` is illegal. Longer jumps are `MOV PC, X`. No wrap hardware; UART TX unrolls eight `OUT`s so a JMP cannot double the baud cell.

Two copies of one pipeline. SM1 is a clock in software (IRQ + side-set). Cut = delete an instance.

## Why not PIO / PRU

PIO's 32-word shared IMEM and X/Y-only file are why I2C becomes `OUT EXEC` soup and USB becomes an ARM busy-wait. We have 256 instructions and four 16-bit GPRs plus debug peek (PC, X, Y, ISR, OSR, FIFO, capture wptr). PRU is a 32-bit RISC plus industrial helpers. That will not fit, and pin wait is a poll loop. We kept hardware `WAIT`.

## Capture/replay

On pin or OE change, the core writes `{delta, pins, oe}` into the SRAM high half and a 128-entry flop shadow. `replay_en` drives `uio` from that shadow. Peek mux is `uo_out` (Icarus: PC is live after UART TX). Recorded UART TX expands back to start+8 data; change-compress drops a stop that equals the last data bit. With both SMs halted, toggling `uio_in` moves only the capture pointer. SAT on decode stays; NuSMV is not here.

## Host

`ui_in[7]` strobe, `[6:4]` cmd, `[3:0]` nibble.

| cmd | action |
|---|---|
| 0 | shift nibble into 16-bit staging |
| 1 | IMEM write, addr++ |
| 2 | set IMEM addr from staging |
| 3/4 | push staging to SM0/SM1 TX FIFO |
| 5 | `{replay, cap, start1, start0}` |
| 6 | clkdiv from staging |
| 7 | peek select |

## Verification

| Layer | Status |
|---|---|
| SAT on decode | Python and OCaml 65536-word bijection; SBY `formal/decode.sby` on the same field split |
| Expect-style UART | Icarus frame hunt for 0x55; golden `sample_uart_tx` |
| Golden lockstep | `sim/golden.py` / `sim/test_all.py` |
| Constrained random | 200 random IMEM words, pin noise, no PC/pin blowup |
| SPI 4 modes | golden: modes 0-3 x 8/16 MOSI bits |
| I2C | START (SDA fall, SCL=1), WAIT SCL stretch, NAK stall, never drive SDA 1 |
| Capture purity | SMs halted: pin changes move capture wptr only |
| Differential | Icarus vs golden on UART 0x55. No FT232 / W25Q on this desk. |
| P&R | Yosys 0.69 generic `stat` in `docs/PAR_HANDOFF.md`. No LibreLane/IHP. |
| AI | used to draft RTL and tests; oracles are SAT, golden, Icarus |

## 8x4 / shuttle

CMOS5L `tt-support-tools` branch `ihp-sg13cmos5l` has no 8x4 tile and no 8x4 DEF (citations under `docs/citations/`). The 1724.16 x 710.64 µm 8x4 number is sg13g2. Email sent: `docs/EMAIL_8x4.md`. Waiting on a reply. No open March 2027 TT CMOS5L row today.

## What we will not claim

USB FS/HS. On-die Ethernet PHY. TinyQV 64 MHz as an IHP number. A 50 ns SPI-slave path. FAULT/glitch as core RTL.
