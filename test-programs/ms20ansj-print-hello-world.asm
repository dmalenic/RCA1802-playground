; -----------------------------------------------------------------------------
; Print `Hello, World.` using print routine from MS20ANSJ Monitor
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; This program is written for
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L ms20ansj-print-hello-world.asm
; p2hex ms20ansj-print-hello-world.p ms20ansj-print-hello-world.hex
; ```
; -----------------------------------------------------------------------------


	RELAXED ON


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
R2	EQU	2
R3	EQU	3
R4	EQU	4
R5	EQU	5
R6	EQU	6
R7	EQU	7
RB	EQU	11
RC	EQU	12
RE	EQU	14


	; assume invoked from MS20ANSJ monitor with 'R0000' 
	; P=0, X=0
	; R2            SCRT routines assume R2 is stack pointer
	; R3            SCRT routines assume R3 is program counter
	; R4=8ADB	points to SCRT call procedure
	; R5=8AED	points to SCRT return procedure
	; R6            stack for SCRT return addresses
	; R7		points to a string to be written by monitor routine on 8526
	; hi(RE)
	; 8526		the print string routine


	ORG	0


	; initialize R4 to 8ADBH and R5 to 8AEDH to enable SCRT
	LDI	0x8A
	PHI	R4
	PHI	R5
	LDI	0xDB
	PLO	R4
	LDI	0xED
	PLO	R5
	; initialize R6 to 0100H
	GHI	R0
	PLO	R6
	LDI	1
	PHI	R6

	; set R3 to main 
	LDI	lo(main)
	PLO	R3
	GHI	R0
	PHI	R3

	; pass the control to main
	SEX	R2
	SEP	R3			; this will call main, while R0 still
	; when SEP 0 is executed at the end of main, program will resume at this point

reset:					; following is the exit location
	SEX	R0			; restore X register like on reset
	LBR	monitor			; jump to monitor

main:
	GHI	R3
	PHI	R7
	LDI	lo(msg)
	PLO	R7

loop:
	; print the message
	SEP	R4
	DB	0x85
	DB	0x26

	; read user response
user_response:
	SEP	R4
	DB	0x80
	DB	0xA3
	; check if enter
	GHI	RB
	BZ	loop			; print message again
	; check if escape
	SMI	2
	BNZ	user_response		; not escape, let user enter response again

return_to_monitor:
	; return the control to monitor
	SEP	R0

msg:
	DB	"\r\n\x1B[7mHello, World.\x1B[0m\r\n..press ENTER to continue, or ESC and ENTER to return to the monitor\r\n\0"


	ORG	0x8000


monitor:
	END

