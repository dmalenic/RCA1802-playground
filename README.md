# RCA 1802 Playground

I have acquired two excellent [RCA 1802](https://en.wikipedia.org/wiki/RCA_1802) retro shields:

- [8-bit force - RetroShield 1802](https://www.tindie.com/products/8bitforce/retroshield-1802-for-arduino-mega/) for Arduino Mega and Teensy 4.1,

- [The 1802 Membership Card](https://www.sunrise-ev.com/1802.htm);

and started investigating this unconventional microprocessor architecture from the mid-1970s.

The following projects are the result of my early investigation:

- [test-programs](test-programs/README.md) holds examples from
  [Operating and Testing the 1802 Membership Card](https://www.retrotechnology.com/memship/mship_test.html),
- [test-alu-ops](test-alu-ops/README.md) is the example taken from the
  [Wikipedia Article](https://en.wikipedia.org/wiki/RCA_1802#Code_samples) on RCA1802
  which took it from 
  [A Short Course in Programming](http://www.cosmacelf.com/publications/books/short-course-in-programming.htm)
  by *Tom Pittman*,
  [Chapter 5 -- Arithmetic and Logic](http://www.cosmacelf.com/publications/books/short-course-in-programming.html#chapter5),
- the [combination-lock-interval-timer](combination-lock-interval-timer/README.md) is based on examples from an
  [old magazine](https://www.atarimagazines.com/computeii/issue3/page50.php),
- the [mem-test](mem-test/README.md) is an extension of Chack Yakym's [mem-test](https://www.retrotechnology.com/memship/yakym_1802.zip).
- my [port](killthebit/README.md) of the legendary Altair 8800 game [Killbits](https://altairclone.com/downloads/killbits.pdf) to [The 1802 Membership Card](https://www.sunrise-ev.com/1802.htm).
- [8 queens](8-queens/README.md) problem is an investigation on how RCA 1802 calls a subroutine.
- [fibonacci](fibonacci/README.md) makes RCA 1802 go 32 bit.

I use Linux and [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/) written by 
[Alfred Arnold](mailto:alfred@ccac.rwth-aachen.de). The examples might need some tweaking to
adapt to the assembler of your choice.

All programs are written to load at location `0000H`. Some are relocatable as long as they are loaded to the beginning of
1802 page (offset multiple of 256).

To run the examples:
1. boot *Membership Card* to *Monitor ROM*
   1. Make sure you have configured your terminal program as described in
     [Membership Card Manual, rev.L1](https://www.sunrise-ev.com/MembershipCard/memberl1.pdf) page 15 section
     *Operation without a Front Panel card*:
      1. 4800 baud, 8 bits, no parity, 1 stop,
      2. No hardware or software handshaking,
      3. Set the *Pacing* or *Transmit Delay* to 10 ms/char and 250 ms/line (or more),
      4. Set the `ENTER` key to send only the ASCII <CR> (or type Ctrl+M).
   2. press `ENTER` to get the Monitor Prompt.
2. Execute `make all` to build the `hex` files,
3. Press `L` on the monitor prompt to get the response `Ready to load program`,
4. On your computer, execute `cat example_directory/example_program.hex`,
5. Copy the output and paste it into the Monitor program window,
6. After a while, the monitor will respond with the `File loaded successfully` and the prompt,
7. Type the `R0000` and press `ENTER`,
8. The monitor will respond with `Currently running your program` and transfer the control to the program you have just
   loaded.

SPDX-FileCopyrightText: © 2024 Damir Maleničić,
SPDX-License-Identifier: MIT