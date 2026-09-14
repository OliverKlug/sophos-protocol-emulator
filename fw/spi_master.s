; SPI master mode 0. MOSI=pin0 SCLK=side1 MISO=in_base2
set     pindirs, 3
set     side_pin, 1
set     in_base, 2
set     pins, 0  side 0
pull    block
set     x, 7
out     pins, 1  side 0
in      pins, 1  side 1
jmp     x--, $-2
push
jmp     pull
