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

Peek select: 0 PC0, 1 X0, 2 Y0, 3 ISR0, 4 OSR0, 5 FIFO flags, 6 capture wptr (full byte), 7 pins, 8 PC1, 9 X1, 10 RX0 (pop), 11 cap pin, 12 cap oe, 13 cap hold, 14 dump_idx++, 15 rewind dump_idx and `cap_mode <= shifter[0]`. PC1 is tied off on this die.

Peek-10 pops RX0 on the strobe-rise posedge and `uo_out` holds that byte until the next posedge. Read it before another clock, or you sample the following FIFO word (empty → 0). Peek 11–13 have no side effect. Peek 14/15 do; do not sample `uo_out` on those strobes.

Load a program: cmd 2 with addr 0, then for each 16-bit word four cmd-0 nibbles (MSB first) and cmd 1. Push a TX word the same way, then cmd 3. Start SM0 with cmd 5 nibble `0001`. Capture on with nibble `0101`. Replay with nibble `1000` (SM halted). Set SPI SCLK-qualify mode with `shift16(1)` then peek 15 before arm. Capture and replay in the same nibble clears wptr. `replay_en` restores inclusive hold times. Halt commits the in-progress record.

I2C is not raw bytes in the FIFO. Push `fw/i2c_master.encode_byte()` PINOE words (two per bit). Halt (cmd 5 nibble 0) and rewrite IMEM to switch UART → SPI → I2C; 32 words will not hold all three at once.
