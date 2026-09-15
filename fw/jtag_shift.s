; JTAG IDCODE. TCK=side1 TDI=0 TMS=3 TDO=2.
; TMS=1 x5 TLR, TMS 0,1,0,0 Shift-DR, 32 TCK TDI=0, two PUSH.
set     pindirs, 0xB
set     side_pin, 1
set     in_base, 2
set     x, 4
set     pins, 8  side 0
set     pins, 8  side 1
jmp     x--, tlr
set     pins, 0  side 0
set     pins, 0  side 1
set     pins, 8  side 0
set     pins, 8  side 1
set     pins, 0  side 0
set     pins, 0  side 1
set     pins, 0  side 0
set     pins, 0  side 1
set     x, 15
set     pins, 0  side 0
in      pins, 1  side 1
jmp     x--, sh0
push
set     x, 15
set     pins, 0  side 0
in      pins, 1  side 1
jmp     x--, sh1
push
jmp     park
