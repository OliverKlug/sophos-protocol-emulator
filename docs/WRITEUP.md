# Sophos (Jane Street protocol-emulator ASIC)

Deadline 2027-01-18. IHP CMOS5L via Tiny Tapeout, 6×4. One SM. Public repo: [OliverKlug/sophos-protocol-emulator](https://github.com/OliverKlug/sophos-protocol-emulator). Closed SHA `691c728`. Criteria map: `docs/CRITERIA.md`. How to run: `./sim/check.sh`.

## What this is

A 16-bit ISA for reading pins, writing pins, waiting, and hitting a cycle. UART, SPI, I2C, and JTAG are firmware loaded over the Tiny Tapeout nibble after fabrication. Capture/replay is the reverse-engineering instrument. SAT on every 16-bit encoding is how we show the decoder is not slop.

It is not three hardcoded peripherals. It is not a RISC-V. It is not a graph compiler. SWD and PS/2 are unlabeled pin-dances, not stacks.

## Why not PIO, PRU, or Loom

PIO's 32-word shared IMEM and X/Y-only file are why I2C becomes `OUT EXEC` soup and USB becomes an ARM busy-wait. We kept 32 instructions (I2C master 28, JTAG IDCODE 26, SPI JEDEC 19, UART frame RX 16, USB LS TX 4) and gave the SM 16-bit X/Y/ISR/OSR plus a peek mux (PC, X, Y, ISR, OSR, FIFO, capture wptr, RX0, dump). Hardware `WAIT` stays. Per-SM clkdiv is the baud trick; delay bits alone are not enough. `{value, oe}` is dest `PINOE` in one beat.

PRU is a 32-bit RISC plus industrial helpers. That will not fit. Pin wait there is a poll loop.

Loom compiles TOML graphs into a 7-opcode engine and is chasing 2-SM + IHP SRAM. Their closed GDS is still 1 SM / 1 slot. CMOS5L SRAM needs TopMetal2 we do not have. We did not become their compiler. Capture dump and a non-idle UART GLS are the things they still do not ship on the signed die.

ISA: `ISA.md`. Host nibble: `docs/HOST.md`.

## Capture / replay

On pin or OE change (edge mode), or on SCLK rise while CS (`uio[3]`) is low (SPI mode), the core commits a 32-slot flop file `{pins, oe, hold}`. Hold is inclusive duration of this sample, saturates at 255, and does not allocate overflow twins. `replay_en` restores those holds onto `uio`. Peek 11/12/13 dump pin/oe/hold at `dump_idx`; peek 14 increments it; peek 15 rewinds and loads `cap_mode` from `shifter[0]`. Peek-6 is the full-byte wptr.

UART TX `0x55` is 12 records (`PASS UART CAP`, `PASS CAP dump`, `PASS CAP timed replay`). Edge-mode SPI replay recovers MOSI on SCLK (`PASS SPI CAP replay`). SCLK-qualified capture fits full JEDEC `0x9F` (`PASS JEDEC CAP`, ID `EF 40 16`). Peek-10 is RX0 and pops it. No foundry SRAM.

## Verification (real pass strings)

| Layer | What you run | Pass |
|---|---|---|
| SAT on decode | Python and OCaml 65536-word bijection; SBY `formal/decode.sby` | bijection OK / SBY PASS |
| Opcode step | SBY `formal/step.sby` | PASS |
| UART TX | `test/tb_uart.v` | `PASS UART TX 0x55` |
| UART RX | `test/tb_uart_rx.v` | `PASS UART RX peek-10` |
| Lockstep | `sim/lockstep.py` + `tb_sm_lockstep.v` | `PASS lockstep cases=…` (6180) |
| SPI + JEDEC | `test/tb_spi.v` | `PASS SPI MISO` (`EF 40 16`) |
| I2C | `tb_three_proto.v` + golden slave | `PASS three proto host-load` |
| JTAG | `test/tb_jtag.v` | `PASS JTAG IDCODE` |
| USB LS | `test/tb_usb.v` | `PASS USB LS` |
| Capture | `tb_cap.v` / `tb_spi_cap.v` / `tb_jedec_cap.v` | `PASS UART CAP` / `PASS CAP dump` / `PASS CAP timed replay` / `PASS SPI CAP replay` / `PASS JEDEC CAP` |
| GLS | GHA `gl_test` on `691c728` | `TESTS=1 PASS=1` UART 0x55 + dump |
| P&R | run 35215850540 | 25 ns, vio 0, +0.79 / +0.13 ns, 11624 cells, 22.2% |

ISA formal is not a protocol waveform proof on RTL. GHA `test.yaml` skips OCaml/SBY. AI drafted RTL and tests; the oracles are SAT, golden, Icarus, SBY.

## Closed GDS

`tt_um_klug_sophos`, tiles `6x4`, `CLOCK_PERIOD` 25. Anish 2026-09-15: no 8×4 CMOS5L DEF yet (`docs/EMAIL_8x4.md`). Viewer/Pages is a human skip, not a silicon fail (`docs/STATUS.md`).

## What we will not claim

USB FS/HS. USB HID / device / 6.5-bit turnaround. Hub/host LS clock ±0.05% (INT=27 FRAC=0 is a LS function −1.23%, inside ±1.5%, not 500 ppm). FPGA. CAN / ETH / FAULT. GLS USB. On-die Ethernet PHY. TinyQV 64 MHz as an IHP number. 50 MHz (20 ns missed slow setup by 3.89 ns). Two SMs on this GDS. IHP SRAM. FT232 / physical W25Q / OpenOCD.
