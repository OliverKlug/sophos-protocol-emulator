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

PIO's 32-word shared IMEM and X/Y-only file are why I2C becomes `OUT EXEC` soup and USB becomes an ARM busy-wait. We have 32 instructions (I2C master is 28; JTAG IDCODE 26; SPI JEDEC 19; UART frame RX 16) and 16-bit X/Y/ISR/OSR plus debug peek (PC, X, Y, ISR, OSR, FIFO, capture wptr, RX0). PRU is a 32-bit RISC plus industrial helpers. That will not fit, and pin wait is a poll loop. We kept hardware `WAIT`.

## Capture/replay

On pin or OE change (edge mode), or on SCLK rise while CS is low (SPI mode), the core commits a 32-slot flop file `{pins, oe, hold}`. Hold is inclusive duration of this sample, saturates at 255, and does not allocate overflow twins. `replay_en` restores those holds onto `uio`. Peek 11/12/13 dump pin/oe/hold at `dump_idx`; peek 14 increments it; peek 15 rewinds and loads `cap_mode` from `shifter[0]`. Peek-6 is the full-byte wptr.

UART TX `0x55` fits (12 records). Icarus dumps via peek 11–13 (`PASS CAP dump`) and walks timed replay (`PASS CAP timed replay`). Edge-mode SPI replay recovers MOSI on SCLK (`PASS SPI CAP replay`). SCLK-qualified capture fits full JEDEC `0x9F` (`PASS JEDEC CAP`, ID `EF 40 16`). Peek mux is `uo_out`. Peek-10 is RX0 and pops it. No foundry SRAM: CMOS5L SRAM macros need TopMetal2.

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
| SPI 4 modes + JEDEC MISO | golden MOSI 0–3 × 8/16; `PASS SPI MISO` vs a flash model (EF 40 16 after 0x9F, not MOSI loopback) |
| I2C | slave ACK / NACK→STOP / stretch 1 bit and 1 byte / Sr; OD monitor on the resolved bus; Icarus in `tb_three_proto` |
| UART RX | frame program ±0/2/5% baud and jitter; `PASS UART RX peek-10` |
| JTAG | `PASS JTAG IDCODE` vs TAP `0x1234ABCD`; SWD/PS2 remain pin-dances |
| USB LS | host NRZI+stuff+CRC-16/USB; `USB LS SYNC+NRZI+stuff+EOP OK`; Icarus `PASS USB LS` (ACK, DATA0+FF, DATA0+00). Bit-layer TX, PHY off-chip, not a device |
| Three proto | `PASS three proto host-load` on one wrapper, SM1 off |
| Capture | Icarus `PASS UART CAP` / `PASS CAP lockstep`; `PASS SPI CAP replay` (4-bit MOSI, not JEDEC). 15 live slots, 1 record/clk replay. Golden purity: halted SM, pin changes move wptr |
| P&R | CMOS5L 6×4 GDS + UART GLS + precheck on GHA run 35023276762 (`8e4ef83`). STA 25 ns / 40 MHz, slow setup WS +0.50 ns, hold WS +0.11 ns, vio count 0. Viewer/Pages is not enabled on this private repo |
| AI | used to draft RTL and tests; oracles are SAT, golden, Icarus, SBY |

## 6×4 / shuttle

CMOS5L `tt-support-tools` branch `ihp-sg13cmos5l` has no 8×4 tile and no 8×4 DEF (citations under `docs/citations/`). Anish 2026-09-15: develop on 6×4; they will mail if 8×4 lands. Copy: `docs/EMAIL_8x4.md`. Phase 5 GDS + UART GLS + 25 ns STA are green (`docs/STATUS.md`).

## What we will not claim

USB FS/HS. USB HID / device stack / 6.5-bit turnaround. Hub/host LS clock ±0.05% (INT=27 FRAC=0 is a LS function −1.23%, inside ±1.5%, not hub 500 ppm). FPGA HID. CAN / ETH / FAULT. GLS USB. On-die Ethernet PHY. TinyQV 64 MHz as an IHP number. A 50 ns SPI-slave path. FAULT/glitch as core RTL. Two SMs on this GDS. FT232 / physical W25Q / OpenOCD (no board).
