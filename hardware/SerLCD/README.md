Serial Display Driver for PIC16LF88
===================================

Driver class for a [Sparkfun SerLCD display](https://www.sparkfun.com/products/9067).

Hardware Setup
==============

Connect RX pin of the LCD Display to PIN5 on the imp.

Contributors
============

Author: [Jason Snell](https://github.com/asm/)

Example Code
============

```
// Configure the UART port
local port0 = hardware.uart57
port0.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);

// Boot!
server.log("booting!");

// Allocate and start a screen
screen <- SerLCD(port0);
screen.clear_screen();
screen.start();

screen.set0("Hello"); // Write the first line
screen.set1("World"); // Write the second line
```

