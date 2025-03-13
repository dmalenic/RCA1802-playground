; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2024 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------
; Calculates the Fibonacci numbers less than 4294967296
;
; Expected output:
;
; Fibonacci numbers less than 4,294,967,296
;           0
;           1
;           1
;           2
;           3
;           5
;           8
;          13
;          21
;          34
;          55
;          89
;         144
;         233
;         377
;         610
;         987
;        1597
;        2584
;        4181
;        6765
;       10946
;       17711
;       28657
;       46368
;       75025
;      121393
;      196418
;      317811
;      514229
;      832040
;     1346269
;     2178309
;     3524578
;     5702887
;     9227465
;    14930352
;    24157817
;    39088169
;    63245986
;   102334155
;   165580141
;   267914296
;   433494437
;   701408733
;  1134903170
;  1836311903
;  2971215073
;
; Press <ENTER> to return to the monitor
;
; -----------------------------------------------------------------------------
; Register allocation is partially imposed by the integration with Chuck's monitor:
; R0 - reset program counter and SP, PC, and SP for user programs invoked with the
;      `R` command, a memory pointer during the `DMA` transfer
; R1 - the interrupt program counter
; R2 - a stack pointer for the main function and interrupt routines
; R3 - program counter for the main function
; R4 - program counter for SCRT subroutine calls
; R5 - program counter for SCRT subroutine returns
; R6 - SCRT return address stack pointer
; R7 - a pointer to a string to be written when invoking `mon_put_str` on location 8526
; R8 - points to the first operand in Fibonacci summation
; R9 - points to the second operand in Fibonacci summation
; RA, RC, RD - scratch-pad registers for calculating and printing the results
; RB.HI - holds the input character classification
; RB.LO - holds the input character or the output character
; RE.HI - by the monitor program convention, it holds 01
; RE.LO - holds the UART baud rate indicator
; RF.HI - used by SCRT call and return subroutines to preserve the value of D
;         register between caller and callee
; -----------------------------------------------------------------------------
; It is assembled using
; [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be portable to other 1802 assemblers.
; The following instructions can be used to assemble and link the program:
; ```
; asl -cpu 1802 -L fibonacci.asm
; p2hex 8-queens.p fibonacci.hex
; ```
; -----------------------------------------------------------------------------


; enable C style numeric constants --------------------------------------------


        RELAXED ON

        CPU     1802


; include the bit manipulation functions --------------------------------------
; This file defines some bit-oriented functions that might be hardwired
; when using other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function. $ is the synonym for the current PC address.


        INCLUDE "bitfuncs.inc"


; -----------------------------------------------------------------------------
; MACROS
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Add two 32-bit numbers: M[a] = M[a]+M[b]
; a - holds the register pointing to the location of the first operand
; b - holds the register pointing to the location of the second operand
; a and b are unchanged
; if 32-bit overflow is encountered, end the calculation by jumping to
; the `fib_l_end` location.
; -----------------------------------------------------------------------------
add_dp	MACRO a,b
	SEX	b			; let X point to the register holding the 2nd operand address
	INC	a			; point to the 4th byte of a
	INC	a
	INC	a
	INC	b			; point to the 4th byte of b
	INC	b
	INC	b
	LDN	a			; load the 4th byte of a
	ADD				; lo(M[A]) = lo(M[a]) + lo(M[b])
	STR	a			; store the 4th byte of a
	DEC	a			; point to the 3rd byte of a
	DEC	b			; point to the 3rd byte of b
	LDN	a			; load the the 3rd byte of a
	ADC				; lo(M[A]) = lo(M[a]) + lo(M[b]) + DF
	STR	a			; store the 3rd byte of a
	DEC	a			; point to the 2nd byte of a
	DEC	b			; point to the 2nd byte of b
	LDN	a			; load the 2nd byte of a
	ADC				; lo(M[A]) = lo(M[a]) + lo(M[b]) + DF
	STR	a			; store the 2nd byte of a
	DEC	a			; point to the 1st byte of a
	DEC	b			; point to the 1st byte of b
	LDN	a			; load the 1st byte of a
	ADC				; lo(M[A]) = lo(M[a]) + lo(M[b]) + DF
	SEX	R2			; restore X to point to the stack
	BDF	fib_l_end		; if there was a carry, we are over 32-bits; exit
	STR	a			; otherwise, store the 1st byte of a
	ENDM


; register aliases ------------------------------------------------------------
R0      EQU     0
R1      EQU     1
R2      EQU     2
R3      EQU     3
R4      EQU     4
R5      EQU     5
R6      EQU     6
R7      EQU     7
R8      EQU     8
R9      EQU     9
RA      EQU     10
RB      EQU     11
RC      EQU     12
RD      EQU     13
RE      EQU     14
RF      EQU     15


; -----------------------------------------------------------------------------
; PROGRAM
; -----------------------------------------------------------------------------
        ORG     0
code:

	; ---------------------------------------------------------------------
	; Initialize the program
	; ---------------------------------------------------------------------
	; When started after the reset, or by executing the monitor R0000 command:
	; R0 is set to be both the program counter and the stack pointer
	; R1 will become a program counter in the case of an interrupt
	; R2 will become a stack pointer in the case of an interrupt
	; The following section configures the registers::
	; R2 points to the area that will become a stack pointer when control is passed to the main function
	; R3 will become a program counter and point to the main function
	; R4 will point to SCRT call routine
	; R5 will point to SCRT return routine
	; R6 will point to SCRT stack
	; ---------------------------------------------------------------------

	; Initialize R4 to 0x8ADB and R5 to 0x8AED to enable SCRT.
	LDI	hi(mon_scrt_call)
	PHI	R4
	PHI	R5
	LDI	lo(mon_scrt_call)
	PLO	R4
	LDI	lo(mon_scrt_return)
	PLO	R5

	; Initialize R6 to SCRT_stack.
	LDI	hi(scrt_stack)
	PHI	R6
	LDI	lo(scrt_stack)
	PLO	R6

	; Configure R3 to point to the main function.
	LDI	lo(main)
	PLO	R3
	GHI	R0
	PHI	R3

	; Configure R2 to point to the stack.
	LDI	hi(stack)
	PHI	R2
	LDI	lo(stack)
	PLO	R2

	; Pass the control to the main function.
	SEX	R2			; Make R2 the default index register, i.e., the stack pointer.
	SEP	R3			; Call the main function.

	; ---------------------------------------------------------------------
	; The program exit point.
	; ---------------------------------------------------------------------
	; R0 points to this location, so when SEP 0 is executed at the end of the main,
	; the program execution will resume from this point.
	SEX	R0			; R0 is now the default index register, similar to what it was after the reset.
	LBR	monitor			; Jump to the monitor.

	; ---------------------------------------------------------------------
	; The main function.
	; ---------------------------------------------------------------------
main:
	LDI	hi(vars)		; load the page part of the variables section
	PHI	R7			; the high part of `vars` holds the page where all strings reside
	PHI	R8			; the high part of `first`
	PHI	R9			; the high part of `second`
	LDI	lo(first+3)		; set the low part to the last byte of `first`
	PLO	R8
	LDI	lo(second+3)		; set the low part to the last byte of  `second`
	PLO	R9

	; print the initial message
	LDI	lo(initial_msg)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; Initialize the `first` and the `second` to enable the program invocation without reloading.
	; Let the `first` be DB 0, 0, 0, 0.
	SEX	R8			; temporary make R8 index pointer
	LDI	0
	STXD
	STXD
	STXD
	STR	R8
	; R8 points to the first byte of `first`.

	; Let the `second` be DB 0, 0, 0, 1.
	SEX	R9			; temporary make R9 index pointer
	LDI	1
	STXD
	LDI	0
	STXD
	STXD
	STR	R9
	; R9 points to the first byte of `second`.

	SEX	R2			; restore the default index pointer

	; Print the `first` holding the initial 0.
	SEP	R4
	DB	hi(prt_32b_num)
	DB	lo(prt_32b_num)
	DB	lo(first)

	; The fibonacci sequence calculation loop calculates 2 fibonacci numbers per iteration.
	; The exit condition is the 32-bit overflow - see `add_dp` for the macro definition where
	; the check is implemented.
fib_l:
	; Print the `second`.
	SEP	R4
	DB	hi(prt_32b_num)
	DB	lo(prt_32b_num)
	DB	lo(second)

	; first = first+second
	add_dp	R8, R9

	; Print the `first`
	SEP	R4
	DB	hi(prt_32b_num)
	DB	lo(prt_32b_num)
	DB	lo(first)

	; second = second+first
	add_dp	R9, R8

	; If this point is reached, `add_dp` did not detect a 32-bit overflow.
	; Repeat the Fibonacci sequence calculation loop.
	BR	fib_l

	; This point is reached only if `add_dp` has detected the 32-bit overflow.
fib_l_end:
	; Print the final message and return to the monitor.
	LDI	lo(final_msg)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; ---------------------------------------------------------------------
	; Exit main function: return the control to the program exit point.
	; ---------------------------------------------------------------------
	SEP	R0


prt_32b_num:
	; ---------------------------------------------------------------------
	; Print a 32-bit number located in a buffer on `vars:` page whose
	; in-page address is passed in as the inline arguments.
	; R7 is used as a pointer to a string holding a converted number.
	; RA, RC and RD are scratch-pad registers for a digit conversion.
	; All registers except D and DF are preserved.
	; ---------------------------------------------------------------------
	; Preserve R7, RA, RC, and RD registers.
	GHI	R7			; use as pointer to a string to print
	STXD
	GLO	R7
	STXD
	GHI	RA			; scratch-pad register for number conversion
	STXD
	GLO	RA
	STXD
	GHI	RC			; scratch-pad register for number conversion
	STXD
	GLO	RC
	STXD
	GHI	RD			; scratch-pad register for number conversion
	STXD
	GLO	RD
	STXD

	; Copy the value pointed to by the provided immediate address to `tmp_conv`.
	; Note: `tmp_conv` is 1 byte longer than the number to print.
	; Use RC as the source index and RD as the destination index.
	GHI	R8			; RA.HI, RC.HI and RD.HI are the same as R8.HI (`vars:` page address)
	PHI	RA			; initialize the high part of RA - needed later in `dec_digit`
	PHI	RC			; initialize the high part of RC
	PHI	RD			; initialize the high part of RD
	LDA	R6			; load the immediate argument
	PLO	RC			; put it in the low part of RC to make RC point to the source buffer
	LDI	lo(tmp_conv)		; load the low part of `tmp_conv` address
	PLO	RD			; put it in the low part of RD to make RD point to the destination buffer
	LDI	0			; set 0 to the first byte of `tmp_conv`
	STR	RD
	INC	RD			; increase RD to point to the 2nd byte of `tmp_conv`
	LDA	RC			; copy the 1st byte of the value pointed by RC to the location pointed by RD
	STR	RD
	INC	RD			; increase RD to point to the 3rd byte of `tmp_conv`
	LDA	RC			; copy the 2nd byte of the value pointed by RC to the location pointed by RD
	STR	RD
	INC	RD			; increase RD to point to the 4th byte of `tmp_conv`
	LDA	RC			; copy the 3rd byte of the value pointed by RC to the location pointed by RD
	STR	RD
	INC	RD			; increase RD to point to the 5th byte of `tmp_conv`
	LDN	RC			; copy the 4th byte of the value pointed by RC to the location pointed by RD
	STR	RD

	; Initialize the string buffer where the decimal conversion result will be written
	; to the default result as if the conversion input was 0.
	LDI	lo(prt_buf_end-1)	; the low part points to the end of the print buffer
	PLO	RC
	SEX	RC			; temporary set RC to act as the index register
	LDI	0			; the trailing '\0'
	STXD
	LDI	'0'			; the corner case for 0, to be overwritten if the input number is not 0
	STXD
	LDI	0x20			; fill the rest of the buffer with ' '
	REPT	10			; an inline macro that repeats commands till ENDM 10 times
	STXD
	ENDM
	SEX	R2			; restore the default index register

	; Let RC point to the last position of `prt_buf`.
	LDI	lo(prt_buf_end-1)
	PLO	RC

	; Convert the 32-bit unsigned value pointed by RA to a decimal string.
	; We have at most 10 decimal digits, repeat digit conversion 10 times starting from the rightmost position.
	REPT	10			; an inline macro that repeats commands till ENDM 10 times
	SEP	R4			; convert a single digit
	DB	hi(dec_digit)
	DB	lo(dec_digit)
	ENDM

	; print the string holding the conversion result, R7 is a pointer to null-terminated string
	LDI	lo(prt_buf)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; print <CR><LF>
	SEP	R4
	DB	hi(mon_crlf)
	DB	lo(mon_crlf)

	; restore R7,RA,RC,RD register
	IRX
	LDXA				; restore RD
	PLO	RD
	LDXA
	PHI	RD
	LDXA				; restore RC
	PLO	RC
	LDXA
	PHI	RC
	LDXA				; restore RA
	PLO	RA
	LDXA
	PHI	RA
	LDXA				; restore R7
	PLO	R7
	LDX
	PHI	R7
	; return
	SEP	R5


dec_digit:
	; ---------------------------------------------------------------------
	; This function converts the single decimal digit by dividing the number
	; in `tmp_conv` by the number in `radix` and writes the result
	; to the correct position in `prt_buf`. It is intended to be called
	; as many times as necessary to convert the whole number.
	; `tmp_conv` is 5 bytes long, the 1st byte is 0 on input, while the 2nd, 3rd,
	; 4th and the 5th byte hold the number to be converted.
	; As per RCA 1802 convention, the big-endian notation is used.
	; If the number in `tmp_conv` is 0, the function returns immediately;
        ; otherwise, it divides that number by a radix value.
	; The division is performed in place, the result replaces the dividend,
	; and the remainder is held in the 1st byte of the `tmp_conv` buffer.
	; The remainder is converted to a character and written in the memory
	; location pointed out by RC.
	; The result of division is intended to be used as the input for the
	; next digit conversion.
	; The RA register manipulates the content of the `tmp_conv` buffer.
	; The RD register points to a radix (divisor).
	; A callee sets the high parts of all registers. This function does not
	; change them.
	; ---------------------------------------------------------------------
	LDI	lo(radix)		; let RD point to `radix`
	PLO	RD
	LDI	lo(tmp_conv+1)		; let RA point to the first byte of the dividend
	PLO	RA

	; If the dividend is zero, return without performing any conversion.
	; Note: the dividend is stored in the 2nd, 3rd, 4th and 5th position of the `tmp_conv` buffer.
	LDA	RA			; load the 2nd byte in the buffer
	BNZ	dec_conv		; the 2nd byte is not zero, perform the conversion
	LDA	RA			; load the 3rd byte
	BNZ	dec_conv		; the 3rd byte is not zero, perform the conversion
	LDA	RA			; load the 4th byte
	BNZ	dec_conv		; the 4th byte is not zero, perform the conversion
	LDN	RA			; load the 5th byte
	BNZ	dec_conv		; the 5th byte is not zero, perform the conversion
	SEP	R5			; all tested bytes were zero; return immediately.

dec_conv:
	; Move the `prt_buf` index to where the current conversion result character will be stored.
	DEC	RC

	; Make RA point to the last byte of `tmp_conv`. It assumes the high part of RA has already been initialized.
	LDI	lo(tmp_conv+4)
	PLO	RA

	; The loop divides a 32-bit value with an 8-bit value. Each loop iteration calculates 1 bit of the result.
	; The remainder is in the first byte. The following 4 bytes hold the division result.
	LDI	32			; 32 iterations
dec_digit_loop:
	; Shift left 5 bytes buffer content, and if the value in the 1st byte is greater or equal to radix,
	; add 1 to the last byte.
	STXD				; preserve the loop counter onto the stack

	; Shift-left the 5th byte in `tmp_conv`, putting 0 to the lsb position.
	LDN	RA			; note that RA points to the last byte within the buffer
	SHL
	STR	RA
	DEC	RA

	; Shift-left the 4th byte in `tmp_conv`, filling the lsb position from the DF.
	LDN	RA
	SHLC
	STR	RA
	DEC	RA

	; Shift-left the 3rd byte in `tmp_conv`, filling the lsb position from the DF.
	LDN	RA
	SHLC
	STR	RA
	DEC	RA

	; Shift-left the 2nd byte in `tmp_conv`, filling the lsb position from the DF.
	LDN	RA
	SHLC
	STR	RA
	DEC	RA

	; Shift-left the 1st byte in `tmp_conv`, filling the lsb position from the DF.
	LDN	RA
	SHLC
	STR	RA

	; D holds the 1st byte of `tmp_conv` that we want to compare with the radix.
	SEX	RD			; point to radix
	SM				; if the prefix is greater or equal to the radix, the result is non-negative
	SEX	R2			; restore the default index register
	BM	dec_prefix_less		; if the prefix is less than radix, skip subtraction

	; The prefix in the 1st byte of `tmp_conv` was greater or equal to `radix`.
	; Store the result of the subtraction in the 1st byte of `tmp_conv` and add 1 to the last byte of the
	; intermediate result. As the last bit of the last byte of `tmp_conv` was zero after the previous shifting,
	; adding 1 cannot cause the overflow.
	STR	RA			; store the subtraction result in the 1st byte of `tmp_conv`
	LDI	lo(tmp_conv+4)		; point to the last byte of `tmp_conv`
	PLO	RA
	LDN	RA			; add 1 to the last byte of `tmp_conv`
	ADI	1
	STR	RA			; store the updated last byte of `tmp_conv`
	BR	dec_test_if_done	; go to loop counter checking

dec_prefix_less:
	; Let RA point to the last part of `tmp_conv`.
	LDI	lo(tmp_conv+4)
	PLO	RA

dec_test_if_done
	; Test if all 32-bits of the division have been calculated
	IRX				; restore the loop counter from the stack
	LDX
	SMI	1			; decrease the loop counter
	BNZ	dec_digit_loop		; if the counter is greater than zero, do another loop

	; The division is completed; the remainder is in the 1st byte of the `tmp_conv` buffer.
	; Convert it to a character and store it in the correct position within the `prt_buf`.
	LDI	lo(tmp_conv)		; restore the RA to the beginning of `tmp_conv`
	PLO	RA
	LDN	RA			; load the remainder byte
	ADI	'0'			; make it a character
	STR	RC			; store it into the current position within `str_buf`
	LDI	0			; clear the first byte of `tmp_conv` for the next iteration
	STR	RA
	; return
	SEP	R5


; -----------------------------------------------------------------------------
; Variables reside in the space from 0x0180 to 0x01FF.
; The 32-bit values are stored using the big-endian notation.
; -----------------------------------------------------------------------------
	ORG	(code+0x0180)
vars:
first:
	; The first argument for the Fibonacci step
	DB	0, 0, 0, 0
second:
	; The second argument for the Fibonacci step
	DB	0, 0, 0, 1
tmp_conv:
	; used for 32-bit division
	DB	0, 0, 0, 0, 0
radix:
	; used to covert the number for printing
	DB	10
prt_buf:
	; buffer where the converted number is stored for printing
	DB	' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, '0', 0
prt_buf_end:

initial_msg:
	DB	"\r\nFibonacci numbers less than 4,294,967,296\r\n\0"
final_msg:
	DB	"\r\nPress <ENTER> to return to the monitor\r\n\0"

; -----------------------------------------------------------------------------
; Reserve the space for SCRT stack (R6) from 0x0200 to 0x027F
; -----------------------------------------------------------------------------
	ORG	(code+0x027F)
scrt_stack:

; -----------------------------------------------------------------------------
; Reserve the space for the standard stack (R2) from 0x0280 to 0x02FF
; -----------------------------------------------------------------------------
	ORG	(code+0x02FF)
stack:


; -----------------------------------------------------------------------------
; Monitor routines called by this program:
; -----------------------------------------------------------------------------
	ORG	0x8000		; monitor entry point
monitor:

;	ORG	0x80A3		; mon_get_ch
;mon_get_ch:

;	ORG	0x8100		; mon_put_ch
;mon_put_ch:

	ORG	0x8519		; mon_crlf
mon_crlf:

;	ORG	0x85BF		; mon_prt_b_hex
;mon_prt_b_hex:

	ORG	0x8526		; mon_put_str
mon_put_str:

	ORG	0x8ADB		; SCRT call subroutine invoked by SEP R4 and using R6 as SP
mon_scrt_call:

	ORG	0x8AED		; SCRT return subroutine invoked by SEP R5 and using R6 as SP
mon_scrt_return:
