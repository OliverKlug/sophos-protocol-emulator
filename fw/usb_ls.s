; USB LS-shaped TX. NRZI-ish on pin0, SE0-ish pause. Not a PHY. No chirp.
set     pindirs, 3
pull    block
set     x, 7
out     pins, 1  delay 3
jmp     x--, $-1
set     pins, 0  delay 7
jmp     pull
