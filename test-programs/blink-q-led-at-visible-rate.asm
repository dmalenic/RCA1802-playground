; -----------------------------------------------------------------------------
; Originally written by:
; Herb Johnson © 2020
; Operating and Testing the 1802 Membership Card
; https://www.retrotechnology.com/memship/mship_test.html
; -----------------------------------------------------------------------------
; This program blinks Q slowly enough so you can see it.
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L blink-q-led-at-visible-rate.asm
; p2hex blink-q-led-at-visible-rate.p blink-q-led-at-visible-rate.hex
; ```
; -----------------------------------------------------------------------------


R1	EQU	1

	ORG	0

start:
	REQ			; reset Q
L0:
	LDI	10H		; load counter
	PHI	R1		;   into high R1
L1:
	; start of delay loop
	DEC	R1		; decrement R1
	GHI	R1		; load the high part of R1 into D
	BNZ	L1		; branch until the high part of R1 is zero
	; end of delay loop

	BQ	start		; if Q is set, go to start to reset it
				;   and do it all again
	SEQ			; otherwise, set Q
	BR	L0		; and branch to set the counter for a
				;   delay loop

	END

