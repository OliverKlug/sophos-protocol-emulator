; SWD write bits then PINOE turnaround (HiZ SWDIO).
set     side_pin, 1
set     pindirs, 3
pull    block
set     x, 7
out     pins, 1  side 0
out     pins, 1  side 1
jmp     x--, $-2
out     pinoe, 16
jmp     pull
