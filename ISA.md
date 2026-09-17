# ProtoEmu ISA (frozen)

16-bit instruction. PIO shared delay/side-set field. Not a pioasm clone.

```
[15:13] opcode
[12:8]  delay/side-set   SIDESET_COUNT=1: [12]=side, [11:8]=delay (0..15)
[7:0]   payload
```

`f_sm = f_sys / (INT + FRAC/256)` with INT=0 treated as 1 (every sysclk). Per SM. Not a second clock pipeline.

`{value, oe}` dest is **PINOE**: one OUT/MOV writes `OSR[7:0] -> pin_out` and `OSR[15:8] -> pin_oe` in one beat.

IMEM: 32 x 16 flop. Host and fetch index are 5 bits. JMP target is still payload[4:0] (0..31). Longer jumps are `MOV PC, X`. `jmp(32)` is illegal; bits[7:5] are only the condition. This die instantiates one SM (`PROTOEMU_SM1=0`). Capture is 32 live flop records `{pin, oe, hold}`; hold saturates in place; `replay_en` restores hold times. Peek 11–13 dump; peek 14 idx++; peek 15 rewind + `cap_mode` from shifter[0]. No IHP SRAM macro.

## Opcodes

| op | name | payload |
|---|---|---|
| 000 | JMP | [7:5] cond, [4:0] addr (0..31). cond 0 = always |
| 001 | WAIT | [7] polarity, [6:5] src (0 pin, 1 irq, 2 jmp_pin), [4:0] index |
| 010 | IN | [7:5] src, [4:0] bitcount (0 => 16) |
| 011 | OUT | [7:5] dest, [4:0] bitcount (0 => 16) |
| 100 | PUSH/PULL | [7] 1=PULL 0=PUSH, [6] ifF/ifE, [5] block |
| 101 | MOV | [7:5] dest, [4:3] op (0 copy, 1 invert, 2 bitrev), [2:0] src |
| 110 | IRQ | [7] clr, [6] wait, [2:0] index |
| 111 | SET | [7:5] dest, [4:0] imm |

JMP cond: 0 always, 1 !X, 2 X--, 3 !Y, 4 Y--, 5 PIN, 6 !OSRE, 7 X!=Y

IN src: 0 PINS, 1 X, 2 Y, 3 NULL, 4 ISR, 5 OSR, 6 STATUS, 7 PININ. PINS/PININ shift `count` consecutive pins from `in_base` (wrap 0..7) left into ISR in one beat.

OUT/MOV dest: 0 PINS, 1 X, 2 Y, 3 PINDIRS, 4 PINOE, 5 PC, 6 ISR, 7 NULL. OUT PINS writes `count` consecutive pins from pin0, LSB of OSR first. Side-set is re-applied after the op and wins on that pin.

MOV src: 0 PINS, 1 X, 2 Y, 3 NULL, 4 STATUS, 5 ISR, 6 OSR, 7 PINOE

SET dest: 0 PINS, 1 X, 2 Y, 3 PINDIRS, 4 IN_BASE, 5 SIDE_PIN

Side-set wins over OUT/SET on the same pin. Side-set fires on the first SM tick of an instruction, including WAIT stall. Delay counts after the op (or after WAIT is met).

NOP is `MOV Y, Y`.

I2C firmware does not put raw data bytes in the TX FIFO. The host pushes `fw/i2c_master.encode_byte()` PINOE words (two per bit: SCL driven 0, then SCL HiZ). ACK is a 9th SCL; `JMP PIN` (SDA, cond 5) STOPs on NAK and does a repeated START on ACK. Never drive SDA 1.

USB LS bit-layer TX is the same split: `fw/usb_ls.encode_packet()` emits PINOE beats (NRZI + bit-stuff + CRC-16/USB + EOP, then OE off). The SM is four words (`SET side_pin,7` / `PULL` / `OUT PINOE` / `JMP pull`). SYNC is loaded as LSB-first `0x80` (KJKJKJKK from idle J). D−=`uio[0]`, D+=`uio[1]`. Handshake PIDs have no CRC. The host never encodes NAK. Not a device, not HID, not FS/HS.

Program sizes that fit 32: UART TX 14, UART unrolled RX 12, UART frame RX 16, SPI mode-0 11, SPI JEDEC 19, I2C master 28, JTAG IDCODE 26, USB LS TX 4. SWD and PS/2 assemble but are unlabeled pin-dances. There is no `MOV OSR`; SPI JEDEC places the 8-bit reverse of `0x9F` in the TX low byte so LSB-first OUT is MSB-first on the wire, and still executes `MOV ISR, OSR, bitrev`.
