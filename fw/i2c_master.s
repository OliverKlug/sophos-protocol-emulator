; I2C master. SDA=pin0 SCL=pin1. Host pushes encode_byte() PINOE words.
; Never drive 1: HiZ or drive 0. WAIT SCL=1 is stretch.
set     pindirs, 0
set     pindirs, 1       ; START: SDA 0, SCL HiZ
set     pins, 0
set     pindirs, 3       ; SCL 0
set     x, 7
pull    block            ; bit: SDA + SCL 0
out     pinoe, 16
pull    block            ; SDA + SCL HiZ
out     pinoe, 16
wait    1 pin 1          ; stretch
jmp     x--, bitloop
set     pindirs, 0
wait    0 pin 0          ; ACK
set     pindirs, 3       ; STOP
set     pins, 0
set     pindirs, 1
wait    1 pin 1
set     pindirs, 0
jmp     0
