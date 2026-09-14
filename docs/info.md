<!---
Tiny Tapeout datasheet.
-->

## How it works

ProtoEmu is a reprogrammable pin machine, not a UART+SPI+I2C mashup. Two identical 16-bit state machines execute an ISA aimed at pins, delays, and FIFOs. Firmware after tapeout is how a new protocol shows up.

Each instruction is 16 bits: 3-bit opcode, a PIO-style shared delay/side-set field (`SIDESET_COUNT=1`), and an 8-bit payload. Per-SM clock enable is `f_sm = f_sys / (INT + FRAC/256)`. `{value, oe}` is dest `PINOE`: one beat writes 8 data bits and 8 output-enables, which is how I2C/SWD turnaround stays one cycle.

Instruction memory is 256 x 16, dual-read, so both SMs fetch every tick. A 1024x8 flop models the IHP SRAM prior: low half IMEM image, high half capture records. Capture/replay plus a peek mux on `uo_out` is the reverse-engineering instrument.

Host protocol lives on `ui_in`: nibble + 3-bit cmd + rising strobe. `uio[7:0]` are the protocol pins.

## How to test

1. Load `fw/uart_tx` through the host nibble (`host/loader.py`).
2. Push a byte into SM0's TX FIFO.
3. CTRL start SM0 (`ui_in` cmd 5, nibble bit 0).
4. Watch `uio[0]` for 8n1. Icarus check: `iverilog` + `test/tb_uart.v` expects 0x55.

SPI master modes 0-3, I2C stretch/ACK, JTAG, SWD, PS/2, and a USB LS-shaped TX are other programs in `fw/`. Same silicon.

Golden + SAT: `python3 sim/test_all.py`. Full local stack: `./sim/check.sh` (adds OCaml and SBY when installed). Honest phase ticks: `docs/STATUS.md`.

## External hardware

None for UART/SPI. I2C needs pullups on SDA/SCL. USB LS and CAN need a PHY or discrete resistors; this die does not contain analog.
