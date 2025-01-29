; -----------------------------------------------------------------------------
; SPDX-FileCopyrightText: © 2024 Damir Maleničić,
; SPDX-License-Identifier: MIT
; -----------------------------------------------------------------------------
; The port of Kill the Bit game for Altair by Dean McDaniel, May 15, 1975. 
; <https://altairclone.com/downloads/killbits.pdf>
; -----------------------------------------------------------------------------
; Kill the rotating bit. If you miss the lit bit, another bit turns on, leaving
; two bits to destroy.
; Quickly toggle the correct switch on and off at the right moment.
; Don't leave the switch in the on position, or the game will pause.
; -----------------------------------------------------------------------------
; Following is a port to the RCA1802 processor for the 1802 Membership Card
; board <https://www.sunrise-ev.com/1802.htm>.
;
; Compared with the original, it is a significantly longer program :-(.
;
; It targets different hardware and processor...
; As my first 1802 program, there is room for optimizations, but it also does a
; bit more than the original :-).
; It attempts to debounce switches and detects when the player has won the game.
;
; When you kill all bits :-), the program lits LEDs 7 and 0 and flashes LEDS 2-5.
; If you want to play again, toggle switch 7.
; If you want to exit the game and return to The 1802 Membership Card ROM
; monitor program, toggle switch 0.
; -----------------------------------------------------------------------------
; I use [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/), but
; the code should be reasonably portable to other 1802 assemblers.
; The following are the assembling and linking instructions:
; ```
; asl -cpu 1802 -L killthebit.asm
; p2hex killthebit.p killthebit.hex 
; ```
; The resulting `killthebit.hex` file can be loaded into The 1802 Membership
; Card using monitor L command. On Linux, run `cat killthebit.hex`, copy
; the output, and paste it to the monitor, then type the `R0000` command in the
; monitor or just toggle in CLEAR and RUN at the board :-).
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


; register aliases ------------------------------------------------------------
; This may also be hardwired in the assembler of your choice.


R0	EQU	0
RB	EQU	11
RC	EQU	12
RD	EQU	13
RE	EQU	14
RF	EQU	15


; Game Control Constants ------------------------------------------------------
SPEED	EQU	0x40	; change to speed up or slow down the game


	; For maximum portability, the `ORG` directive should point to the
	; beginning of a RCA 1802 memory page (256 byte boundary).


	ORG	0


	; Initialization ------------------------------------------------------
	; RF	- points to the (tmp) variable that is used while debouncing
	;	  switches
	; RE	- delay loop counter
	; RD	- points to the (pattern) variable that holds a bit pattern
	; RC	- points to the (switches) variable that holds the last toggled
	;	  switch
	; RB	- PC for the subroutine that reads and debounces switches
	;	  (rd_switch)
	; R0	- PC for the main program 
	;
	; It assumes that the program, subroutine, and variables are on the same
	; memory page

start:

	LDI	lo(tmp)		; Set the (tmp) variable location
	PLO	RF		;  to the RF register.
	LDI	lo(pattern)	; Set the (pattern) variable location
	PLO	RD		;  to the RD register.
	LDI	lo(switches)	; Set the (switches) variable location
	PLO	RC		;  to the RC register.
	LDI	lo(rd_switch)	; Set the (rd_switch) subroutine location
	PLO	RB		;  to the RB register.
	LDI	hi($)		; To make the program relocatable:
	PHI	RF		; - Load a correct `hi` part of the address of (tmp),
	PHI	RD		; - Load a correct `hi` part of the address of (pattern),
	PHI	RC		; - Load a correct `hi` part of the address of (switches),
	PHI	RB		; - Load a correct `hi` part of the address of (rd_switch).
	LDI	0		; The lower part of a delay loop counter is 0
	PLO	RE		;  and should be set to lo(RE).

	STR	RC		; Reset the value in (switches).
	LDI	1		; Load the initial value for the (pattern) variable.
	STR	RD		; Set the initial value into the (pattern) variable.

	; The Main Loop for the Game ------------------------------------------
	; Continuously:
	; - Display the bit-pattern on LEDs,
	; - Loop for a split-second to enable a player to toggle a switch:
	;   - Debounce the switch if toggled,
	; - Apply the toggled switch to the bit pattern,
	; - Rotate the bit-pattern,
	; - If all bits are "killed" exit the loop and offer the user a choice to:
	;    - Play again by jumping to `start` or
	;    - Exit to the monitor program,
	; - Otherwise, continue with the main loop for the game.
main:
	; Display the Pattern -------------------------------------------------
	SEX	RD		; Select `RD` as the output data pointer.
	OUT	4		; Display the bit pattern, side-effect `RD++`.
	DEC	RD		; Restore `RD` with `RD--`.
	LDI	SPEED		; Initialize the delay loop control value.
	PHI	RE		; Set the delay loop control value to `RE`.

	; Call the Subroutine that Reads and Debounces Switches ---------------
	SEP	RB		; Call the subroutine `rd_switch`.
				; The register `RC` holds the bit pattern
				; indicating a toggled switch.

	; Apply Toggled Switch to a Pattern to Kill or Introduce a Bit --------
	; It assumes 1 on a toggled switch position, so `XOR` will toggle the
	; corresponding bit in the rotating bit pattern.
apply_switch:
	LDN	RD		; Load the (pattern) into the `D` register.
	SEX	RC		; Switch the memory pointer to the `RC` register
				; that points to the variable `(switches)`.
	XOR			; `XOR` with (switches).

	; Rotate the Bit Pattern 1 Position to the Left -----------------------
	; Instructions `SHRC`/`RSHR` will not do so because we don't want to 
	; use the carry bit through the `DL` registers.
	; The bit 7 needs to be rotated directly into the bit 0.
shift:
	SHL			; Shift the value in `D` left, MSB->DF, 0->LSB.
	BNF	msb0		; If the value in `DF` is 0, skip the next instruction.
	ORI	1		; Set the LSB of the `D` register to 1.
msb0:
	STR	RD		; Store the result in the (pattern) variable.
	LDN	RF		; Register `RF` is 0 at this point. This is a 
				;  shorter version of `LDI 0`.
	STR	RC		; The variable (switches) value is consumed, and
				;  reset for the next round.

	; If the Value in the Variable (pattern) is 0, You Have Won -----------
	; This section detects it.
	; If it can not detect it, then the game continues.
	LDN	RD		; Load the value from the variable (pattern).
	BNZ	main		; If not all bits are killed, continue with the
				; main loop.

	; You Won! ------------------------------------------------------------
	; TODO
	; When I find out how the monitor program prints messages, I will print
	; the congratulations message and explain what to do next.
	; For now, it is only the instructions written in this comment:
	; - lit the LEDs 0 and 7, and flash LEDs 2-5.
	; - If the user toggles the switch for bit 7, continue with the next game.
	; - If the user toggles the switch for bit 0, exit to the monitor.
	LDI	0xBD		; Set MSB and LSB to 1, and the initial pattern
				; for flashing LEDs 2-5.
	STR	RD		; Store the end of the game pattern to the
				; variable (pattern).
yes_no_loop:
	SEX	RD		; Select register `RD` as the output data pointer,
				; i.e., we are selecting the variable (pattern).
	LDI	0x24		; Define the mask for toggling bits 2-5.
	XOR			; `XOR` the value in the variable (pattern) and
				; the mask.
	STR	RD		; Store the result to the variable (pattern).
	OUT	4		; Display the value in the variable (pattern),
				; side-effect `RD++`.
	DEC	RD		; Restore RD with `RD--`.

	SEP	RB		; Call the subroutine `rd_switch` to read and
				; debounce switches.
	SEX	RC		; The register `RC` holds the bit pattern
				; indicating a toggled switch.

	; Check If the Play Again or End of the Game Switch Has Been Toggled --
	LDI	0x81		; Define the mask for the relevant switches.
	AND			; Check if it has been toggled.
	SHL			; Shift Left to move the MSB to DF (carry).
	BDF	start		; The MSB was set, the play again switch was toggled.
	BNZ	reset		; The LSB was set, the end the game switch was toggled.
	BR	yes_no_loop	; No relevant switch was toggled, loop to let
				; the user provide the choice.

	; The Following Emulates a Board Reset --------------------------------
	; Clear LEDs, reset the `P` and the `X` registers, and then execute a 
	; long branch to the ROM to the location `8000H`.
	; Note: resetting the `P` register is not needed, it is already 0.
reset:
	SEX	RD		; Select the `RD` register as the output data
				; pointer. We will manipulate the (pattern) variable.
	LDI	0		; Define the mask to clear LEDs.
	STR	RD		; Store the mask to the variable (pattern).
	OUT	4		; Output the variable (pattern) value to clear LEDs;
				; side-effect RD++ is ignored during the reset.
	SEX	0		; Reset the `X` register.
	LBR	monitor		; Transfer the control to the ROM at the location
				; `8000H`.
	; The End of The Main Loop of The Game --------------------------------	


	; The Subroutine That Reads And Debounces Switches --------------------
	; It expects:
	; - The register `R0` to be the program counter for a callee,
	; - The register `RF` to point to the variable (tmp),
	; - The register `RE` to have a delay loop counter value set,
	; - The register `RC` to point to the variable (switches).
	; It uses:
	; - The register `RB` as its own program counter,
	; - The variable (tmp) as temporary storage. Its value is not preserved.
	; It returns:
	; - The last non-zero value of a switch toggle is preserved in the
	;   variable (switches).
ret_rd_sw:
	SEP	R0	      ; Restore the callee program counter.
	
	; The external loop controls the overall pace of the game.
rd_switch:
	SEX	RF		; Select the register `RF` as the input data pointer.
				; The subroutine uses the variable (tmp).
	INP	4		; Read switches.
	LDN	RF		; Load the value from variable (tmp) to the
				; `D` register.
	BZ	delay		; Skip the next instruction if all switches are off.
	STR	RC		; Store the last read value in the variable (switches).

	; The internal delay loop defines the time between reads of switches (debouncing).
delay:
	DEC	RE		; Decrement the delay loop counter.
	GLO	RE		; Load the register `RE` lower byte to the register `D`.
	BNZ	delay		; Continue with the inner delay loop if the register `D`
				; content is not 0.
	GHI	RE		; Load the register `RE` higher byte to the register `D`.
	BNZ	rd_switch	; Continue with the outer delay loop if the register `D`
				; content is not 0.

	; All switches must be off at this point. If not so, wait till
	; the user turns the switch off.
check_sw_off:
	INP	4		; Read switches, the register `RF` is still the
				; memory pointer, i.e., the result will be written
				; into the variable (tmp).
	LDN	RF		; Load the last state of the switches.
	BNZ	check_sw_off	; If not all switches are off, loop.

	; We have detected if a switch is toggled within a predefined time interval
	; and ensured that all switches are now in the off position.
	BR	ret_rd_sw	; Return from the subroutine.


	; The Variables -------------------------------------------------------

tmp:		DB	0
pattern:	DB	1	; It holds a bit pattern that is to be displayed by LEDs.
switches:	DB	0	; It holds a bit pattern that represents a toggled switch.


	ORG	0x8000

monitor:
