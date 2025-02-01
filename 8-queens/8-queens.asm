; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2025 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------
; 8 Queen Problem
; The program to find all 92 solutions for the
; [8 Queen Problem](https://en.wikipedia.org/wiki/Eight_queens_puzzle)
; and prints them to the connected console.
; -----------------------------------------------------------------------------
; The program is written for 1802 Membership Card revision L1 running Chuck
; Yakym's MS20ANSJ Monitor v2.0JR (10 Jul 2024) located at address 0x8000.
;
; It is assembled using
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L 8-queens.asm
; p2hex 8-queens.p 8-queens.hex
; ```
; -----------------------------------------------------------------------------
; Register convention imposed by the integration with Chuck's monitor:
; R0 - reset program counter and SP, PC and SP for user program invoked with
;      'R' command, DMA memory pointer
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
; RF.HI - used by SCRT call and return subroutines to preserve the value of D
;         register between caller and callee
; -----------------------------------------------------------------------------
; Monitor routines used by this program (routine names are mine)
; 8000 - `monitor` entry point
; 80A3 - `mon_get_ch` reads a character and classifies it as:
;        00 - CR, 1 - space, 02 - ESC, 03 - digit, 04 - hex-letter or FF - other
; 8526 - `mon_put_str` writes a string to the screen. R7 points to the string.
;        R7 is preserved after the call.
; 8ADB - SCRT call a subroutine (invoked with R4 as PC)
; 8AED - SCRT return from a subroutine (invoked with R5 as PC)
; -----------------------------------------------------------------------------


; enable C style numeric constants --------------------------------------------


	RELAXED	ON

	CPU	1802


; include the bit manipulation functions --------------------------------------
; This file defines a couple of bit-oriented functions that might be hardwired
; when using other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function. $ is the synonym for the current PC address.
; The source for `bitfuncs.inc` is provided to help port those functions to the
; assembler of your choice.


	INCLUDE "bitfuncs.inc"


; register aliases ------------------------------------------------------------
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
code:

	; -----------------------------------------------------------------------------
	; Initialize the program
	; -----------------------------------------------------------------------------
	; When started after reset, or by executing the monitor R0000 command:
	; R0 is set to be both the program counter and the stack pointer
	; R1 is  pointer.
	; R2 is will become stack pointer in a case of an interrupt
	; Following section configures the registers:
	; R2 to point to the area that will become a stack pointer when control is passed to main
	; R3 to point to main, it will become a program counter
	; R4 will point to SCRT call routine
	; R5 will point to SCRT return routine
	; R6 will point to SCRT stack
	; -----------------------------------------------------------------------------
start:
	; initialize R4 to 0x8ADB and R5 to 0x8AED to enable SCRT
	LDI	hi(mon_scrt_call)
	PHI	R4
	PHI	R5
	LDI	lo(mon_scrt_call)
	PLO	R4
	LDI	lo(mon_scrt_return)
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
	SEX	R2			; Make R2 the default index register i.e. stack pointer
	SEP	R3			; this will call main, while R0 still

	; -----------------------------------------------------------------------------
	; The program exit point
	; -----------------------------------------------------------------------------
	; R0 is pointing to this location so when SEP 0 is executed at the end of main,
	; the program execution will resume at this point
	SEX	R0			; Make R0 default index register like on reset
	LBR	monitor			; jump to monitor

	; -----------------------------------------------------------------------------
	; The main routine
	; -----------------------------------------------------------------------------
main:
	; initialize
	LDI	hi(rows)		; get address of the first row
	PHI	R8			; initialize page address for all variable pointers
	LDI	lo(rows)		; get address of the first row
	PLO	R8			; R8 points to the first row

	; set the initial values for the first recursive call
	LDI	0x80			; initial cell of the first row
	STR	R8			; store it to the memory
	LDI	8			; number of rows to process
	PHI	RA			; store it to RA.HI
	LDI	0			; the first row is the current row
	PLO	RA			; RA.LO holds the current row

	; call the recursive routine to find 8-queen positions
	SEP	R4
	DB	hi(find_pos)
	DB	lo(find_pos)

	; no_more_solutions or user has cancelled the process, print the appropriate
	; message to ask a user to press <ENTER> to return to monitor
no_more_solutions:
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(no_more_sols)
	DB	lo(no_more_sols)

	; -----------------------------------------------------------------------------
	; return the control to the program exit point
	; -----------------------------------------------------------------------------
	SEP	R0


	; -----------------------------------------------------------------------------
	; Find position
	; -----------------------------------------------------------------------------
	; Routine specific register usage:
	; Input:
	; R8 - points to current row representation
	; RA.HI - holds number of rows to process
	; RA.LO - the current row index
	; RB - user interaction
	; Output:
	; RF.LO - 1 if position found, 0 if not
	; -----------------------------------------------------------------------------
find_pos:
	; test if all 8 rows have been successfully processed?
	GLO	RA			; get current row value and check if it is 8?
	SDI	8			; D = 8 - D i.e. will be 0 if all rows are processed
	BNZ	find_pos_proc_row	; if it is not the last row, continue processing current row

	; last row processed - print the solution
	SEP	R4
	DB	hi(print_board)
	DB	lo(print_board)

	; inform and ask a user to press <ENTER> to look for the next solution or <ESC> to return to monitor
find_user_response:
	; write message to the user
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(next_or_exit)
	DB	lo(next_or_exit)

	; read user's response, on return, RB.HI will be 0 for <ENTER> or 2 for <ESC>
	SEP	R4
	DB	hi(mon_get_ch)
	DB	lo(mon_get_ch)

	; check if <ENTER>
	GHI	RB			; RB.HI is 0 if user pressed <ENTER>
	BZ	find_pos_ret		; return to the previous level look for the next solution

	; check if <ESC>
	SMI	2			; if ESC was pressed RB.HI
	BNZ	find_user_response	; not the <ESC> key, invalid input let user try again
	LBR	no_more_solutions	; drop from all recursive calls and return to monitor

	; process current row
find_pos_proc_row:
	; check if the queen at current position in the current row is attacking any other queen
	SEP	R4			; test if attacking a queen in the same column
	DB	hi(test_col)
	DB	lo(test_col)
	GLO	RF
	BZ	find_next_pos_in_row	; yes - try the next position
	SEP	R4			; test if attacking a queen in the up-left diagonal
	DB	hi(test_left_diag)
	DB	lo(test_left_diag)
	GLO	RF
	BZ	find_next_pos_in_row	; yes - try the next position
	SEP	R4			; test if attacking a queen in the up-right diagonal
	DB	hi(test_right_diag)
	DB	lo(test_right_diag)
	GLO	RF
	BZ	find_next_pos_in_row	; yes - try the next position

	; no - found a safe position for the current row, move to next row recursively
	INC	R8			; move the current row state pointer to the next row
	LDI	0x80			; define the initial state for the next row
	STR	R8			; and store it
	INC	RA			; increase the current row indicator
	SEP	R4			; call recursively the routine to find the valid position in a new row
	DB	hi(find_pos)
	DB	lo(find_pos)
	DEC	RA			; on return restore the current row indicator
	DEC	R8			; and restore the pointer to current row state

	; try the next position in the current row if the current row is not exhausted
find_next_pos_in_row:
	LDN	R8			; get row state
	SHR				; next row state
	STR	R8			; save new row state
	BNF	find_pos_proc_row	; if it is not 0 after rotation, the stat is valid and loop to test it
	; otherwise return back to the previous row

find_pos_ret:
	SEP	R5			; return from the subroutine


	; ---------------------------------------------------------------------
	; Test if attacking any other queen in the current column
	; ---------------------------------------------------------------------
	; Routine specific register usage:
	; Input:
	; R8 - points to current state row representation
	; RA.LO - indicates the current row number
	; Output:
	; RF.LO - 1 if not attacking any other queen in the current column, 0 otherwise
	; Internal usage (values preserved):
	; RA.HI - the working copy of the the test mask
	; R8 - points to row we test against
	; D and DF are not preserved
	; ---------------------------------------------------------------------
test_col:
	; save the registers that may be modified
	GHI	RA			; save RA on stack
	STXD
	GLO	RA
	STXD
	GHI	R8			; save R8 on stack
	STXD
	GLO	R8
	STXD

	; initialize the test
	SEX	R8			; make R8 a temporary SP
	LDI	1			; assume the positive result
	PLO	RF
	LDN	R8			; take the current row state
	PHI	RA			; preserve it in RA.HI as the test mask

	; testing loop
test_col_loop:
	GLO	RA			; are we in the top row?
	BZ	test_col_ret		; yes, then we are done
	DEC	R8			; otherwise point to the previous row
	DEC	RA			; decrease testing row counter
	GHI	RA			; get the test mask
	AND				; check if it overlaps with the testing row state
	BZ	test_col_loop		; no, proceed to test with the row above
	LDI	0			; yes, the test has failed
	PLO	RF			; so indicate the negative result in the return value

	; restore to the state before the call
test_col_ret:
	SEX	R2			; restore the stack pointer to R2
	IRX				; drop SP to point the saved registers
	LDXA				; restore R8
	PLO	R8
	LDXA
	PHI	R8
	LDXA				; restore RA
	PLO	RA
	LDX
	PHI	RA
	SEP	R5			; return


	; ---------------------------------------------------------------------
	; Test if attacking any other queen in the up-left diagonal
	; ---------------------------------------------------------------------
	; Routine specific register usage:
	; Input:
	; R8 - points to current state row representation
	; RA.LO - indicates the current row number
	; Output:
	; RF.LO - 1 if not attacking any other queen in the diagonal, 0 otherwise
	; Internal usage (values preserved):
	; RA.HI - the working copy of the the test mask
	; R8 - points to row we test against
	; D and DF are not preserved
	; ---------------------------------------------------------------------
test_left_diag:
	; save the registers that may be modified
	GHI	RA			; save RA on stack
	STXD
	GLO	RA
	STXD
	GHI	R8			; save R8 on stack
	STXD
	GLO	R8
	STXD

	; initialize the test
	SEX	R8			; make R8 a temporary SP
	LDI	0			; make sure DF is 0 so we test only one position per row
	SHL
	LDI	1			; assume the positive result
	PLO	RF
	LDN	R8			; take current row state
	PHI	RA			; preserve it in RA.HI as the initial test mask

	; testing loop
test_left_diag_loop:
	GLO	RA			; are we in the top row?
	BZ	test_left_diag_ret	; yes, then we are done
	DEC	R8			; no, point to the previous row
	DEC	RA			; decrease testing row counter
	GHI	RA			; get the test mask
	SHL				; shift mask left
	BDF	test_left_diag_ret	; if shifted out of the board we are done
	PHI	RA			; preserve the test maks for the next iteration
	AND				; check if it overlaps with the testing row state
	BZ	test_left_diag_loop	; no, proceed to test with the row above
	LDI	0			; yes, the test has failed
	PLO	RF			; so indicate the negative result in the return value

test_left_diag_ret:
	; restore to the state before the call
	SEX	R2			; restore the stack pointer
	IRX				; drop SP to point the saved registers
	LDXA				; restore R8
	PLO	R8
	LDXA
	PHI	R8
	LDXA				; restore RA
	PLO	RA
	LDX
	PHI	RA
	SEP	R5			; return


	; ---------------------------------------------------------------------
	; Test if attacking any other queen in the up-right diagonal
	; ---------------------------------------------------------------------
	; Routine specific register usage:
	; Input:
	; R8 - points to current state row representation
	; RA.LO - indicates the current row number
	; Output:
	; RF.LO - 1 if not attacking any other queen in the diagonal, 0 otherwise
	; Internal usage (values preserved):
	; RA.HI - the working copy of the the test mask
	; R8 - points to row we test against
	; D and DF are not preserved
	; ---------------------------------------------------------------------
test_right_diag:
	GHI	RA			; save RA on stack
	STXD
	GLO	RA
	STXD
	GHI	R8			; save R8 on stack
	STXD
	GLO	R8
	STXD

	; initialize the test
	SEX	R8			; make R8 a temporary SP
	LDI	0			; make sure DF is 0 so we test only one position per row
	SHR
	LDI	1			; assume the positive result
	PLO	RF
	LDN	R8			; take current row state
	PHI	RA			; preserve it in RA.HI as the initial test mask

	; testing loop
test_right_diag_loop:
	GLO	RA			; are we in the top row?
	BZ	test_right_diag_ret	; yes, then we are done
	DEC	R8			; no, point to the previous row
	DEC	RA			; decrease testing row counter
	GHI	RA			; get the test mask
	SHR				; shift mask right
	BDF	test_right_diag_ret	; if shifted out of board we are done
	PHI	RA			; preserve the test maks for the next iteration
	AND				; check if it overlaps with the testing row state
	BZ	test_right_diag_loop	; no, proceed to test with the row above
	LDI	0			; yes, the test has failed
	PLO	RF			; so indicate the negative result in the return value

test_right_diag_ret:
	; restore to the state before the call
	SEX	R2			; restore the stack pointer
	IRX				; drop SP to point the saved registers
	LDXA				; restore R8
	PLO	R8
	LDXA
	PHI	R8
	LDXA				; restore RA
	PLO	RA
	LDX
	PHI	RA
	SEP	R5			; return


	ORG	0x0100

	; -----------------------------------------------------------------------------
	; Print the result
	; -----------------------------------------------------------------------------
	; Routine specific register usage:
	; Input registers: none
	; Output registers: none
	; Internal usage (values preserved):
	; R8 - points to the current row
	; R9.LO - the working copy of the current chessboard row content
	; RA.HI - the number of rows to print
	; D and DF are not preserved
	; -----------------------------------------------------------------------------
print_board:
	; preserve R8, R9.LO, RA.HI
	GHI	R8
	STXD
	GLO	R8
	STXD
	GLO	R9
	STXD
	GLO	RA
	STXD

	; initialize printing
	LDI	8			; number or chessboard rows to print
	PHI	RA			; store it to RA.HI
	LDI	hi(rows)		; get address of the first row
	PHI	R8
	LDI	lo(rows)
	PLO	R8			; R8 points to the first row

	; print the header row
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(hdr_row)
	DB	lo(hdr_row)

	; the row printing loop
print_row:
	; print a current row content
	SEP	R4			; print row, on return R8 will point to the next row
	DB	hi(print_current_row)
	DB	lo(print_current_row)
	GHI	RA			; get the number of rows to process
	SMI	1			; decrease it
	PHI	RA			; preserve the value
	BNZ	print_row		; if it is no 0 continue with the next row

	; restore RA.LO, R9.LO, R8
	IRX				; drop SP to point the saved registers
	LDXA
	PLO	RA
	LDXA
	PLO	R9
	LDXA
	PLO	R8
	LDX
	PHI	R8
	; return
	SEP	R5


	; -----------------------------------------------------------------------------
	; Print current chessboard row
	; -----------------------------------------------------------------------------
	; Routine specific register usage:
	; Input:
	; R8 - points to the current row
	; Output:
	; R8 - points to the next row
	; Internal usage (values preserved):
	; R7 - points to a string to be printed using monitor routine at 0x8526
	; R9.HI - the number of (remaining) chessboard fields in the current row to print
	; R9.LO - working copy of the current row content
	; RA.LO - indicator if the current print is black or white
	; RB.LO - a character to print using `mon_put_ch`
	; -----------------------------------------------------------------------------
print_current_row:
	; preserve R7, R9, RA.LO, RB.LO
	GHI	R7
	STXD
	GLO	R7
	STXD
	GHI	R9
	STXD
	GLO	R9
	STXD
	GLO	RA
	STXD
	GLO	RB
	STXD

	; print row number
	GHI	RA		; load remaining number of rows to print into D
	SDI	'9'		; D = '9' - D, subtract current row number from '9'
	PLO	RB		; put result in RB.LO for printing
	SEP	R4		; invoke mon_put_ch routine to print the character in RB.LO
	DB	hi(mon_put_ch)
	DB	lo(mon_put_ch)

	; print a space between the row number and the first field
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(row_start)
	DB	lo(row_start)

	; initialize the field counter, row pointer, black-white indicator
	LDI	8	; 8 chessboard fields in a row
	PHI	R9	; R9.HI holds a number of chessboard fields in a row to print
	LDA	R8	; Load content of the current row then make R8 points to the next row
	PLO	R9	; R9.LO holds ca working copy of the current row
	GLO	R8	; Test if it is an odd or an even row? The odd rows start with a white cell.
	ANI	01	; Is it even or odd row?
	PLO	RA	; Store this info in RA.LO so we can invert it for the next iteration
	BZ	print_current_field	; If it is an even row skip sending invert video esc sequence

	; print invert video escape sequence
print_esc_inv:
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(esc_inv)
	DB	lo(esc_inv)

	; print the current field
print_current_field:
	; load page holding strings representing board content to R7.HI, R7.LO will depend on content to print
	LDI	hi(field)
	PHI	R7

	; determine the current field content depending if the corresponding row bit is 1 (a queen) or 0 (an empty field)
	GLO	R9		; get the working copy of the current row
	SHL			; shift D left putting msb in the DF
	PLO	R9		; store the new state of the working copy of the current row for the next iteration
	BDF	print_queen	; if the DF is 1 the field contains the queen

	; get string representing an empty field into R7
	LDI	lo(field)
	PLO	R7
	BR	print_field_content

	; get string representing a field with queen into R7
print_queen:
	LDI	lo(queen)
	PLO	R7

	; print the current field
print_field_content:
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; undo the inverse video and bold-face font if either or both were set by printing norm esc sequence
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(esc_norm)
	DB	lo(esc_norm)

	; prepare for printing the next field
print_next_field:
	GHI	R9		; get the number of fields to print in the current row
	SMI	1		; decrease it
	BZ	print_crlf_and_ret	; if the result is 0 print <CR><LF> and return
	PHI	R9		; otherwise preserve the number of fields left to print for the next iteration
	GLO	RA		; get the black-white field indicator
	XRI	1		; invert it
	PLO	RA		; and preserve the result for the next iteration
	BZ	print_current_field	; if it was black go to directly printing a field content
	BR	print_esc_inv	; if it was white, go to printing video invert esc sequence first

	; print <CR><LF> sequence
print_crlf_and_ret:
	SEP	R4
	DB	hi(put_str)
	DB	lo(put_str)
	DB	hi(row_end)
	DB	lo(row_end)

	; restore RB.LO, RA.LO, R9, R7
	IRX
	LDXA
	PLO	RB
	LDXA
	PLO	RA
	LDXA
	PLO	R9
	LDXA
	PHI	R9
	LDXA
	PLO	R7
	LDX
	PHI	R7
	; return
	SEP	R5


	; -----------------------------------------------------------------------------
	; The wrapper for `mon_put_str` to enable passing string address inline with
	; a subroutine call
	; -----------------------------------------------------------------------------
	; Internal usage (values preserved):
	; R7 - hold pointer to the string when invoking the `mon_put_str` routine
	; -----------------------------------------------------------------------------
put_str:
	; preserve R7 register
	GHI	R7
	STXD
	GLO	R7
	STXD

	; load inline string address into R7
	LDA	R6
	PHI	R7
	LDA	R6
	PLO	R7

	; call mon_put_str routine from the monitor that expects R7 to point to the string
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; restore R7 register
	IRX
	LDXA
	PLO	R7
	LDX
	PHI	R7
	; return
	SEP	R5


		ORG	(code+0x0200)
vars:
		; -- rows expected to be at the page boundary
rows:		DB	0b00000000	; row 1
		DB	0b00000000	; row 2
		DB	0b00000000	; row 3
		DB	0b00000000	; row 4
		DB	0b00000000	; row 5
		DB	0b00000000	; row 6
		DB	0b00000000	; row 7
		DB	0b00000000	; row 8

		; a safety buffer
		DB	0		; recursion touches this cell

esc_inv:	DB	"\x1B[7m\0"
esc_norm:	DB	"\x1B[0m\0"
queen:		DB	" \x1B[1mQ\x1B[2m \0"
field:		DB	"   \0"
hdr_row:	DB	"   A  B  C  D  E  F  G  H\r\n\0"
row_start:	DB	" \0"
row_end:	DB	"\r\n\0"
no_more_sols:	DB	"\r\nNo more solutions found.\n\rPress <ENTER> to return to Monitor\r\n\0"
next_or_exit:	DB	"\r\nPress <ENTER> to look for the next solution, or <ESC> to return to the monitor\r\n\0"

; -----------------------------------------------------------------------------
; Reserve space for R6 stack
; -----------------------------------------------------------------------------
	ORG	(vars+0x017F)	; SCRT stack is from 0x017F..0x0100
scrt_stack:

; -----------------------------------------------------------------------------
; Reserve space for R2 stack
; -----------------------------------------------------------------------------
	ORG	(vars+0x01FF)	; R2 stack is from 0x01FF..0x0180
stack:


; -----------------------------------------------------------------------------
; Monitor routines called by this program
; -----------------------------------------------------------------------------

	ORG	0x8000		; monitor entry point
monitor:			;

	ORG	0x80A3		; mon_get_ch
mon_get_ch:			;

	ORG	0x8100		; mon_put_ch
mon_put_ch:				;

	ORG	0x8526		; mon_put_str
mon_put_str:			;

	ORG	0x8ADB		; SCRT call subroutine invoked by SEP R4 and using R6 as SP
mon_scrt_call:			;

	ORG	0x8AED		; SCRT return subroutine invoked by SEP R5 and using R6 as SP
mon_scrt_return:		;
