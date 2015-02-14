# VS10XX Audio Encoder/Decoder

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [VS10XX Family from VLSI](http://www.vlsi.fi/en/support/evaluationboards/vs10xxprotoboard.html) allows easy encoding and decoding of many common compressed audio formats with a simple SPI interface. Some parts in the family also offer a headphone amplifier, micrphone amplifier, and many related analog front-end features. This driver class was written for the [VS1063 Breakout Board, available from Sparkfun](https://www.sparkfun.com/products/11684). The VS1063 can decode Ogg Vorbis/MP3/AAC/WMA audio and encode MP3, IMA ADPCM, and Ogg Vorbis. 

This class is unfinished.

## Hardware Setup

The table below shows how to connect an Electric Imp breakout board to the VS1063 breakout board from Sparkfun

| VS10XX Breakout Pin | Imp Breakout Pin | Notes |
| ----------------- | ---------------- | ----- |
| V<sub>CC</sub> | 3V3 | Power |
| GND | GND |  |
| SO | Imp SPI MISO Pin (Ex: Pin2) | |
| SI | Imp SPI MOSI Pin (Ex: Pin7) | |
| SCLK | Imp SPI SCLK Pin (Ex: Pin5) ||
| CS | Any Imp GPIO | DIGITAL_OUT |
| RST | Any Imp GPIO | DIGITAL_OUT |
| DREQ | Any Imp GPIO | DIGITAL_IN |
| BSYNC | Any Imp GPIO | DIGITAL_OUT (XDCS) |

The debug UART can also be connected to the imp but is not yet implemented in this class

## Instantiation

SPI interface and GPIO pins must be configured before passing to the constructor. 

```
cs_l.configure(DIGITAL_OUT, 1);
dcs_l.configure(DIGITAL_OUT, 1);
rst_l.configure(DIGITAL_OUT, 1);
dreq_l.configure(DIGITAL_IN);
spi.configure(CLOCK_IDLE_LOW, SPICLK_LOW);
uart.configure(UARTBAUD, 8, PARITY_NONE, 1, NO_CTSRTS);

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart);
```

## Usage

Coming Soon.