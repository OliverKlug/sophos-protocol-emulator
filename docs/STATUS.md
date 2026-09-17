# Status (only what was run and passed)

As of 2026-09-16. Do not treat a checkbox here as a LibreLane GDS.

## Phase 0 — contest lock

Checked:

- Template clone from `ttihp-verilog-template`. Product name is Sophos. Silicon top is `tt_um_klug_sophos` (was `tt_um_klug_protoemu` on GHA SHAs through `8e4ef83`).
- Email sent to `asic-competition@janestreet.com` (copy in `EMAIL_8x4.md`). Anish replied 2026-09-15: template has no 8×4 yet; develop on 6×4; they will mail if 8×4 lands.
- CMOS5L tools: **no `8x4` key**, **no `tt_block_8x4_pgvdd.def`**. Height-4 DEFs stop at `6x4`. Live `info.yaml` is `tiles: "6x4"`. That is now the contest instruction, not a guess.

## Phase 1 — UART out of a pin

Checked (week-1 fallback, not Hardcaml Cyclesim):

- Icarus 13.0 `test/tb_uart.v`: `PASS UART TX 0x55`, peek PC live.
- Python golden `sample_uart_tx`.
- OCaml 5.3 `ocaml/uart_tx.ml`: 0x55 on pin0 (TX-ops only).

Not checked: Hardcaml Cyclesim of an SM. That rewrite is off the table.

## Phase 2 — CMOS5L 6×4 harden and opcode formal

Checked on `ab80ad6`, GHA [run 34907266141](https://github.com/OliverKlug/protoemu/actions/runs/34907266141), 2026-09-15:

- `gds` `@ihp-cmos5l` / `ihp-sg13cmos5l` / `tiles: "6x4"` success (1h19m).
- `precheck` success (43m).
- `gl_test` success: cocotb `test.test_uart_0x55` on the gate netlist, `TESTS=1 PASS=1 FAIL=0`. Not idle `uo_out[0]==0`.
- Local: `./sim/check.sh` (golden + UART RTL + lockstep 6180 + `formal/step.sby` PASS). Yosys generic 7830 cells, no `sram_flop`.

Viewer failed: private-repo GitHub Pages 404. Not a silicon exit.

Die: one SM, 32×16 IMEM, capture 16, no IHP SRAM. Anish: stay on 6×4 until they ship 8×4.

## Phase 3 — protocols as programs

Checked locally, 2026-09-15. Same CMOS5L 6×4 die as Phase 2 (`PROTOEMU_SM1=0`). No new GDS.

- Icarus `test/tb_three_proto.v`: `PASS three proto host-load` (UART TX 0x55, SPI mode-0 MOSI, I2C START+OD+stretch+ACK) on one `tt_um_klug_sophos`, sequential IMEM reload.
- Icarus `test/tb_uart_rx.v`: `PASS UART RX peek-10` (cmd 7 nibble 10; `uo_out` is the left-shifted ISR byte, host bit-reverses).
- Icarus `test/tb_spi.v`: `PASS SPI MISO` (JEDEC 0x9F vs a Verilog flash; RX is EF 40 16, not MOSI loopback).
- Icarus `test/tb_jtag.v`: `PASS JTAG IDCODE` vs a TAP model (`0x1234ABCD`). The old `len(prog)>=4` cartoon is retired.
- Python: I2C wired-AND slave (ACK, NACK→STOP, stretch 1 bit / 1 byte, repeated START, OD monitor on the resolved bus). UART frame RX ±0/2/5% baud, ±1 tick jitter, runt, bad stop / break recover. SPI `fw/spi_jedec.py` + `sim/flash_miso.py`.

Named skip, no board: FT232 UART, physical W25Q, OpenOCD. SWD / PS/2 stay unlabeled pin-dances. Gate-level vector stays UART 0x55; SPI/I2C/USB stay Icarus RTL. Two SMs are not on this GDS.

## Phase 4 — capture / replay

Checked locally, 2026-09-17. RTL in `protoemu_core.v`. No new GDS yet. January binary stays `8e4ef83` until GHA 25 ns green.

- 32 live slots, packed `{pin, oe, hold}`. Hold-this, saturate at 255, no overflow writes. `cap_mode=0` pin/OE change; `cap_mode=1` SCLK rise while CS low (peek 15 from shifter[0]).
- Python: `CAP UART 0x55 wptr=12`. `CAP SPI mode0 8 MOSI=0xa5`. `CAP JEDEC 0x9F wptr=32 ID=EF 40 16`.
- Icarus `test/tb_cap.v`: `PASS UART CAP`, `PASS CAP dump` (peek 11–13), `PASS CAP timed replay`.
- Icarus `test/tb_spi_cap.v`: `PASS SPI CAP replay` (edge mode).
- Icarus `test/tb_jedec_cap.v`: `PASS JEDEC CAP`.
- Generic Yosys `sim/synth.ys`: 9994 cells (was 7830). Extra is the 32×24 flop file, not a second async port (that path was 19k and was killed).

GLS dump is in `test.test_uart_0x55` (still `TESTS=1`). New GDS not signed off.

## Phase 5 — FPGA / GLS / STA

Checked on `8e4ef83` (WAIT combo + Phase 3 firmware), GHA [run 35023276762](https://github.com/OliverKlug/protoemu/actions/runs/35023276762), 2026-09-16:

- `gds` `@ihp-cmos5l` success (1h24m). One SM, 32×16 IMEM, capture 16. `CLOCK_PERIOD` 25 ns.
- `precheck` success (41m). First attempt on this run was canceled mid-klayout (`results.xml` missing); rerun greened. Not a DRC report.
- `gl_test` success: `test.test_uart_0x55`, `TESTS=1 PASS=1 FAIL=0`. Not idle.
- Signoff STA from `GDS_logs` `55-openroad-stapostpnr/summary.rpt` and `final/metrics.json`: 25 ns, setup/hold vio count 0 (aggregated and `nom_slow_1p08V_125C`). Slow setup WS **+0.50 ns**, overall hold WS **+0.11 ns**. 20 ns on the prior SHA missed slow setup by **−3.89 ns** (10 r2r vios, hold clean). Post-P&R stdcells 8284, util 15.5%.

Viewer failed: private Pages 404, then duplicate `github-pages` artifact on rerun. Not a silicon exit.

Named skip: FPGA (`fpga.yaml` `branches: none`, action tag `@ihp-cmos5l`), Verilator protocol twin, SDF GLS, SPI/I2C in `test.py`, two SMs, Hardcaml SEC.

## Phase 6 — USB LS bit-layer TX

Checked locally, 2026-09-16. Same Phase 5 die (`8e4ef83`). No RTL, no GDS, no USB in `test.py`.

- Python `sim/test_usb_ls.py`: `USB LS SYNC+NRZI+stuff+EOP OK`. Host `encode_packet()`: SYNC `0x80`, NRZI+stuff (incl. last-1-before-EOP), CRC-16/USB low-byte-first (DATA0+FF `C3 FF 00 FF`, DATA0+00 `C3 00 40 BF`, empty `C3 00 00`). Destuff-by-delete. PID complement rejects `D3`. No NAK encode. SM 4 words, FIFO streamed (never empty mid-packet in the golden).
- Icarus `test/tb_usb.v`: `PASS USB LS` (ACK, DATA0+FF, DATA0+00). Bit-centre sample of D+/D−. clkdiv INT=8 so `fifo_push` (~15 clk) cannot starve a 3-tick bit. `./sim/check.sh` prints `check.sh OK`.

Not a device, not HID, not FS/HS, not a hub clock. LS function rate is 1.5 Mbps ±1.5% (`TLDRATE`). INT=27 FRAC=0 is −1.23% on that table. PHY off-chip. D−=`uio[0]`, D+=`uio[1]`.

Named skip: FPGA HID (`fpga.yaml` `branches: none`), 6.5-bit turnaround, CAN/ETH/FAULT, chirp, keep-alive/SOF/PRE, GLS USB, CRC opcode, host NAK.

## Deliverables

In tree: ISA, writeup, TT `docs/info.md`, SAT artifacts, host loader, firmware. Contest submit is 2027-01-18, not now.
