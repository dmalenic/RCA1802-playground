; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2024 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------
; This program generates all prime numbers less than 65536 using a sieve of
; Eratosthenes algorithm.
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
; R8, R9.LO are used to update the context of `sieve` (step 3.2)
;     R8 points to the byte, and R9.LO is the bit mask to test/update
; RA holds the pointer to the buffer that holds the current number being
;     marked as composite, or
; RC holds the current number being tested for primality
; RD holds the pointer to the `step` when marking multiples of a prime number as composites
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
; asl -cpu 1802 -L sieve.asm
; p2hex 8-queens.p sieve.hex
; ```
; -----------------------------------------------------------------------------


; enable C style numeric constants --------------------------------------------


        RELAXED ON

        CPU     1802


; include the bit manipulation functions --------------------------------------
; This file defines some bit-oriented functions that might be hardwired
; when using other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function. `$` is the synonym for the current PC address.


        INCLUDE "bitfuncs.inc"


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
	; The following section configures the registers:
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
	LDI	hi(initial_msg)
	PHI	R7
	LDI	lo(initial_msg)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; ---------------------------------------------------------------------
	; Initialize the `sieve` array for the initial case that 2 is the prime.
	; R8 is the index within the sieve.
	; RC is the counter.
	; ---------------------------------------------------------------------
	LDI	hi(sieve_end-1)		; R8 points to the last element of the `sieve` array
	PHI	R8
	LDI	lo(sieve_end-1)
	PLO	R8
	LDI	0
	PLO	RC

	SEX	R8			; Use R8 as the index register; R8 points to the `sieve`.

init_loop:
	LDI	0b01010101		; Prepopulate the sieve to a state corresponding to 2 being a prime.
	REPT	32			; Unwind the loop so only the `RC.LO` register is used as a counter (32 * 256 == 8k)
	STXD
	ENDM
	DEC	RC
	GLO	RC
	BNZ	init_loop

	; This is the special case for the very first byte; 1 is neither prime nor composite,
	; and 2 is the only even prime.
	; Note: R8 points to a byte just below the start of the sieve.
	INC	R8			; Point R8 to the 1st element.
	LDI	0b10010101		; The 1st byte must account for 2 being a prime and 1 not.
	STR	R8

	SEX	R2			; Restore default index register.

	; ---------------------------------------------------------------------
	; Detect primes other primes starting with 3:
	; 1. loop over all odd numbers less than 32768
	;   2. if the current testing number is not marked yet, it is a prime
	;      3.1 set the marking step to be twice the current prime
	;      3.2 starting from the current prime, using the marking step as the
	;          increment, mark every encountered number as a composite.
	; RC holds the current number being tested (step 1)
	; RA holds the pointer to`tmp_mark`, which holds the current number being
	;     marked as composite (step 3.2)
	; RD holds the pointer to the `step` in which RA is incremented (step 3.2)
	; R8, R9.LO are used to update the context of `sieve` (step 3.2)
	;     R8 points to the byte, and R9.LO is the bit mask to test/update
	; ---------------------------------------------------------------------

	; initialize the RC, RA and RD
	LDI	0			; RC is 0003
	PHI	RC
	LDI	3
	PLO	RC
	LDI	hi(vars)		; RA points to `tmp_mark`
	PHI	RA
	PHI	RD
	LDI	lo(tmp_mark)
	PLO	RA
	LDI	lo(step)		; RD points to `step`
	PLO	RD

	; ---------------------------------------------------------------------
	; The outer loop loops over all odd numbers starting with 3 less than 32768.
	; If any encountered number has not already been marked, it is a prime.
	; ---------------------------------------------------------------------

outer_marking_loop:
	; Initialize the current testing number in `tmp_mark` and `step` to the value in RC.
	GHI	RC			; get RC.HI
	STR	RA			; store it to the 1st byte of `tmp_mark`
	STR	RD			; and to the 1st byte of `step`
	INC	RA			; move RA to the 2nd byte of `tmp_mark`
	INC	RD			; move RD to the 2nd byte of `step`
	GLO	RC			; get the RC.LO
	STR	RA			; and store it to the 2nd byte of `tmp_mark`
	; double it for the step value
	SHL				; double the value in D, MSB carry overflows to DF
	STR	RD			; store it as the 2nd byte of `step`
	DEC	RD			; then point RD to the 1st byte of `step`
	LDN	RD			; and load the 1st byte of `step`.
	SHLC				; Double it and populate the LSB from DF.
	STR	RD			; Store the result to the 1st byte of `step`
	; At this moment, RD points to the 1st byte of `step`.
	DEC	RA			; RA points to the 1st byte of `tmp_mark`.

	; ---------------------------------------------------------------------
	; Check if the number has already been marked. If so, skip it and continue
	; with the next candidate.
	; ---------------------------------------------------------------------

	; Put the byte index of the number from `tmp_mark` into R8.
	; Note that the number 1 in `tmp_mark` is represented by the bit 0 of the byte 0 of `sieve`.
	LDA	RA			; Read the value pointed by RA
	PHI	R8			; and copy it to R8.
	LDN	RA
	PLO	R8
	DEC	R8			; Fix the offset error between the prime representation in RC and the one in `sieve`.
	; Let R9 point to `mark_mask`. Note the optimization if it is placed on the page boundary.
	LDI	hi(mark_mask)
	PHI	R9
	LDI	0
	PLO	R9
	DEC	RA			; Keep RA pointing to the first byte of `tmp_mark`.

	; Shift R8 3 times to the right. The shifted-out bits are shifted into R9.LO.
	REPT	3
	GHI	R8
	SHR
	PHI	R8
	GLO	R8
	SHRC
	PLO	R8
	GLO	R9
	SHRC
	PLO	R9
	ENDM
	; Right align R9.LO.
	REPT	5
	SHR
	ENDM
	PLO	R9

	; Make R8 point to the correct byte within `sieve`.
	GHI	R8
	ADI	hi(sieve)
	PHI	R8
	; There is no need to add the lower part of the `mark_mask` address to R9.LO if it is on the page boundary.

	; Test the bit based on the mask pointed by R9. If it is already marked, look for another candidate.
	LDN	R8
	SEX	R9
	AND
	SEX	R2
	BNZ	next_marking_number

	; ---------------------------------------------------------------------
	; At this point, we have a prime number.
	; The inner loop marks all its multiples as composite numbers.
	; ---------------------------------------------------------------------

inner_marking_loop:

	; ---------------------------------------------------------------------
	; Calculate numbers to mark: M[RA] = M[RA] + M[RD]
	; ---------------------------------------------------------------------

	; RA points th the 1st byte of `tmp_mark`, and RD points to the 1st byte of `step`.
	SEX	RD			; make RD index
	INC	RD			; let RD point to the 2nd byte of `step`
	INC	RA			; let RA point to the 2nd byte of `tnp_mark`
	LDN	RA			; load the 2nd byte of `tmp_mark`
	ADD				; add the 2nd byte of `step`
	STR	RA			; store the result to the 2nd byte of `tmp_mark`
	DEC	RD			; point to the 1st byte of `step`
	DEC	RA			; point to the 1st byte of `tmp_mark`
	LDN	RA			; load the 1st byte of `tmp_mark`
	ADC				; add the 1st byte of `step` with carry
	STR	RA			; store the result to the 1st byte of `tmp_mark`
	SEX	R2			; restore the default index register
	; If M[RA] >= 65536, i.e., the carry has occurred, then the inner loop has been completed.
	BDF	next_marking_number	; The carry is detected, and we are done with the inner loop.
	; RA points to the 1st byte of `tmp_mark`.

	; ---------------------------------------------------------------------
	; Mark the composite number.
	; ---------------------------------------------------------------------

	; Put the byte index of the number from `tmp_mark` into R8.
	; Note that the number 1 in `tmp_mark` is represented by the bit 0 of the byte 0 of `sieve`.
	LDA	RA			; Read the value pointed by RA
	PHI	R8			; and copy it to R8.
	LDN	RA
	PLO	R8
	DEC	R8			; Fix the offset error between the prime representation in RC and the one in `sieve`.
	; Let R9 point to `mark_mask`. Note the optimization if it is placed on the page boundary.
	LDI	hi(mark_mask)
	PHI	R9
	LDI	0
	PLO	R9
	DEC	RA			; Keep RA pointing to the first byte of `tmp_mark`.

	; Shift R8 3 times to the right. The shifted-out bits are shifted into R9.LO.
	REPT	3
	GHI	R8
	SHR
	PHI	R8
	GLO	R8
	SHRC
	PLO	R8
	GLO	R9
	SHRC
	PLO	R9
	ENDM
	; Right align R9.LO.
	REPT	5
	SHR
	ENDM
	PLO	R9

	; Make R8 point to the correct byte within `sieve`.
	GHI	R8
	ADI	hi(sieve)
	PHI	R8
	; There is no need to add the lower part of the `mark_mask` address to R9.LO if it is on the page boundary.

	; Set the bit to indicate that it corresponds to the composite number.
	LDN	R8
	SEX	R9
	OR
	SEX	R2
	STR	R8

	BR	inner_marking_loop

next_marking_number:

	; Increment RC twice, so it will hold the next odd number.
	INC	RC
	INC	RC

	; It is enough to iterate only over sqrt(N) candidates to mark all composite numbers up to N.
	; In our case, N is 65537, so we need to iterate only over the first 256 candidates, i.e.,
	; when RC.HI stops being 0; we are done.
	GHI	RC
	BZ	outer_marking_loop


	; ---------------------------------------------------------------------
	; Print results
	; Don't assume any register is now in a usable state; reinitialize required registers:
	; The code iterates over the `sieve` and tests every bit to determine if the corresponding
	; number has been marked as a composite or a prime. If it is a prime, it is printed.
	; R8 is the index into the `sieve`,
	; R9 points to the `prt_mask`,
	; RC is the number to print,
	; RD.LO is used for tabulation. It holds a count of numbers printed in the current row.
	; ---------------------------------------------------------------------
print_result:
	; Print the message stating what is being printed.
	LDI	hi(print_start_msg)
	PHI	R7
	LDI	lo(print_start_msg)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

 	; 1 is the first number to test; load it to RC.
	LDI	1
	PLO	RC
	LDI	0
	PHI	RC

	; Load the address of the `sieve` to R8.
	LDI	hi(sieve)
	PHI	R8
	LDI	lo(sieve)
	PLO	R8

	; Load the address of `prt_mask` to R9.
	LDI	hi(prt_mask)
	PHI	R9
	LDI	lo(prt_mask)
	PLO	R9

	; Load 0 to RD to initialize tabulation.
	GHI	RC			; RC.HI is currently 0
	PLO	RD

print_res_loop:
	; Initialize `prt_mask` for a current bit in `sieve`.
	; It is required if we rerun the program without reloading it.
	LDI	0b10000000
	STR	R9

print_res_mask_loop:
	; Is the masked-out bit set?
	LDN	R9			; Load `prt_mask` to D
	SEX	R8			; R8 is the index into `sieve`
	AND				; D = D & (*R8)
	SEX	R2			; restore the default index register
	BNZ	prt_skip_not_prime	; if D is not zero, then we have a composite.

	; D was 0, so it is a prime. Print the number held within RC.
	SEP	R4
	DB	hi(prt_16b_num)
	DB	lo(prt_16b_num)

	; Check if 10 numbers have been printed in this row.
	INC	RD
	GLO	RD
	SMI	10
	BNZ	prt_skip_not_prime	; no, skp printing <CR><NL>
	PLO	RD			; yes, reset the counter

	; print <CR><LF>
	SEP	R4
	DB	hi(mon_crlf)
	DB	lo(mon_crlf)

prt_skip_not_prime:

	; Test the next number.
	INC	RC			; Increment the register holding a number to print.

	; Shift the `prt_mask`.
	LDN	R9			; load the `prt_mask` to D
	SHR				; shift the value in `prt_mask` 1 bit to the right,
	STR	R9			; store the updated value of `prt_mask`
	BNZ	print_res_mask_loop	; `prt_mask` is not zero; continue with the same byte within the `sieve`
	INC	R8			; otherwise, point to the next byte in the `sieve` array

	; If all numbers are tested, R8 will point to `sieve_end`.
	GHI	R8			; get R8.HI
	SMI	hi(sieve_end)		; subtract the high part of `sieve_end`
	BZ	print_loop_end		; exit loop if equal
	BR	print_res_loop

print_loop_end:

	; Print the final message and return to the monitor.
	LDI	hi(final_msg)
	PHI	R7
	LDI	lo(final_msg)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; ---------------------------------------------------------------------
	; Exit main function: return the control to the program exit point.
	; ---------------------------------------------------------------------
	SEP	R0


prt_16b_num:
	; ---------------------------------------------------------------------
	; Print a 16-bit number provided in RC.
	; R7 is used as a pointer to a string holding a converted number.
	; RC holds the 16-bit value to be converted.
	; RA, RC and RD are scratch-pad registers for a digit conversion.
	; All registers except D and DF are preserved.
	; ---------------------------------------------------------------------
	; Preserve R7, R8, RA, RC, and RD registers.
	GHI	R7			; use as a pointer to a string to print
	STXD
	GLO	R7
	STXD
	GHI	R8
	STXD
	GLO	R8
	STXD
	GHI	RA			; scratch-pad register for number conversion
	STXD
	GLO	RA
	STXD
	GHI	RC			; holds the 16-bit value to convert
	STXD
	GLO	RC
	STXD
	GHI	RD			; scratch-pad register for number conversion
	STXD
	GLO	RD
	STXD

	; Copy the value pointed to by the provided immediate address to `tmp_conv`.
	; Note: `tmp_conv` is 1 byte longer than the number to print.
	; Its 1st byte is initialized to 0 (it will hold the division remainder).
	; Use RC as the source value and RD as the destination index.
	GHI	R9			; RA.HI, RC.HI, and RD.HI are the same as R9.HI (`vars:` page address)
	PHI	RA			; initialize the high part of RA - needed later in the `dec_digit` function
	PHI	RD			; initialize the high part of RD
	LDI	lo(tmp_conv)		; load the low part of the `tmp_conv` address
	PLO	RD			; put it in the low part of RD to make RD point to the destination buffer
	LDI	0			; set 0 to the first byte of `tmp_conv`
	STR	RD
	INC	RD			; increase RD to point to the 2nd byte of `tmp_conv`
	GHI	RC			; copy the 1st byte of the value pointed by RC to the location pointed by RD
	STR	RD
	INC	RD			; increase RD to point to the 3rd byte of `tmp_conv`
	GLO	RC			; copy the 2nd byte of the value pointed by RC to the location pointed by RD
	STR	RD

	; Initialize the string buffer where the decimal conversion result will be written
	; to the default result as if the conversion input was 0.
	LDI	hi(vars)
	PHI	RC
	LDI	lo(prt_buf_end-1)	; the low part points to the end of the print buffer
	PLO	RC
	SEX	RC			; temporary set RC to act as the index register
	LDI	0			; the trailing '\0'
	STXD
	LDI	'0'			; the corner case for 0, to be overwritten if the input number is not 0
	STXD
	LDI	0x20			; fill the rest of the buffer with ' '
	REPT	5			; an inline macro that repeats commands till ENDM 5 times
	STXD
	ENDM
	SEX	R2			; restore the default index register

	; Let RC point to the last position of `prt_buf`.
	LDI	lo(prt_buf_end-1)
	PLO	RC

	; Convert the 16-bit unsigned value pointed by RA to a decimal string.
	; We have at most 5 decimal digits, repeat digit conversion 5 times starting from the rightmost position.
	REPT	5			; an inline macro that repeats commands till ENDM 5 times
	SEP	R4			; convert a single digit
	DB	hi(dec_digit)
	DB	lo(dec_digit)
	ENDM

	; Print the string with the conversion result. R7 is a pointer to the null-terminated string.
	LDI	hi(prt_buf)
	PHI	R7
	LDI	lo(prt_buf)
	PLO	R7
	SEP	R4
	DB	hi(mon_put_str)
	DB	lo(mon_put_str)

	; Restore R7, R8, RA, RC, and RD registers.
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
	LDXA				; restore R8
	PLO	R8
	LDXA
	PHI	R8
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
	; `tmp_conv` is 3 bytes long, the 1st byte is 0 on input, while the 2nd
	; and the 3rd byte hold the number to be converted.
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
	; Note: the dividend is stored in the 2nd and 3rd position of the `tmp_conv` buffer.
	LDA	RA			; load the 2nd byte in the buffer
	BNZ	dec_conv		; the 2nd byte is not zero, perform the conversion
	LDN	RA			; load the 3rd byte
	BNZ	dec_conv		; the 3rd byte is not zero, perform the conversion
	SEP	R5			; all tested bytes were zero; return immediately.

dec_conv:
	; Move the `prt_buf` index to where the current conversion result character will be stored.
	DEC	RC

	; Make RA point to the last byte of `tmp_conv`. It assumes the high part of RA has already been initialized.
	LDI	lo(tmp_conv+2)
	PLO	RA

	; The loop divides a 16-bit value with an 8-bit value. Each loop iteration calculates 1 bit of the result.
	; The remainder is in the first byte. The following 2 bytes hold the division result.
	LDI	16			; 16 iterations
dec_digit_loop:
	; Shift left 3 bytes buffer content, and if the value in the 1st byte is greater or equal to radix,
	; add 1 to the last byte.
	STXD				; preserve the loop counter onto the stack

	; Shift-left the 3rd byte in `tmp_conv`, putting 0 to the lsb position.
	LDN	RA			; note that RA points to the last byte within the buffer
	SHL
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
	LDI	lo(tmp_conv+2)		; point to the last byte of `tmp_conv`
	PLO	RA
	LDN	RA			; add 1 to the last byte of `tmp_conv`
	ADI	1
	STR	RA			; store the updated last byte of `tmp_conv`
	BR	dec_test_if_done	; go to loop counter checking

dec_prefix_less:
	; Let RA point to the last part of `tmp_conv`.
	LDI	lo(tmp_conv+2)
	PLO	RA

dec_test_if_done
	; Test if all 16 bits of the division have been calculated
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
; The 16-bit values are stored using the big-endian notation.
; -----------------------------------------------------------------------------
	ORG	(code+0x0200)
vars:
mark_mask:
	; bitmask used to update a `sieve` byte
	; it is placed on a page boundary position to optimize the code.
	DB	0b10000000
	DB	0b01000000
	DB	0b00100000
	DB	0b00010000
	DB	0b00001000
	DB	0b00000100
	DB	0b00000010
	DB	0b00000001
prt_mask:
	; bitmask used when testing whether to print a number associated with a bit in the `sieve`
	DB	0b10000000
tmp_mark:
	; the 16-bit number being tested or printed
	DB	0, 0
step:
	; the increment value for the loop that marks composites within the `sieve`
	; it is usually twice the value of the current prime
	DB	0, 0
tmp_conv:
	; used for 16-bit division
	DB	0, 0, 0
radix:
	; used to covert the number for printing
	DB	10
prt_buf:
	; buffer where the converted number is stored for printing
	DB	' ', 0, 0, 0, 0, '0', 0
prt_buf_end:

initial_msg:
	DB	"\r\nPlease wait a moment while I am populating the sieve of Eratosthenes ...\n\r\0"
print_start_msg:
	DB	"\r\nPrime numbers less than 65536\r\n\0"
final_msg:
	DB	"\r\nPress <ENTER> to return to the monitor\r\n\0"


; -----------------------------------------------------------------------------
; Reserve the space for SCRT stack (R6) from 0x0300 to 0x037F
; -----------------------------------------------------------------------------
	ORG	(code+0x037F)
scrt_stack:


; -----------------------------------------------------------------------------
; Reserve the space for the standard stack (R2) from 0x0380 to 0x03FF
; -----------------------------------------------------------------------------
	ORG	(code+0x03FF)
stack:


; -----------------------------------------------------------------------------
; The array holding the Sieve of Eratosthenes
; Note: the sieve is represented in the LSB-first order, i.e., 1 is the leftmost
; bit of the 1st byte, and 65535 is the rightmost bit of the last byte.
; -----------------------------------------------------------------------------
	ORG	(0x2000)
sieve:
	ORG	(0x4000)
sieve_end:


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

	ORG	0x85BF		; mon_prt_b_hex
mon_prt_b_hex:

	ORG	0x8526		; mon_put_str
mon_put_str:

	ORG	0x8ADB		; SCRT call subroutine invoked by SEP R4 and using R6 as SP
mon_scrt_call:

	ORG	0x8AED		; SCRT return subroutine invoked by SEP R5 and using R6 as SP
mon_scrt_return:
