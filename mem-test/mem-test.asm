; Here is a memory test program for the 1802 Membership card.
; It is a bit march type test of the 32K RAM (62256) however
; it doesn't check for cross-talk between the memory address lines.
; I have wrote such a program but even on my Netronics ELF II
; it would take just under 6 DAYS to complete.
; This version does check for data line cross-talk only.
; Running this software on the 1802 Membership Card Rev L.1
; will take a minute or two to complete.
; The LED's will display the current memory page being tested.
; If there is an error detected the "Q" LED will come on and stay on.
; If an error is detected the address that caused the error is stored
; at memory location hex 0002 (hi order) and hex 0003 (lo order).
; If there is no errors detected the data LED's will appear to count
; from "00" to "7F", when it is done testing and no errors have been
; detected the "Q" LED will flash (Blink) on and off and the data
; LED's will display hex "7F" (01111111).
;
; last date Sept 30 2011. Charles J. Yakym



; enable C style numeric constants --------------------------------------------


        RELAXED ON

        CPU     1802


; include the bit manipulation functions --------------------------------------
; This file defines a couple of bit-oriented functions that might be hardwired
; when using other assemblers.
; A code uses `hi()` and `lo()` operators that `asl` implements as user-defined
; function. $ is the synonym for the current PC address.
; The source for `bitfuncs.inc` is provided to help port those functions to the
; assembler of your choice.


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

BLNK_D	EQU	0x20		; blink delay


        ORG     0

code:

	BR   start 
mem_addr:
	DB   0x00		; high order address of memory being tested 
	DB   0x00		; lo order address of memory being tested
dis_pg_val:
	DB   0x00		; high order address to display

start:
	GHI  R0 		; set hi order R2,R5, RC
	PHI  R2 
	PHI  R5 
	PHI  RC 
	LDI  lo(mem_addr) 	; R2 points at hi order storage location
	PLO  R2 
	LDI  lo(dis_pg_val) 	; R5 points to display memory address
	PLO  R5 
	LDI  lo(free_mem) 	; Rc points to starting address to begin testing
	PLO  RC 
	LDI  0x01 		; RD.0 = starting test bit pattern
	PLO  RD 

test_page:
	GHI  RC 		; Display current page being tested
	STR  R5 
	SEX  R5 
	OUT  4 			; Display page number
	DEC  R5 
	SEX  RC 		; Set X=C

	GHI  RC 		; Save current hi order testing address at R2
	STR  R2 
	INC  R2 
	GLO  RC 		; Save current lo order testing address as R2
	STR  R2 
	DEC  R2 
	GLO  RD 
	STXD 			; Save bit pattern at RC
	INC  RC 		; correct RC
	SD 
	BZ   next_bit 		; Jump if bit was loaded correctly into memory pointed to by RC
	SEQ 			; Set Q on
	BR   $	 		; Error detected, loop on self if error is detected

next_bit:
	GLO  RD  
	SHL 			; Change bit pattern, Shift bit left
	PLO  RD 		; Save bit pattern in RD.0
	BNZ  test_page 		; Jump if not done with bit pattern 01 thru 80
	STR  RC 		; zero out tested memory location

	LDI  0x01 		; Reset bit pattern to hex "01"
	PLO  RD 
	INC  RC 		; increment memory location counter RC

	GHI  RC 
	SDI  0x80 		; Check to see if RC = hex "8000"
	BNZ  test_page 		; If not then check next memory location pointed to by RC

test_ok:
	SEQ			; Flash "Q" LED when done with no errors detected 
	LDI  BLNK_D 		; RA is a countdown timer
	PHI  RA 
	DEC  RA 
	GHI  RA 
	BNZ  $-2	 	; Counter = zero?
	REQ 
	LDI  BLNK_D 		; RA is a countdown timer
	PHI  RA 
	DEC  RA 
	GHI  RA 
	BNZ  $-2 		; Counter = zero?
	BR   test_ok		;keep the "Q" LED flashing

free_mem:
	; the first memory location to be tested

	END

