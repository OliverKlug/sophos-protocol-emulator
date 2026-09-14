; JTAG shift. TDI=0 TCK=side1 TDO=2 TMS=3
set     pindirs, 0xB
set     side_pin, 1
set     in_base, 2
pull    block
set     x, 7
out     pins, 1  side 0
in      pins, 1  side 1
jmp     x--, $-2
push
jmp     pull
