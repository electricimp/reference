#Neopixel Class
This class allows the imp to drive WS2812 and WS2812B ["NeoPixel"](http://www.adafruit.com/products/1312) LEDs. The "Neopixel" is an all-in-one RGB LED with integrated shift register and constant-current driver. The parts are daisy-chained, and a proprietary one-wire protocol is used to send data to the chain of LEDs. Thus, each pixel is individually addressable, which allows the part to be used for a wide range of effects animations.

Some example hardware that uses the WS2812 or WS2812B:

* [40 RGB LED Pixel Matrix](http://www.adafruit.com/products/1430)
* [60 LED - 1m strip](http://www.adafruit.com/products/1138)
* [30 LED - 1m strip](http://www.adafruit.com/products/1376)
* [NeoPixel Stick](http://www.adafruit.com/products/1426)

#Hardware Configuration
The WS2812 and WS2812B require a 5V power supply. Each pixel can draw up to 60 mA when displaying white in full brightness, so be sure to size your power supply appropriately. Undersized power supplies can cause glitching, or failure to produce any light at all.

| Imp Pin | WS2812 Pin |
| --- |
| Pin7 (SPI257 MOSI) | Data In ("Din") |

