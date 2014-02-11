Partial Driver for FT800 Embedded Video Engine
===================================

Author: [Tom Byrne](https://github.com/tombrew/)

Driver class for a [FTDI FT800 Embedded Video Engine](http://www.ftdichip.com/Support/Documents/ProgramGuides/FT800%20Programmers%20Guide.pdf).

The FT800 is underlying hardware for the [Gameduino 2](http://excamera.com/sphinx/gameduino2/).

## Hardware Setup
This class requires a SPI interface and three GPIO pins to use. In the example, the device is connected to an Electric Imp breakout board as follows

| Imp Pin | EVE Pin | Purpose |
|-----------------------------|
|   Pin1  | SCK     | SPI Clock |
|   Pin2  | PD#     | Power Down, Active Low |
|   Pin5  | INT#    | Interrupt, Active Low |
|   Pin7  | CS#     | SPI Chip Select, Active Low |
|   Pin8  | MOSI    | SPI Master Out, Slave In |
|   Pin9  | MISO    | SPI Master In, Slave Out |