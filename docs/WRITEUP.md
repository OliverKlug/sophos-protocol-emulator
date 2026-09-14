# ProtoEmu writeup (Jane Street protocol-emulator ASIC)

Deadline target: 2027-01-18. Process: IHP CMOS5L via Tiny Tapeout, 6×4 (legal height-4). One SM on this die.

## What this is

A tiny ISA for reading pins, writing pins, waiting, and hitting a cycle. UART, SPI, and I2C are firmware. JTAG and SWD are firmware. Capture/replay is the product. SAT on every 16-bit encoding is how we show the decoder is not slop.

It is not three hardcoded peripherals. It is not a RISC-V. It is not a 32-word PIO clone.

## Week-1 HDL path

Hardcaml Cyclesim missed the week-1 window. The named fallback is the chip: Verilog SM, Python golden, OCaml ISA/UART golden (`ocaml/`), exhaustive SAT-on-decode in both languages, SBY on the field split (`formal/decode.sby`) and opcode-step (`formal/step.sby`). Icarus 13.0: `test/tb_uart.v` prints `PASS UART TX 0x55`. Lockstep: `PASS lockstep cases=…` against `golden.Sm`.

A January Hardcaml rewrite is not on the table. No Amaranth port.

## ISA (see ISA.md)

16-bit word. Delay and side-set share 5 bits, `SIDESET_COUNT=1`. Per-SM clkdiv, integer required, 8-bit fraction present. `PINOE` is the `{value, oe}` dest: 16-bit OSR in one beat. JMP target is always `payload[4:0]` (0..31). `jmp(32)` is illegal. Longer jumps are `MOV PC, X`. No wrap hardware; UART TX unrolls eight `OUT`s so a JMP cannot double the baud cell.

IMEM is 32 × 16. One pipeline instance on the routed die. SM1 is generate-off (`PROTOEMU_SM1`). Cut = delete an instance, not a second ISA.

## Why not PIO / PRU

PIO's 32-word shared IMEM and X/Y-only file are why I2C becomes `OUT EXEC` soup and USB becomes an ARM busy-wait. We have 32 instructions (firmware max today is 19) and 16-bit X/Y/ISR/OSR plus debug peek (PC, X, Y, ISR, OSR, FIFO, capture wptr, RX0). PRU is a 32-bit RISC plus industrial helpers. That will not fit, and pin wait is a poll loop. We kept hardware `WAIT`.

## Capture/replay

On pin or OE change, the core writes a 16-deep flop shadow. `replay_en` drives `uio` from that shadow. Peek mux is `uo_out`. Peek-10 is RX0 and pops it. No foundry SRAM: CMOS5L SRAM macros need TopMetal2.

## Host

`ui_in[7]` strobe, `[6:4]` cmd, `[3:0]` nibble.

| cmd | action |
|---|---|
| 0 | shift nibble into 16-bit staging |
| 1 | IMEM write, addr++ (5-bit wrap) |
| 2 | set IMEM addr from staging[4:0] |
| 3/4 | push staging to SM0/SM1 TX FIFO |
| 5 | `{replay, cap, start1, start0}` |
| 6 | clkdiv from staging |
| 7 | peek select; nibble 10 also pops RX0 |

## Verification

| Layer | Status |
|---|---|
| SAT on decode | Python and OCaml 65536-word bijection; SBY `formal/decode.sby` on the same field split |
| Opcode step | SBY `formal/step.sby` (WAIT/IRQ stall, JMP, side-set last-wins, PULL/PUSH block, delay freeze, !start reset) |
| Expect-style UART | Icarus frame hunt for 0x55; golden `sample_uart_tx` |
| Golden lockstep | `sim/lockstep.py` + `test/tb_sm_lockstep.v`: 8×8×32, delay 0/1/15, small side=1 slice |
| Constrained random | 200 random IMEM words, pin noise, PC bound 31 |
| SPI 4 modes | golden: modes 0-3 x 8/16 MOSI bits |
| I2C | START (SDA fall, SCL=1), WAIT SCL stretch, NAK stall, never drive SDA 1 |
| Capture purity | SM halted: pin changes move capture wptr only |
| P&R | CMOS5L 6×4 configs in tree. Phase 2 not ticked until GHA `gds` + UART GLS |
| AI | used to draft RTL and tests; oracles are SAT, golden, Icarus, SBY |

## 6×4 / shuttle

CMOS5L `tt-support-tools` branch `ihp-sg13cmos5l` has no 8×4 tile and no 8×4 DEF (citations under `docs/citations/`). Gremlin-Board shipped 6×4 on the same action. Email sent: `docs/EMAIL_8x4.md`. Reopen 8×4 only if Jane Street ships a CMOS5L DEF.

## What we will not claim

USB FS/HS. On-die Ethernet PHY. TinyQV 64 MHz as an IHP number. A 50 ns SPI-slave path. FAULT/glitch as core RTL. Two SMs on this GDS.
