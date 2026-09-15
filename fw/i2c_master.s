; I2C master. SDA=pin0 SCL=pin1. Host pushes encode_byte() PINOE words.
; Never drive 1: HiZ or drive 0. WAIT SCL=1 is stretch.
; 9th SCL is ACK. JMP PIN (SDA): NAK -> STOP, ACK -> repeated START.
set     pindirs, 0
set     pins, 0          ; pin_out 0 before OE (leftover MOSI)
set     pindirs, 1       ; START: SDA 0, SCL HiZ
set     pindirs, 3       ; SCL 0
set     x, 7
pull    block            ; bit: SDA + SCL 0
out     pinoe, 16
pull    block            ; SDA + SCL HiZ
out     pinoe, 16
wait    1 pin 1          ; stretch
jmp     x--, bitloop
set     pindirs, 2       ; ACK: SCL 0, SDA HiZ
set     pindirs, 0       ; SCL HiZ
wait    1 pin 1
jmp     pin, stop        ; NAK if SDA=1
set     pindirs, 2       ; SCL 0, slave releases ACK
set     pindirs, 0       ; both HiZ
set     pindirs, 1       ; Sr: SDA fall while SCL HiZ
set     pins, 0
set     pindirs, 3
set     x, 7
jmp     bitloop
stop:
set     pindirs, 3
set     pins, 0
set     pindirs, 1
wait    1 pin 1
set     pindirs, 0
jmp     park
