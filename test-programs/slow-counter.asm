; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2024 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------
; The port of Kill the Bit game for Altair by Dean McDaniel, May 15, 1975. 
; <https://altairclone.com/downloads/killbits.pdf>
; -----------------------------------------------------------------------------
; Kill the rotating bit. If you miss the lit bit, another bit turns on, leaving
; two bits to destroy.
; Quickly toggle the correct switch on and off at the right moment.
; Don't leave the switch in the on position, or the game will pause.
; -----------------------------------------------------------------------------
; A slow counter in 10 bytes: EF 80 BF AF 9E 5F 1E 64 30 01" by Dave Ruske
; https://www.retrotechnology.com/memship/memship.html#soft
; -----------------------------------------------------------------------------
; I use [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be reasonably portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L slow-counter.asm
; p2hex slow-counter.p slow-counter.hex 
; ```
; The resulting `slow-counter.hex` file can be loaded into The 1802 Membership
; Card using monitor L command. On Linux, run `cat slow-counter.hex`, copy
; the output, and paste it to the monitor, then type the `R0000` command in the
; monitor or just toggle in CLEAR and RUN at the board :-).
; -----------------------------------------------------------------------------


	RELAXED	ON


R0	EQU	0
RE	EQU	14
RF	EQU	15

	SEX	RF	; make F register a memory pointer
loop:
	GLO	R0	; load the low part of R0 (0 after reset)
	PHI	RF	; put it to the high byte of RF
	PLO	RF 	; and to the low part of RF, RF is now 0000
	GHI	RE 	; load the high part of RE
	STR	RF 	; store it to location 0000
	INC	RE 	; increase RE
	OUT	4 	; display the result
	BR	loop 	; loop

