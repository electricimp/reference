Pervasive Displays Epaper Panel Driver
==============
This class drives a [Pervasive Displays Epaper Panel](http://repaper.org/). 

The Epaper Agent recieves images in the WIF Image format. This uses 1 bit per pixel. The agent expands this format to the 2 bits per pixel required by the panel (black, white, don't care) before relaying to the device. 

Contributors
===================================
Tom Byrne

Usage
===================================
This class can be used with an Electric Imp module connected to the Pervasive Displays development board, or with [hardware which integrates the panel](http://electricimp.com/docs/hardware/resources/reference-designs/vanessa/). Because of the large number of GPIO pins required to use the Pervasive panel, the Electric Imp card cannot be used. In the example, the hardware is configured as follows:

| Pin | Job |
|-----|-----|
| Pin1 | EPD Chip Select (active-low) |
| Pin2 | SPI MISO |
| Pin5 | SPI SCLK |
| Pin6 | Panel BUSY |
| Pin7 | SPI MOSI |
| Pin8 | Analog Temperature Sensor Input (ADC) |
| Pin9 | PWM |
| PinA | Panel Reset Active Low |
| PinB | Panel Power Enable |
| PinC | Panel High-Voltage Rail Discharge Enable |
| PinD | Panel Border Control |
| PinE | SPI FLASH Chip Select Active Low | 