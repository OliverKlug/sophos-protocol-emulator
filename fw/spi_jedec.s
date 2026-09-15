; SPI JEDEC 0x9F. CS=3 MOSI=0 SCLK=side1 MISO=2. MOV bitrev, 32 clocks.
set     pindirs, 0xB
set     side_pin, 1
set     in_base, 2
set     pins, 8          ; CS high
pull    block
mov     osr, osr, bitrev
set     pins, 0          ; CS low
set     x, 15
out     pins, 1  side 0
in      pins, 1  side 1
jmp     x--, $-2
push
set     x, 15
out     pins, 1  side 0
in      pins, 1  side 1
jmp     x--, $-2
push
set     pins, 8          ; CS high
jmp     pull
