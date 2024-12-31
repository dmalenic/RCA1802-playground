# Kill The Bit

This is my second port of [this](https://altairclone.com/downloads/killbits.pdf), a beautiful game to another exotic old architecture. The first one was ported to a
revived [emulator](https://dmalenic.github.io/mc14500b/mc14500-sim/index.html) for the 1-bit Motorola Industrial Control Unit [MC14500B ICU](https://en.wikipedia.org/wiki/Motorola_MC14500B). More information on the
emulator can be found at [GitHub page](https://github.com/dmalenic/mc14500b/tree/main/mc14500-sim)

Compared to the original Dean McDaniel implementation for Altair 8800, my program is more than four times longer :-(.
The original uses 24 bytes. In contrast, my version uses about 100. This is my first real 1802 program; there is room
for optimizations ;-). Suggestions for code improvements are welcome; feature requests are a bit less. It targets
different hardware and processor, and it does a bit more than the original :-) :

- it debounces switches,
- it integrates with [The 1802 Membership Card](https://www.sunrise-ev.com/1802.htm) ROM monitor program,
- it detects when a player has won the game and offers a choice to:

  - play again,
  - or gracefully exit the game to the ROM monitor program.

  A sort of *Congratulations, you won!! Do you want to play again or exit the game?* dialog was implemented using 8 LEDs and
  2 switches :-).




SPDX-FileCopyrightText: © 2024 Damir Maleničić,
SPDX-License-Identifier: MIT