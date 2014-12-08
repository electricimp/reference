class HT16K33BIG
{
	// Squirrel class for 1.2-inch 4-digit, 7-segment LED displays driven by the HT16K33 controller
	// For example: http://www.adafruit.com/products/1270
	// Communicates with any imp I2C bus
 
	// Availibility: Device

	// Written by Tony Smith (@smittytone) October 2014
	// Version 1.0
	// Copyright 2014 Electric Imp
	// Issued under the MIT license (MIT)

	// Permission is hereby granted, free of charge, to any person obtaining a copy
	// of this software and associated documentation files (the "Software"), to deal
	// in the Software without restriction, including without limitation the rights
	// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	// copies of the Software, and to permit persons to whom the Software is
	// furnished to do so, subject to the following conditions:
	// 	The above copyright notice and this permission notice shall be included in
	// 	all copies or substantial portions of the Software.

	// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	// THE SOFTWARE.
 
	// HT16K33 registers and HT16K33-specific variables
    
	HT16K33_REGISTER_DISPLAY_ON  = "\x81"
	HT16K33_REGISTER_DISPLAY_OFF = "\x80"
	HT16K33_REGISTER_SYSTEM_ON   = "\x21"
	HT16K33_REGISTER_SYSTEM_OFF  = "\x20"
	HT16K33_DISPLAY_ADDRESS      = "\x00"
	HT16K33_I2C_ADDRESS = 0x70
	HT16K33_BLANK_CHAR = 16
	HT16K33_MINUS_CHAR = 17
	HT16K33_CHAR_COUNT = 17

	// Class properties; null for those defined in the Constructor

	_buffer = null
	_digits = null
	_led = null
	_ledAddress = 0

	constructor(impBus, ht16k33Address = 0x70)
	{
		// Parameters:
		// 1. Whichever imp I2C bus is to be used for the HT16K33
		// 2. The HT16K33's I2C address (default: 0x70)

		_led = impBus
		_ledAddress = ht16k33Address << 1

		// _buffer stores the character matrix values for each row of the display

		_buffer = [0x00, 0x00, 0x00, 0x00, 0x00]

		// _digits stores character matrices for 0-9, A-F, blank and minus

		_digits = 
		[0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,  // Chars 0-9
		0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71,  // Chars A-F
		0x00, 0x40] // Space & minus
	}

	function init(clearChar = 16, brightness = 15)
	{
		// Parameters:
		// 1. Integer index for the _digits[] character matrix to zero the display to
		// 2. Integer value for the display brightness, between 0 and 15

		// Configure the I2C bus

		_led.configure(CLOCK_SPEED_100_KHZ)

		// Set the brightness (which of necessity wipes and power cyles the dispay)

		setBrightness(brightness)

		// Clear the screen to the chosen character

		setColon(0x00)
		clearBuffer(clearChar)
		updateDisplay()
	}

	function clearBuffer(clearChar = 16)
	{
		// Fills the buffer with a blank character, or the digits[] character matrix whose index is provided

		if (clearChar < 0 || clearChar > HT16K33_CHAR_COUNT) clearChar = HT16K33_BLANK_CHAR

		// Put the clear_character into the buffer except row 2 (colon row)

		_buffer[0] = _digits[clearChar]
		_buffer[1] = _digits[clearChar]
		_buffer[3] = _digits[clearChar]
		_buffer[4] = _digits[clearChar]
	}

	function setColon(bitVal)
	{
		// Sets the colon at row 0, the colon at row 3 and the raised
		// decimal point at row 5. All are set/unset with a single value
		// stored in _buffer[2]
		// 0x02 - centre colon
		// 0x04 - left colon, lower dot
		// 0x08 - left colon, upper dot
		// 0x10 - decimal point (upper)

		_buffer[2] = bitVal
	}

	function writeChar(rowNum = 0, charVal = 0x7F)
	{
		// Puts the input character matrix (an 8-bit integer) into the specified row,
		// adding a decimal point if required. Character matrix value is calculated by
		// setting the bit(s) representing the segment(s) you want illuminated.
		// Bit-to-segment mapping runs clockwise from the top around the outside of the
		// matrix; the inner segment is bit 6:
		//
		//	    0
		//	    _
		//	5 |   | 1
		//	  |   |
		//	    - <----- 6
		//	4 |   | 2
		//	  | _ |
		//	    3
		//

		if (rowNum < 0 || rowNum > 4 || rowNum == 2) return
		_buffer[rowNum] = charVal
	}

	function writeNumber(rowNum = 0, intVal = 0)
	{
		// Puts the number - ie. index of _digits[] - into the specified row

		if (rowNum < 0 || rowNum > 4 || rowNum == 2) return

		_buffer[rowNum] = _digits[intVal]
	}

	function updateDisplay()
	{
		// Converts the row-indexed buffer[] values into a single, combined
		// string and writes it to the HT16K33 via I2C

		local dataString = HT16K33_DISPLAY_ADDRESS

		for (local i = 0 ; i < 5 ; i++)
		{
			dataString = dataString + _buffer[i].tochar() + "\x00"
		}

		// Write the combined datastring to I2C

		_led.write(_ledAddress, dataString)
	}

	function setBrightness(brightness = 15)
	{
		// This function is called when the app changes the clock's brightness
		// Default: 15

		if (brightness > 15) brightness = 15
		if (brightness < 0) brightness = 0

		brightness = brightness + 224

		// Preserve the current _buffer contents

		local sbuffer = [0,0,0,0,0]

		for (local i = 0, i < 5 ; i++)
		{
		    sbuffer[i] = _buffer[i]
		}

		clearBuffer(HT16K33_BLANK_CHAR)
		updateDisplay()

		// Power cycle the display

		powerDown()
		powerUp()

		// Write the new brightness value to the HT16K33

		_led.write(_ledAddress, brightness.tochar() + "\x00")
		
		// Restore the current _buffer contents

		for (local i = 0, i < 5 ; i++)
		{
		    _buffer[i] = sbuffer[i]
		}

		updateDisplay()
	}

	function powerDown()
	{
		_led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_OFF)
		_led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_OFF)
	}

	function powerUp()
	{
		_led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_ON)
		_led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_ON)
	}
}
