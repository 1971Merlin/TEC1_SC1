# TEC1_SC1
General code for the TEC-1 and SC-1 computers


## rammap.asm

rammap is a basic tool to check how much RAM the machine has, by writing various bit test patterns to memory locations starting immediately after the ROM, and verifying the written values can be read back accurately. The code only tests for first byte of every 1k block, as memory chips generlaly are at least 1k in size.

A proper memory tester would check every byte -- and you can adjust the value of adinc (make it = 1) if you want to test every byte.

Ignore the keyboard code -- it presently doesn't do anything; it ended up there as i used code from a different project as a framework. I was originally going to have a 'press any key to test the next block' or 're-test' type thing, but never got around to it ;)

