; -----------------------------------------------------------------------------
; TEST ALU OPS
;
; This code snippet example is a diagnostic routine that tests
; ALU (Arithmetic and Logic Unit) Operations.
; https://en.wikipedia.org/wiki/RCA_1802#Code_samples
; http://www.cosmacelf.com/publications/books/short-course-in-programming.html#chapter5
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; This version is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L test-alu-ops.asm
; p2hex test-alu-ops.p test-alu-ops.hex
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


	INCLUDE	"bitfuncs.inc"


R0	EQU	0
R6	EQU	6

	ORG	0

	; Assumes P is 0
	; Set the initial condition as after reset

	GHI	R0		; Set up R6
	PHI	R6
	LDI	do_it		; For input of OPCODE
	PLO	R6
	SEX	0		; (X=0 already)
	OUT	4		; Announce us ready (Note: X=0)
	DB	0		; immediate value to display
	SEX	6		; Now X=6
	BN4	$		; Wait for it
	INP	4		; OK, get it
	OUT	4		; And echo to display
	B4	$		; Wait for release
	LDI	lo(op1)		; Now get ready for
	PLO	R6		;  the first operand
	SEX	0		; Say so
	OUT	4		; (Note X=0)
	DB	1		; immediate value to display
	BN4	$
	SEX	R6		; Take it
	INP	4		;    in to (op1)
	OUT	4		; Echo it and also increment R6
	B4	$
	SEX	0		; DITTO the second operand to (op2)
	OUT	4		; (Note X=0)
	DB	2		; immediate value to display
	SEX	6
loop:	BN4	$		; Wait for it
	INP	4		; Get it (Note: X=6)
	OUT	4		; Echo it
	B4	$		; Wait for release
	DEC	R6		; Back up R6 to (op1)
	DEC	R6
	LDA	R6		; Get the 1st operand to D
do_it:	NOP			; Do operation
	NOP			; (Spare)
	DEC	R6		; Back to (op1)
	STR	R6		; Output result
	OUT	4		; (X=6 still)
	REQ			; Turn off Q
	LBNZ	loop		; Then if Zero,
	SEQ			; Turn it on again
	BR	loop		; Repeat in any case

	ORG	0x60
op1:	DB	0		; the 1st operand
op2:	DB	0		; the 2nd operand

	END

