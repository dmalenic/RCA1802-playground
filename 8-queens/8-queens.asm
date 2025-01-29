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
; asl -cpu 1802 -L 8-queens.asm
; p2hex 8-queens.p 8-queens.hex
; ```
; -----------------------------------------------------------------------------
; Register convention imposed by monitor:
; R0 - reset program counter and SP, PC and SP for user program invoked with 'R' command, DMA memory pointer
; R1 - interrupt program counter
; R2 - stack pointer for main and interrupt routines
; R3 - program counter for main routine
; R4 - program counter for SCRT subroutine calls
; R5 - program counter for SCRT subroutine returns
; R6 - SCRT return address stack
; R7 - a pointer to a string to be written when invoking 8526
; RB.HI - holds the input character classification
; RB.LO - holds the input character, or the output character
; RE.HI - holds 01
; RE.LO - holds the baud rate indicator
; -----------------------------------------------------------------------------
; Monitor Routines Used in This Program
; 8000 - the entry point, waits till IN is released and then jumps to 8B00 for real entry point
; 8005 - reads a character
; 80A3 - reads a character and classifies it as:
;        00 - CR, 1 - space, 02 - ESC, 03 - digit, 04 - hex-letter or FF -  other
; 8513 - writes a sequence ' ', CR, LF on the screen
; 8519 - writes a sequence CR, LF on the screen (part of 8513 but sometimes called separately)
; 8526 - writes a string to the screen, R7 points to the string, R7 is preserved
; 859B - writes ' ' on the screen
; 8ADB - SCRT call a subroutine (invoked with R4 as PC)
; 8AED - SCRT return from a subroutine (invoked with R5 as PC)
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


	ORG	0


	; -----------------------------------------------------------------------------
	; Initialize the program
	; -----------------------------------------------------------------------------
	; When started after reset, or by executing the monitor R command:
	; R0 is set to be both the program counter and the stack pointer
	; R1 is  pointer.
	; R2 is will become stack pointer in a case of an interrupt
	; Following section configures the registers:
	; R2 to point to the area that will become a stack pointer when control is passed to main
	; R3 to point to main, it will become a program counter
	; R4 will point to SCRT call routine
	; R5 will point to SCRT return routine
	; R6 will point to SCRT stack
start:
	; initialize R4 to 0x8ADB and R5 to 0x8AED to enable SCRT
	LDI	hi(scrt_call)
	PHI	R4
	PHI	R5
	LDI	lo(scrt_call)
	PLO	R4
	LDI	lo(scrt_return)
	PLO	R5
	; initialize R6 to SCRT_stack
	LDI	hi(scrt_stack)
	PHI	R6
	LDI	lo(scrt_stack)
	PLO	R6

	; configure R3 to point to the main
	LDI	lo(main)
	PLO	R3
	GHI	R0
	PHI	R3

	; configure R2 to point to the stack
	LDI	hi(stack)
	PHI	R2
	LDI	lo(stack)
	PLO	R2

	; pass the control to main
	SEX	R2			; R2 is the stack pointer
	SEP	R3			; this will call main, while R0 still

	; -----------------------------------------------------------------------------
	; The program exit point
	; -----------------------------------------------------------------------------
	; R0 is pointing to this location so when SEP 0 is executed at the end of main,
	; the program execution will resume at this point
	SEX	R0			; restore X register like on reset
	LBR	monitor			; jump to monitor

	; -----------------------------------------------------------------------------
	; The main routine
	; -----------------------------------------------------------------------------
	; System registers
	; R0 - DMA memory pointer
	; R1 - interrupt PC
	; R2 - SP/interrupt SP
	; R3 - PC
	; R4 - SCRT call PC
	; R5 - SCRT return PC
	; R6 - SCRT SP
	; Code registers
	; R7 - reserved for pointing to messages
	; R8 - points to chessboard row0
	; R9 - points to current row
main:
	;



	; -----------------------------------------------------------------------------
	; Print the result
	; -----------------------------------------------------------------------------
	; Registers convention used by this application:
	; R8 - points to the current row
	; R9.HI - the number of chessboard fields in the current row to print
	; R9.LO - the working copy of the current chessboard row content
	; RA.HI - the number of rows to print
	; RA.LO - indicator if the current print is black or white
print_board:
	LDI	8			; number or chessboard rows to print
	PHI	RA			; store it to RA.HI
	LDI	hi(row1)		; get address of the first row
	PHI	R8
	LDI	lo(row1)
	PLO	R8			; R8 points to the first row
print_row:
	SEP	R4			; print row, on return R8 will point to the next row
	DB	hi(print_current_row)
	DB	lo(print_current_row)
	GHI	RA
	SMI	1
	PHI	RA
	BNZ	print_row
	; inform an end-user to press Enter to return to monitor
	LDI	lo(enter_to_ret)
	PLO	R7
	LDI	hi(enter_to_ret)
	PHI	R7
	SEP	R4
	DB	hi(puts)
	DB	lo(puts)

	; -----------------------------------------------------------------------------
	; return the control to monitor
	; -----------------------------------------------------------------------------
return_to_monitor:
	SEP	R0


check_if_valid_position_ret:
	SEP	R5
check_if_valid_position:
	BR 	check_if_valid_position_ret


print_current_row:
	; load page holding strings representing board content to R7 hi, R7 low will depend on content to print
	LDI	hi(board_ptr_strs)
	PHI	R7
	; initialize field counter, row pointer, black-white indicator
	LDI	8	; 8 chessboard fields in a row
	PHI	R9	; R9.HI holds a number of chessboard fields in a row to print
	LDA	R8	; R8 points to the next row
	PLO	R9	; R9.LO holds ca working opy of the current row
	GLO	R8	; odd or even row, odd rows start with a white cell
	ANI	01	; is even or odd? row
	PLO	RA	; store this info in RA
	BZ	print_current_field	; if even skip sending invert video esc sequence
print_esc_inv:
	; print invert video escape sequence
	LDI	hi(esc_inv)
	PHI	R7
	LDI	lo(esc_inv)
	PLO	R7
	SEP	R4
	DB	hi(puts)
	DB	lo(puts)
print_current_field:
	; determine the current field content depending if corresponding row bit is 1 (queen) or zero (empty field)
	GLO	R9		; get a working copy of the current row
	SHL			; shift D left putting msb in the DF
	PLO	R9		; store new state of the working copy of the current row
	BDF	print_queen	; if msb was 1 the field contains the queen
	; get string representing an empty field into R7
	LDI	lo(field)
	PLO	R7
	BR	print_field_content
print_queen:
	; get string representing a field with queen into R7
	LDI	lo(queen)
	PLO	R7
print_field_content:
	; print the current field
	SEP	R4
	DB	hi(puts)
	DB	lo(puts)
	; undo the inverse video and bold-face font if either or both were set by printing norm esc sequence
	LDI	lo(esc_norm)
	PLO	R7
	SEP	R4
	DB	hi(puts)
	DB	lo(puts)
print_next_field:
	; prepare for printing the next field
	GHI	R9		; get number of fields to print in the current row
	SMI	1		; subtract 1
	BZ	print_crlf_and_ret	; if the result is 0 print <CR><LF> and jump to subroutine return code sequence
	PHI	R9		; store the calculated number of fields to print
	GLO	RA		; get withe-black field indicator
	XRI	1		; invert it
	PLO	RA		; store the result
	BZ	print_current_field	; if black go to printing a field content
	BR	print_esc_inv	; if white, go to printing video invert esc sequence
print_crlf_and_ret:
	; print <CR><LF> sequence
	LDI	hi(crlf)
	PHI	R7
	LDI	lo(crlf)
	PLO	R7
	SEP	R4
	DB	hi(puts)
	DB	lo(puts)
	; go to SCRT returning from a subroutine sequence
	SEP	R5


	ORG	0x0100
	; -- rows
row1:	DB	0b10000000
row2:	DB	0b00010000
row3:	DB	0b01000000
row4:	DB	0b00000001
row5:	DB	0b00001000
row6:	DB	0b00000010
row7:	DB	0b00100000
row8:	DB	0b00000100

board_ptr_strs:
esc_inv:	DB	"\x1B[7m\0"
esc_norm:	DB	"\x1B[0m\0"
queen		DB	"\x1B[1m Q \x1B[2m\0"
field		DB	"   \0"
crlf		DB	"\r\n\0"
enter_to_ret	DB	"\r\nPress ENTER to return to Monitor\r\n\0"

	ORG	0x017F		; SCRT stack is from 0x017F..0x0100
scrt_stack:

	ORG	0x01FF		; R2 stack is from 0x01FF..0x0180
stack:


	ORG	0x8000
monitor:

	ORG	0x8526
puts:

	ORG	0x8ADB
scrt_call:

	ORG	0x8AED
scrt_return:
