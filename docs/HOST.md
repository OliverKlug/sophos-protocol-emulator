# Host nibble protocol

Pins do not grow with tile count. Host uses `ui_in`. Protocol lives on `uio[7:0]`. Peek is `uo_out`.

```
ui_in[7]   strobe (command commits on rising edge)
ui_in[6:4] cmd
ui_in[3:0] nibble
```

Hold strobe low, present `{cmd, nibble}`, raise strobe one cycle, drop it. `host/loader.py` emits `(cmd, nibble)` pairs in that order.

| cmd | nibble / [staging] | effect |
|---|---|---|
| 0 | nibble | `{staging[11:0], nibble}` |
| 1 | ignored | `imem[addr] <= staging`; addr++ |
| 2 | ignored | `addr <= staging[4:0]` |
| 3 | ignored | push `staging` to SM0 TX FIFO |
| 4 | ignored | push `staging` to SM1 TX FIFO |
| 5 | `{replay, cap, start1, start0}` | run / capture / replay |
| 6 | SM select in bit0; frac bits above | clkdiv from staging |
| 7 | peek select | `uo_out` mux; nibble 10 also pops RX0 |

Peek select: 0 PC0, 1 X0, 2 Y0, 3 ISR0, 4 OSR0, 5 FIFO flags, 6 capture wptr, 7 pins, 8 PC1, 9 X1, 10 RX0 (pop). PC1 is tied off on this die.

Load a program: cmd 2 with addr 0, then for each 16-bit word four cmd-0 nibbles (MSB first) and cmd 1. Push a TX word the same way, then cmd 3. Start SM0 with cmd 5 nibble `0001`. Capture on with nibble `0101`.

I2C is not raw bytes in the FIFO. Push `fw/i2c_master.encode_byte()` PINOE words (two per bit).
