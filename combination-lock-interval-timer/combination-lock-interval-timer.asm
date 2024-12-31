; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2024 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```   
; asl -cpu 1802 -L combination-lock-interval-timer.asm
; p2hex combination-lock-interval-timer.p combination-lock-interval-timer.hex
; ```
; -----------------------------------------------------------------------------


	ORG	0

; register aliases
R0	EQU	0
R1	EQU	1
R2	EQU	2
R3	EQU	3
R4	EQU	4
R5	EQU	5
R6	EQU	6
R7	EQU	7
R8	EQU	8
R9	EQU	9
RA	EQU	10
RB	EQU	11
RC	EQU	12
RD	EQU	13
RE	EQU	14
RF	EQU	15

start:
	; combination-lock initialization -------------------------------------
	REQ			; Q is low
	LDI	(tmp)		; Initialise Reg D as an output pointer
	PLO	RD		; RD.0 = address(tmp)
	LDI	0		; Initialize Reg E and F for use as control
	PLO	RF		;
	PHI	RF		; RF=0000H
	PLO	RE		;
	PHI	RE		; RE=0000H
	PHI	RD		; RD=(tmp)

	SEX	RD		; X=DH

	; initialize display to "00"
	LDI	0		; Load message "00" 
	STR	RD		;   to (tmp)
	OUT	4		; Output the message from (tmp), RD++
	DEC	RD		; RD-- to restore RD
	; input and test the first combination digit --------------------------
	BN4	$		; Loop until IN is pressed
	B4	$		; Loop until IN is released
	INP	4		; Read the switches into (tmp)
	XRI	0CAH		; Check if byte 1 is correct
	BNZ	error_sub	; No, display error
	; input and test the second combination digit -------------------------
	BN4	$		; Loop until IN is pressed
	B4	$		; Loop until IN is released
	INP	4		; Read the switches into (tmp)
	XRI	0FEH		; Check if byte 2 is correct
	BNZ	error_sub	; No, display error
	; input and test the third combination digit --------------------------
	BN4	$		; Loop until IN is pressed
	B4	$		; Loop until IN is released
	INP	4		; Read the switches into (tmp)
	XRI	42H		; Check if byte 3 is correct
	BNZ	error_sub	; No, display error
	; all bytes are ok, activate the timer --------------------------------

interval_timer:
	; timer initialization ------------------------------------------------
	SEQ			; set Q
loop_param:
	; load immediately the predetermined value that defines the looping interval
	LDI	0FH		; Predetermined value to compare RF against
	STR	RD		; Store it in the memory location pointed by RD
	OUT	4		; Output memory location pointed by RD, RD++
	DEC	RD		; RD-- to restore RD
	; the interval loop ---------------------------------------------------
loop:
	DEC	RE		; Decrement timer
	GHI	RE		; Load timer hi-byte
	BNZ	loop		; Check timer hi-byte, continue loop if not 0
	GLO	RE		; Load timer lo-byte
	BNZ 	loop		; Check timer lo-byte, continue loop if not 0
	INC	RF		; If the low byte is zero, increment the
				;   workspace register by one
	GLO	RF		; Get new value from the register
	XOR			; Exclusive OR with predetermined value
	BNZ	loop		; Check if RF is 2; continue loop if not
	; end of the interval loop --------------------------------------------
time_has_elapsed:
	REQ			; reset Q
	; determine what to do next -------------------------------------------
	BN4	$		; Loop until IN is pressed
	B4	$		; Loop until IN is released
	INP	4		; Read the switches into (tmp)
	GLO	RF		; RF has the displayed value
	XOR			; Exclusive OR with (tmp)
	BNZ	start		; If it does not match, run the program again
				; otherwise fall through to the Monitor program
	; following emulates Reset --------------------------------------------
	SEP	0		; Reset P pointer
	SEX	0		; Reset X pointer
	LBR	monitor		; Go to ROM
	; End	

error_sub:
	LDI	0EEH		; Load message "EE"
	STR	RD		; Store it to (tmp)
	OUT	4		; Output the message from (tmp), RD++
	PHI	RF		; Also, put it into the high part of R4
	DEC	RD		; RD-- to restore RD
loop_ee:
	DEC	RF		; Decrement R4
	GHI	RF		; Loadi the hi part of R4
	BNZ	loop_ee		; Continue the loop if it is not 0
	BR	start		; Go to start
tmp:	DB	00H

	ORG	8000H
monitor:

