; -----------------------------------------------------------------------------
; Originally written by:
; Herb Johnson © 2012
; Operating and Testing the 1802 Membership Card
; https://www.retrotechnology.com/memship/mship_test.html
; -----------------------------------------------------------------------------
; Read the 8 data switches and display their complement on the 8 LEDs.
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L switches-leds-inv-and-q.asm
; p2hex switches-leds-inv-and-q.p switches-leds-inv-and-q.hex
; ```
; -----------------------------------------------------------------------------


; include the bit manipulation functions --------------------------------------
; This file defines a couple of bit-oriented functions that might be hardwired
; for other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function.     
; The source for `bitfuncs.inc` is provided to help port those functions to the
; assembler of your choice.


	include "bitfuncs.inc"


R0	EQU	0
R3	EQU	1

	; assumes P=0

	ORG	0

start:
	GLO	R0		; D=lo(RO), zero on reset
	PHI	R3		; R3 high byte = 0
	LDI	lo((tmp))	; set D=lower byte of the address of (tmp)
	PLO	R3		; R3=the address of (tmp)
	SEX	R3		; X->R3 
	INP	4		; read switches
	XRI	0FFH		; invert bits in D and M(R3)
	STR	R3		; save the result in M(R3)
	OUT	4		; write M(R3) to LEDs (increments R3)
	DEC	R3		; cancel increment with decrement
	BR	start		; go to start
tmp:
	DB	0

	END

