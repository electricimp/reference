L6470 "dSPIN" Stepper Motor Driver
===================================

Author: [Tom Byrne](https://github.com/tombrew/)

Driver class for a [L6470 "dSPIN" Stepper Motor Driver IC with SPI interface](http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf
).

Sparkfun offers a [breakout](https://www.sparkfun.com/products/11611) for this IC, which makes getting started with an Imp and a stepper motor quite straightforward.

This class implements most of the L6470's feature list:

 *  Programmable home and mark positions
 *  Programmable min and max speed
 *  Microstepping up to 1/128 step
 *  Goto commands which can specify a direction or omit a direction to take the shortest path
 *  Programmable thermal compensation

## Hardware Setup
The Sparkfun breakout includes more I/O than an Imp card has available, but use of the SYNC and BUSY pins is not required. These pins can easily be used with an Imp module, but are not implemented in this class. Either of the Imp's SPI interfaces can be used, and any Imp GPIO can be used for any L6470 GPIO. Here is an example configuration (which matches the code):

| Imp Pin | L6470 Breakout Pin | Description |
| ------- | ------------------ | ----------- |
| Pin1    | CK                 | SPI Clock   |
| Pin2    | CSN                | Chip Select, Active Low |
| Pin5    | STBY               | L6470 Reset, Active Low |
| Pin7    | FLGN               | L6470 Flag Output, Active Low |
| Pin8    | SDI                | SPI MOSI. Data from Imp to L6470 |
| Pin9    | SDO                | SPI MISO. Data from L6470 to Imp |
