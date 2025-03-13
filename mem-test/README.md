# Memory Test Program for The 1802 Membership Card

Here is a memory test program for the 1802 Membership card.
It is a bit-march type test of the 32K RAM (62256) however
it doesn't check for cross-talk between the memory address lines.

This version does check for data line cross-talk only.

Running this software on the 1802 Membership Card Rev L.1
will take a minute or two to complete.

The LED's will display the current memory page being tested.
If there is an error detected the `Q` LED will come on and stay on.
If an error is detected the address that caused the error is stored
at memory location hex `0002` (hi order) and hex `0003` (lo order).
If there is no errors detected the data LED's will appear to count
from `00` to `7F`, when it is done testing and no errors have been
detected the `Q` LED will flash (Blink) on and off and the data
LED's will display hex `7F`.
