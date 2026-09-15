#!/bin/sh
set -e
cd "$(dirname "$0")/.."
python3 sim/test_all.py

rtl() {
  iverilog -g2012 -o "$1" \
    src/project.v src/protoemu_core.v src/sm.v src/fifo4.v src/clkdiv.v \
    "$2"
  vvp "$1"
}

rtl test/tb_uart.vvp test/tb_uart.v
rtl test/tb_uart_rx.vvp test/tb_uart_rx.v
rtl test/tb_spi.vvp test/tb_spi.v
rtl test/tb_jtag.vvp test/tb_jtag.v
rtl test/tb_three_proto.vvp test/tb_three_proto.v

python3 sim/lockstep.py
iverilog -g2012 -o test/tb_sm_lockstep.vvp \
  src/sm.v test/tb_sm_lockstep.v
vvp test/tb_sm_lockstep.vvp +expect=sim/lockstep_expect.txt

if command -v opam >/dev/null 2>&1; then
  eval "$(opam env --switch=ocaml-base-compiler.5.3.0 2>/dev/null)" || true
fi
if command -v dune >/dev/null 2>&1; then
  (cd ocaml && dune exec ./sat_decode.exe && dune exec ./uart_tx.exe)
else
  echo "skip OCaml (dune not on PATH)"
fi
if command -v sby >/dev/null 2>&1; then
  (cd formal && sby -f decode.sby && sby -f step.sby)
else
  echo "skip SBY (sby not on PATH)"
fi
echo "check.sh OK"
