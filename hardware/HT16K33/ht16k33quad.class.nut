class HT16K33QUAD
{
	// Squirrel class for 0.54-inch 4-digit, 14-segment LED displays driven by the HT16K33 controller
	// For example: http://www.adafruit.com/product/1912
	// Communicates with any imp I2C bus

	// Availibility: Device

	// Written by Tony Smith (@smittytone) August/September 2014
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
	HT16K33_BLANK_CHAR = 62
	HT16K33_MINUS_CHAR = 17
	HT16K33_CHAR_COUNT = 77
	HT16K33_DP_VALUE = 0x4000

	// Class properties; those defined in the Constructor must be null

	_buffer = null
	_digits = null
	_led = null
	_ledAddress = 0

	constructor(impI2Cbus, ht16k33Address = 0x70)
	{
		// Parameters:
		// 1. Whichever imp I2C bus is to be used for the HT16K33
		// 2. The HT16K33's I2C address (default: 0x70)

		_led = impI2Cbus
		_ledAaddress = ht16k33Address << 1

		// Buffer stores the character matrix values for each row of the display
		// Quad LED has 16-bit values. There are four individual characters per display

		_buffer = [0x0000, 0x0000, 0x0000, 0x0000]

		// digits store character matrices for 0-9, A-F, a-z, space and various symbols

		_digits = [
		0x003F, 0x1200, 0x00DB, 0x008F, 0x12E0, 0x00ED, 0x00FD, 0x0C01, 0x00FF, 0x00EF, // 0-9
		0x00F7, 0x128F, 0x0039, 0x120F, 0x0079, 0x0071, // A-F
		0x00BD, 0x00F6, 0x1200, 0x001E, 0x2470, 0x0038, 0x0536, 0x2136, 0x003F, 0x00F3, // G-P
		0x203F, 0x20F3, 0x00ED, 0x1201, 0x003E, 0x0C30, 0x2836, 0x2D00, 0x1500, 0x0C09, // Q-Z
		0x1058, 0x2078, 0x00D8, 0x088E, 0x0858, 0x0C80, 0x048E, 0x1070, 0x1000, 0x000E, // a-j
		0x3600, 0x0030, 0x10D4, 0x1050, 0x00DC, 0x0170, 0x0486, 0x0050, 0x2088, 0x0078, // k-t
		0x001C, 0x2004, 0x2814, 0x28C0, 0x200C, 0x0848, // u-z
		0x0000, // blank
		0x0006, 0x0220, 0x12CE, 0x12ED, 0x0C24, 0x235D, 0x0400, 0x2400, 0x0900, 0x3FC0,
		0x12C0, 0x0800, 0x00C0, 0x0000, 0x0C00, 0x10BD // Symbols
		]
	}

	function init(clearChar = 62, brightness = 15)
	{
		// Initialises the display
		//
		// Parameters:
		// 1. Integer index for the _digits[] character matrix to zero the display to; default: space
		// 2. Integer value for the display brightness, between 0 and 15; default: 15

		// Configure the I2C bus

		_led.configure(CLOCK_SPEED_100_KHZ)

        	// Clear the character buffer

		clearBuffer(clearChar)

		// Set the brightness (which also wipes and power cyles the display)

		setBrightness(brightness)
	}

	function clearBuffer(clearChar = 62)
	{
		// Fills the buffer with a blank character, or the _digits[] character matrix whose index is provided
		// Parameters:
		// 1. Integer index for the _digits[] character matrix to zero the display to; default: space

		if (clearCharacter < 0 || clearCharacter > HT16K33_CHAR_COUNT) clearChar = HT16K33_BLANK_CHAR

		_buffer[0] = _digits[clearChar]
		_buffer[1] = _digits[clearChar]
		_buffer[2] = _digits[clearChar]
		_buffer[3] = _digits[clearChar]
	}

	function writeChar(rowNumber = 0, charVal = 0xFFFF, hasDot = false)
	{
		// Puts the input character matrix (a 16-bit integer) into the specified row,
		// adding a decimal point if required. Character matrix value is calculated by
		// setting the bit(s) representing the segment(s) you want illuminated:
		//
		//	    0			    9
		//	    _
		//	5 |   | 1		8 \ | / 10
		//	  |   |			   \|/
		//	      			 6 - - 7
		//	4 |   | 2		   /|\
		//	  | _ |		   11 / | \ 13		. 14
		//	    3			    12
		//
		// Bit 14 is the period, but this is set with parameter 3
		// Nb. Bit 15 is not read by the display
		//
		// Parameters:
		// 1. Integer index indicating the display character to write to; default: 0 (left-most)
		// 2. '16-bit' integer value for the LED segments to illuminate; default: 0xFFFF (all on)
		// 3. Boolean value specifying whether the decimal poing is lit; default: false

		// Bail on incorrect row numbers or character values

		if (rowNumber < 0 || rowNumber > 3) return
		if (charVal < 0 || charVal > 0xFFFF) return

		// Write the character to the _buffer[]

		if (hasDot) char_value = charVal | HT16K33_DP_VALUE
		_buffer[rowNumber] = charVal
	}

	function writeNumber(rowNum = 0, intVal = 0, hasDot = false)
	{
		// Puts the number - ie. index of _digits[] - into the specified row,
		// adding a decimal point if required
		//
		// Parameters:
		// 1. Integer index indicating the display character to write to; default: 0 (left-most)
		// 2. Integer value for number to write; default: 0
		// 3. Boolean value specifying whether the decimal poing is lit; default: false

		// Bail on incorrect row numbers or character values

		if (intVal < 0 || intVal > 15) return
		if (rowNum < 0 || rowNum > 3) return

		setBufferValue(rowNum, intVal, hasDot)
	}

    function writeLetter(rowNum = 0, ascii = 65, hasDot = false)
    {
    	// Puts the number - ie. index of digits[] - into the specified row,
		// adding a decimal point if required
        // Parameters:
		// 1. Integer index indicating the display character to write to; default: 0 (left-most)
		// 2. Integer Ascii value for character to write; default: A
		// 3. Boolean value specifying whether the decimal poing is lit; default: false

		// Bail on incorrect row number

        if (rowNum < 0 || rowNum > 3) return

        local intVal = 0

        if (ascii > 31 && ascii < 48) intVal = ascii + 30
        if (ascii > 47 && ascii < 58) intVal = ascii - 48
        if (ascii > 64 && ascii < 91) intVal = ascii - 55
		if (ascii > 96 && ascii < 123) intVal = ascii - 61
		if (ascii == 64) intVal = 78

		setBufferValue(rowNum, intVal, hasDot)
	}

	function setBufferValue(rowNum, intVal, hasDot)
	{
		// Sets a _buffer[] entry to the character stored in _digits[]

		if (hasDot)
		{
			_buffer[rowNum] = _digits[intVal] | HT16K33_DP_VALUE
		}
		else
		{
			_buffer[rowNum] = _digits[intVal]
		}
	}

	function updateDisplay()
	{
		// Converts the row-indexed buffer[] values into a single, combined
		// string and writes it to the HT16K33 via I2C

		local dataString = HT16K33_DISPLAY_ADDRESS

		for (local i = 0 ; i < 4 ; i++)
		{
			// Convert 16-bit character data into two 8-bit values for transmission

			local upperByte = _buffer[i]
			upperByte =  upperByte >> 8
			local lowerByte = _buffer[i]
			lowerByte = lowerByte & 0x00FF

			dataString = dataString + lowerByte.tochar() + upperByte.tochar()
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

		// Wipe the display completely first, but retain its current contents

		local sbuffer = [0x0000, 0x0000, 0x0000, 0x0000]

		for (local i = 0 ; i < 4 ; i++)
		{
			sbuffer[i] = _buffer[i]
		}

        	// Clear the display

		clearBuffer(HT16K33_BLANK_CHAR)
		updateDisplay()

		// Power cycle the display

		powerDown()
		powerUp()

        // Write the new brightness value to the HT16K33

		_led.write(_ledAddress, brightness.tochar() + "\x00")

		// Restore the character buffer

        for (local i = 0 ; i < 4 ; i++)
		{
			_buffer[i] = sbuffer[i]
		}

        // And display the original contents

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
