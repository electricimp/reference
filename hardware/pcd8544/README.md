PCD8544 LCD Driver
===================

Class for using an LCD with a PCD8544 driver chip with the Imp.

The screen used to test this class was a "Nokia 5110" monochrome LCD that can be purchased from Adafruit:
http://www.adafruit.com/products/338

Hardware
=========
Add a pullup resistor (we like 100KΩ) between Vcc and RESET
Add a pulldown resistor (we like 100KΩ) between CLK and GND


Notes
======
This class, by itself, can display a text string using a built-in font. It can be combined with agent code to enable display of black & white bitmap images (or any pixel data, really, as long as you format it properly.)
For examples (such as web-based text input and image display) visit https://github.com/electricimp/examples/ and navigate to the 'pcd8544' directory

The driver chip datasheet can be found at http://www.nxp.com/documents/data_sheet/PCD8544_1.pdf

NOTES:
There must be a 100k pull-down resistor between CLK and GND, and a 100k pull-up resistor between RST and VCC.
