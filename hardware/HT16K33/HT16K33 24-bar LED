class HT16K33BAR
{
	// Squirrel class for barchart-style LED displays driven by the HT16K33 controller
	// For example: http://www.adafruit.com/products/1721
	// Communicates with any imp I2C bus
 
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

	LED_OFF = 0
	LED_RED = 1
	LED_YELLOW = 2
	LED_GREEN = 3

	// Class private properties. Those defined in the Constructor should be null

	_buffer = null
	_led = null
	_ledAddress = 0
	_discreteValues = false
	_chipAtTop = true

	constructor(impI2Cbus, ht16k33Address = 0x70)
	{
		// Parameters:
		// 1. The imp I2C bus connected to the HT16K33
		// 2. The HT16K33's I2C address

		_led = impI2Cbus
		_ledAddress = ht16k33Address << 1

		// _buffer stores the colour values for each row of the bar

		_buffer = [0x0000, 0x0000, 0x0000]
    }

	function init(brightness = 15, usesDiscreteValues = false, theChipAtTop = true)
	{
		// Initialize the barchart
		// Parameters:
		// 1. Integer value specifying the initial display brightness (0 - 15)
		// 2. Boolean value specifying whether the display fills the space below the set bar
		// 3. Boolean value specifying whether the board is oriented with the HT16K33 chip at
		//    the top or the bottom
		
		_discreteValues = usesDiscreteValues
		_chipAtTop = theChipAtTop

		// Configure the I2C bus

		_led.configure(CLOCK_SPEED_100_KHZ)

		// Set the brightness (which of necessity wipes and power cyles the dispay)

		setBrightness(brightness)
	}

	function writeBar()
	{
		// Writes the contents of _buffer and writes it to the LED matrix
		// _buffer values are 16-bit, so transfer as two 8-bit values, LSB first

		local dataString = HT16K33_DISPLAY_ADDRESS

		for (local i = 0 ; i < 3 ; i++)
		{
			dataString = dataString + (_buffer[i] & 0xFF).tochar() + (_buffer[i] >> 8).tochar()
		}

		_led.write(_ledAddress, dataString)
	}

	function clearBar()
	{
		// Clears the _buffer, which is then written to the LED matrix

		_buffer = [0x0000, 0x0000, 0x0000]
		writeBar()
	}

	function setBar(barNumber, ledColor)
	{
		if (barNumber < 0 || barNumber > 23) return
		if (ledColor < LED_OFF || ledColor > LED_GREEN) return

		if (_chipAtTop == false)
		{
			barNumber = 23 - barNumber

			if (_discreteValues == false)
			{
				for (local i = 23 ; i > barNumber ; i--)
				{
					fixBar(i, ledColor)
				}
			}
			else
			{
				fixBar(barNumber + 1, ledColor)
			}
		}
		else
		{
			if (_discreteValues == false)
			{
				for (local i = 0 ; i < barNumber ; i++)
				{
					fixBar(i, ledColor)
				}
			}
			else
			{
					fixBar(barNumber - 1, ledColor)
			}
		}

		writeBar()
	}

	function fixBar(barNumber, ledColor)
	{
		local a = 999
		local b = 999

		if (barNumber < 12)
    	{
    		a = barNumber / 4
    	}
		else
		{
			a = (barNumber - 12) / 4
		}

		b = barNumber % 4
		if (barNumber >= 12) b = b + 4

  		if (ledColor == LED_RED)
  		{
    		// Turn on red LED

    		_buffer[a] = _buffer[a] | (1 << b)

    		// Turn off green LED

    		_buffer[a] = _buffer[a] & ~(1 << (b + 8))
  		}
  		else if (ledColor == LED_YELLOW)
  		{
    		// Turn on red and green LED

    		_buffer[a] = _buffer[a] | (1 << b) | (1 << (b + 8))
  		}
  		else if (ledColor == LED_OFF)
  		{
    		// Turn off red and green LED

    		_buffer[a] = _buffer[a] & ~(1 << b) & ~(1 << (b + 8))
		}
		else if (ledColor == LED_GREEN)
		{
    		// Turn on green LED

			_buffer[a] = _buffer[a] | (1 << (b + 8))

			// Turn off red LED

			_buffer[a] = _buffer[a] & ~(1 << b)
		}
	}

	function setBrightness(brightness = 15)
	{
		// Called when the app changes the brightness
		// Default: 15

		if (brightness > 15) brightness = 15
		if (brightness < 0) brightness = 0

		brightness = brightness + 224

		// Wipe the display completely first, so preserve what's in the _buffer

		local sbuffer = [0x0000, 0x0000, 0x0000]

		for (local i = 0 ; i < 3 ; i++)
		{
		    sbuffer[i] = _buffer[i]
		}

		// Clear the LED matrix

		clearBar()

		// Power cycle the LED matrix

		powerDown()
		powerUp()

        // Write the new brightness value to the HT16K33

		_led.write(_ledAddress, brightness.tochar() + "\x00")

		// Restore what's was in the _buffer...

        for (local i = 0 ; i < 3 ; i++)
		{
		    _buffer[i] = sbuffer[i]
		}

		// ... and write it back to the LED matrix

        writeBar()
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
