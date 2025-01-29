# Interval Timer Combination Lock

The [COSMAC Quickies](https://www.atarimagazines.com/computeii/issue3/page50.php) examples from an archive of an old magazine
[COMPUTE II ISSUE 3 / AUGUST/SEPTEMBER 1980 / PAGE 50](https://www.atarimagazines.com/computeii/covers/showcover.php?issue=issue3).

This example is a tweak of the code presented in the article. The program waits for a proper 3-byte combination to set
the 1802 `Q` output flip-flop `ON`. The `Q` is then active for approximately 15 seconds.

The combination lock part of the program in which the operator wishing access to set the `Q` flip-flop must first enter
three predetermined, two-digit hex numbers into memory in the proper sequence is based on the
`Listing 2 — Combination Lock` example from the [magazine article](https://www.atarimagazines.com/computeii/issue3/page50.php) mentioned above.

Each two-hex-digit data byte is entered using input switches and confirmed by pressing and releasing the `IN` button.

As the data bytes for the *combination* are entered into memory, the 1802 performs a logical exclusive or with each byte
in turn, using data stored at addresses `byte1+1`, `byte2+1` and `byte3+1` respectively. If the wrong number is entered
at any point, the program jumps to the error subroutine beginning at location `error_sub`, which momentarily outputs an
`EE`to the data display while executing a three-second timing delay, then outputs a `00` to the data display and jumps
back to the start of the `combination_lock` routine.

As written, you would have to enter `CA` (defined at the program location `byte1+1`), `FE` (defined at the program
location `byte2+1`), and `42` (defined at the program location `byte3+1`) to turn the `Q` flip-flop from logic `0` to
logic `1`. You can change the data bytes for any combination you wish. The chances of someone solving the combination
decrease if you add more numbers.

Once the proper number sequence has been entered, the `Q` flip-flop goes `ON` and stays that way for a predetermined
time. This part is based on the `Listing 1 — Interval Timer` from the [magazine article](https://www.atarimagazines.com/computeii/issue3/page50.php) mentioned above.

The program uses the register `E`, one of the 1802's sixteen, sixteen-bit general purpose registers, as a
timer that continually counts down from hex `FFFF`. When the register `E` reaches zero, a fact discovered by testing
both high and low bytes, the register `F` is incremented by one. The `F` register is then tested to see if the
*predetermined value* has been set. If not, the timing loop continues.

An interval timing program can be set for any delay from just below 0.8 seconds (if the *predetermined value* byte at the
location `loop_param + 1` is `1`) to just over 202 seconds (if the *predetermined value* byte has value `0`) by varying only
the data byte at that location.

By further nesting the loop with yet another register in a similar way as the register `F` is being used, it is possible
to extend the timer to almost 14 hrs and 22 minutes. It would be easy to establish the interval to days, months, and more by adding more registers. The 1802 has plenty of registers for such usage.

The data bytes in locations `loop_param+1` and `tmp` can be used to fine-tune the timer duration.

The interval timer program segment starts by setting the `Q` flip-flop high, indicating the start of the timer. Once the proper value for the reg `F` has been reached, 1802 resets its `Q` flip-flop off.

When `Q` goes off, the user can rerun the program or go to the 1802 Membership Card Monitor program. For the latter, the user needs to set the switches to match the value shown on a display and then press and release the `IN` button.
The program repeats if the combination of switches does not match the displayed value after releasing the `IN` button.


SPDX-FileCopyrightText: © 2024 Damir Maleničić,
SPDX-License-Identifier: MIT