# Changelog

## 0.5 — 2026-09-17 / SHA `691c728`

32-slot capture `{pin, oe, hold}`, hold-this saturate, dump peeks 11–14, `cap_mode` SCLK qualify. USB LS bit-layer TX firmware on the same die. Product renamed Sophos. Top `tt_um_klug_sophos`.

GHA [run 35215850540](https://github.com/OliverKlug/sophos-protocol-emulator/actions/runs/35215850540): `gds` / `precheck` / `gl_test` green. STA 25 ns, vio 0, slow setup +0.79 ns, hold +0.13 ns, 11624 stdcells, 22.2% util. Viewer red (Pages).

## 0.4 — 2026-09-16

USB LS host encoder: SYNC `0x80`, NRZI+stuff, CRC-16/USB, EOP. Icarus `PASS USB LS`. No RTL change vs the Phase 5 die at the time (`8e4ef83`).

## 0.3 — 2026-09-15

UART RX peek-10, SPI JEDEC MISO, I2C OD stretch/ACK, JTAG IDCODE, three-proto host-load. WAIT combo. Same 6×4 floorplan.

## 0.2 — 2026-09-16 / SHA `8e4ef83` (history)

CMOS5L 6×4 GDS, UART GLS, precheck. 16-slot capture. Top still `tt_um_klug_protoemu`. STA 25 ns, vio 0, slow setup +0.50 ns, hold +0.11 ns, 8284 stdcells, 15.5% util. 20 ns missed slow setup by −3.89 ns.

## 0.1 — 2026-09-14

Verilog SM fallback after Hardcaml Cyclesim missed week 1. Python golden, OCaml SAT, SAT-on-decode 65536. UART TX 0x55 out of a pin.
