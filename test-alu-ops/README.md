# Test ALU Operations

The code is adapted from the code snippets from
[Wikipedia](https://en.wikipedia.org/wiki/RCA_1802#Code_samples) that
copied the code from the
[A Short Course in Programming](http://www.cosmacelf.com/publications/books/short-course-in-programming.htm)
by *Tom Pittman*,
[Chapter 5 -- Arithmetic and Logic](http://www.cosmacelf.com/publications/books/short-course-in-programming.html#chapter5).

This code snippet example is a diagnostic routine that tests ALU
(Arithmetic and Logic Unit) Operations.

It requires three inputs: an opcode, executed at location 0029,
and two data bytes, one stored in location 0060 (via R6) and one stored
in location 0061 (same address register, but incremented). It does its
operation and then puts the result back into location 0060 to display it.
If the result is zero, the program also turns Q on.
So that you will know which input is expected, the display will show
`00` when it is waiting for an opcode, `01` when waiting for the first
operand, and `02` when waiting for the second operand.
After it has performed the operation, the result also becomes the first
operand for the next time through the loop, so you only have to key in
the second operand for each successive time through. Of course, any
time you want to put a new opcode or first operand, you can reset the
computer and run the program again.

**Note**: The above routine presumes that the CDP1802 microprocessor is in
an initial reset state (or that it has been set as such prior to
executing this code). Therefore, the program counter (PC) and the X
indirect register 'pointer' are both set to 16-bit register R0.




SPDX-FileCopyrightText: © 2024 Damir Maleničić,
SPDX-License-Identifier: MIT 