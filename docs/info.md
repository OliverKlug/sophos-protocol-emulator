<!---
Tiny Tapeout datasheet.
-->

## How it works

ProtoEmu is a reprogrammable pin machine, not a UART+SPI+I2C mashup. One 16-bit state machine on this 6×4 CMOS5L die executes an ISA aimed at pins, delays, and FIFOs. A second SM is generate-off so a later die can turn it on. Firmware after tapeout is how a new protocol shows up.

Each instruction is 16 bits: 3-bit opcode, a PIO-style shared delay/side-set field (`SIDESET_COUNT=1`), and an 8-bit payload. Per-SM clock enable is `f_sm = f_sys / (INT + FRAC/256)`. `{value, oe}` is dest `PINOE`: one beat writes 8 data bits and 8 output-enables.

Instruction memory is 32 × 16 flops. Capture is 16 shadow records. There is no IHP SRAM macro on this stack (TopMetal2). Capture/replay plus a peek mux on `uo_out` is the reverse-engineering instrument. Peek select 10 is RX0 and pops that FIFO.

Host protocol lives on `ui_in`: nibble + 3-bit cmd + rising strobe. `uio[7:0]` are the protocol pins. STA clock is 40 MHz (`clock_hz: 40000000`); board UART is pad-limited.

## How to test

1. Load `fw/uart_tx` through the host nibble (`host/loader.py`).
2. Push a byte into SM0's TX FIFO.
3. CTRL start SM0 (`ui_in` cmd 5, nibble bit 0).
4. Watch `uio[0]` for 8n1. Icarus check: `iverilog` + `test/tb_uart.v` expects 0x55. GLS: same vector, not idle. Host-reload UART then SPI then I2C: `test/tb_three_proto.v` (`PASS three proto host-load`). RX peek-10: `test/tb_uart_rx.v`.

SPI master modes 0-3, SPI JEDEC MISO (`test/tb_spi.v`), I2C stretch/ACK vs a slave model, and JTAG IDCODE (`test/tb_jtag.v`) are other programs in `fw/`. SWD, PS/2, and USB LS are pin-dances. Same silicon. No board: no FT232, physical W25Q, or OpenOCD.

Golden + SAT: `python3 sim/test_all.py`. Full local stack: `./sim/check.sh` (adds OCaml and SBY when installed). Honest phase ticks: `docs/STATUS.md`.

## External hardware

None for UART/SPI. I2C needs pullups on SDA/SCL. USB LS and CAN need a PHY or discrete resistors; this die does not contain analog.
