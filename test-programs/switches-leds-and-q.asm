; -----------------------------------------------------------------------------
; Originally written by:
; Lee Hart © 2010
; Operating and Testing the 1802 Membership Card
; https://www.retrotechnology.com/memship/mship_test.html
; -----------------------------------------------------------------------------
; Read the 8 data switches, display their settings on the 8 LEDs, and pulses Q
; at a rate set by the switches. It tests the Membership Card's ability to read
; switches and write to the lights.
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L switches-leds-and-q.asm
; p2hex switches-leds-and-q.p switches-leds-and-q.hex
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
				;   (but we can ignore it in this program)
	SEQ			; set Q, at this point, D holds the value
				;   from switches
	SMI	1		; subtract memory immediate from D (D = D-1)
	BNZ	start		; branch if not zero to start,
				; (so this loops "switch" times)
	REQ			; reset Q
	BR	start		; go to start
tmp:
	DB	0

	END

