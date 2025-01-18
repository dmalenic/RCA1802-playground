; -----------------------------------------------------------------------------
; Originally written by:
; Herb Johnson © 2020
; Operating and Testing the 1802 Membership Card
; https://www.retrotechnology.com/memship/mship_test.html
; -----------------------------------------------------------------------------
; Read the 8 data switches and display their settings on the 8 LEDs.
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L switches-and-leds.asm
; p2hex switches-and-leds.p switches-and-leds.hex
; ```
; -----------------------------------------------------------------------------


	RELAXED	ON


; include the bit manipulation functions --------------------------------------
; This file defines a couple of bit-oriented functions that might be hardwired
; for other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function.     
; The source for `bitfuncs.inc` is provided to help port those functions to the
; assembler of your choice.


	INCLUDE "bitfuncs.inc"


R0	EQU	0
R1	EQU	1

	; assumes P=0

	ORG	0

start:
	SEX	1		; set X=1
	GHI	R0		; D=R0 high byte (i.e. 0)
	PHI	R1		; R1 high byte = 0
	LDI	lo(tmp)		; set D=lower byte of the address of (tmp)
	PLO	R1		; R1=the address of (tmp)
	INP	4		; read switches into D and M(R1)
	OUT	4		; write LEDs from M(R1) and increment R1
	BR	start		; go to start to reset R1 ad do it again
tmp:
	DB	0

	END

