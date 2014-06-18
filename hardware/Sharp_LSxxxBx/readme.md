Driver for the LSxxxBx Sharp Memory LCD family
===================================

Author: [Juan Albanell](https://github.com/juanderful11/)

Driver class for [LSxxxBx Sharp Memory LCD family](http://www.sharpmemorylcd.com/memorylcd.html).

Built with [Adafruit's 1.3" display breakout](https://learn.adafruit.com/adafruit-sharp-memory-display-breakout/overview).

[Here is the datasheet](http://www.sharpmemorylcd.com/resources/LS013B4DN04_Application_Info.pdf) that we used when writing this class.

## Hardware Setup
This display uses write only SPI which the imp emulates using two wire SPI in combination with a CS pin:

|  eImp  |  Breakout | 
|--------|-----------|
| Pin 2  | CS        |
| Pin 5  | Clock     |
| Pin 7  | MOSI      |

The power supply for the display depends on the model specifications, if 3.3V is the typical it can be connected to the Imp's 3.3V pin, otherwise an external power source is necessary in order to be within specs.

The display's VCOM can either be generated in hardware or software: 

- If hardware mode is chosen then the EXTMD has to be tied to VDD. Furthermore the EXTIN pin in the breakout has to be connected to an oscillator of your choice that produces the correct VCOM frequency for your model. 
- If software mode is chosen then the EXTMD has to be tied to Ground. The VCOM frequency is regulated by the code.