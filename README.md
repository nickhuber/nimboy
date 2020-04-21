This is intended to be a Game Boy emulator, written in Nim.

There are 2 goals:
- to better understand Nim
- understand how emulators work

It is not advised to actually use this software, there are likely better
emulators out there.

On windows, using scoop:
  * scoop add extras
  * scoop install sdl2

To run tests:
  * nimble test

To compile and run:
  * nimble run nimboy /path/to/rom.gb
