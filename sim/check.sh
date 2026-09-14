#!/bin/sh
set -e
cd "$(dirname "$0")/.."
python3 sim/test_all.py
iverilog -g2012 -o test/tb_uart.vvp \
  src/project.v src/protoemu_core.v src/sm.v src/fifo4.v src/clkdiv.v src/sram_flop.v \
  test/tb_uart.v
vvp test/tb_uart.vvp

if command -v opam >/dev/null 2>&1; then
  eval "$(opam env --switch=ocaml-base-compiler.5.3.0 2>/dev/null)" || true
fi
if command -v dune >/dev/null 2>&1; then
  (cd ocaml && dune exec ./sat_decode.exe && dune exec ./uart_tx.exe)
else
  echo "skip OCaml (dune not on PATH)"
fi
if command -v sby >/dev/null 2>&1; then
  (cd formal && sby -f decode.sby)
else
  echo "skip SBY (sby not on PATH)"
fi
echo "check.sh OK"
