class CHARLCD
{
	// A Squirrel class to drive an 8 x 1 to 20 x 4 character LCD driven by a Hitachi HD44780 controller
	// via an MCP23008 interface chip on an Adafruit I2C backpack [http://www.adafruit.com/product/292]
	// Communicates with any imp I2C bus

	// Written by Tony Smith (@smittytone) October 2014
	// Version 1.0
	// Copyright (c) 2014, Electric Imp, Inc.

	// MCP2008 Constants
	
	MCP23008_IODIR = "\x00"
	MCP23008_GPIO = "\x09"

	// HD44780 Commands

	LCD_CLEARDISPLAY = 0x01
	LCD_RETURNHOME = 0x02
	LCD_ENTRYMODESET = 0x04
	LCD_DISPLAYCONTROL = 0x08
	LCD_CURSORSHIFT = 0x10
	LCD_FUNCTIONSET = 0x20
	LCD_SETCGRAMADDR = 0x40
	LCD_SETDDRAMADDR = 0x80

	// Flags for display entry mode

	LCD_ENTRYRIGHT = 0x00
	LCD_ENTRYLEFT = 0x02
	LCD_ENTRYSHIFTINCREMENT = 0x01
	LCD_ENTRYSHIFTDECREMENT = 0x00

	// Flags for display on/off control

	LCD_DISPLAYON = 0x04
	LCD_DISPLAYOFF = 0x00
	LCD_CURSORON = 0x02
	LCD_CURSOROFF = 0x00
	LCD_BLINKON = 0x01
	LCD_BLINKOFF = 0x00
	LCD_BACKLIGHT = 0x80

	// Flags for display/cursor shift

	LCD_DISPLAYMOVE = 0x08
	LCD_CURSORMOVE = 0x00
	LCD_MOVERIGHT = 0x04
	LCD_MOVELEFT = 0x00

	// Flags for display mode

	LCD_8BITMODE = 0x10
	LCD_4BITMODE = 0x00
	LCD_2LINE = 0x08
	LCD_1LINE = 0x00
	LCD_5x10DOTS = 0x04
	LCD_5x8DOTS = 0x00

	HIGH = 1
	LOW = 0

	_lcdWidth = 0
	_lcdHeight = 0
	_currentLine = 0
	_currentCol = 0
	_displayControl = 0

	_device = null
	_devAddress = 0

	constructor(impI2Cbus, mcp2008address = 0x20)
	{
		// Parameters:
		// 1. imp I2C bus to which display backpack is connected
		// 2. Display backpack I2C address from datasheet

		_device = impI2Cbus
		_devAddress = mcp2008address << 1
		_device.configure(CLOCK_SPEED_100_KHZ)
	}

	function init(chars = 16, rows = 2)
	{
		// Initializes the display
		//
		// Parameters:
		// 1. Integer value for the number of characters per line that the display supports (Default: 16)
		// 2. Integer value for the number of lines that the display supports (Default: 2)

		if (rows < 1) rows = 1
		if (chars < 1) chars = 1

		_lcdWidth = chars
		_lcdHeight = rows
		
		// displayFunction combines basic LCD parameters: mode (4- or 8-bit); one or multiple
		// HD44780s; and character pixel matrix size (5x8 or 5x10)
		
		local displayFunction = LCD_4BITMODE | LCD_1LINE | LCD_5x8DOTS
		if (_lcdHeight > 1) displayFunction = displayFunction | LCD_2LINE

		delay(5)
		_device.write(_devAddress, MCP23008_IODIR + "\xFF\x00\x00\x00\x00\x00\x00\x00\x00\x00")
		_device.write(_devAddress, MCP23008_IODIR + "\x00")

		// Must write the next two lines two further times each

		_device.write(_devAddress, MCP23008_GPIO + "\x9C")
		_device.write(_devAddress, MCP23008_GPIO + "\x98")
		_device.write(_devAddress, MCP23008_GPIO + "\x9C")
		_device.write(_devAddress, MCP23008_GPIO + "\x98")
		_device.write(_devAddress, MCP23008_GPIO + "\x9C")
		_device.write(_devAddress, MCP23008_GPIO + "\x98")
		_device.write(_devAddress, MCP23008_GPIO + "\x94")
		_device.write(_devAddress, MCP23008_GPIO + "\x90")

		delay(5)
		sendCommand(LCD_FUNCTIONSET | displayFunction)
		delay(5)
		sendCommand(LCD_FUNCTIONSET | displayFunction)
		delay(5)

		displayOn()
		clearScreen()

		// displayFunction combines basic LCD presentation parameters
		
		local displayMode = LCD_ENTRYLEFT | LCD_ENTRYSHIFTDECREMENT
		sendCommand(LCD_ENTRYMODESET | displayMode)

		setBacklight(HIGH)
	}

	function clearScreen()
	{
		// Clear the display

		sendCommand(LCD_CLEARDISPLAY)
		delay(2)
	}

	function displayOn()
	{
		// Power up and activate the display

		_displayControl = _displayControl | LCD_DISPLAYON
		sendCommand(LCD_DISPLAYCONTROL | _displayControl)
	}

	function displayOff()
	{
		// Power down the display

		_displayControl = _displayControl | LCD_DISPLAYOFF
		sendCommand(LCD_DISPLAYCONTROL | _displayControl)
	}

	function setBacklight(setting)
	{
		// Set the backlight
		//
		// Parameters:
		// 1. Integer or Boolean value indicating whether the backlight should be on or off
		//
		// Note: Backlight intensity is not supported by HD44780

		if (setting == HIGH || setting = true)
		{
			_displayControl = _displayControl | 0x80
			_device.write(_devAddress, MCP23008_GPIO + "\x80")
		}
		else
		{
			_displayControl = _displayControl & 0x7F
			_device.write(_devAddress, MCP23008_GPIO + "\x00")
		}
	}

	function setCursor(col, row)
	{
		// Set the print cursor at the selected co-ordinates
		//
		// Parameters:
		// 1. Integer for the column number
		// 2. Integer for the row number
		//
		// Note: Column and row values begin at zero

		local rowOffsets = [0x00, 0x40, 0x14, 0x54]

		if (row < 0) row = 0
		if (row >= _lcdHeight) row = _lcdHeight - 1
		if (col < 0) col = 0
		if (col >= _lcdWidth) col = _lcdWidth - 1

		sendCommand(LCD_SETDDRAMADDR | (col + rowOffsets[row]))

		_currentLine = col
		_currentCol = col
	}

	function print(stringToPrint = "")
	{
		// Print a string at the current cursor location
		//
		// Parameters:
		// 1. String value to be printed

		if (stringToPrint == "" || stringToPrint == null) return
		if (typeof stringToPrint != "string") return

		for (local i = 0 ; i < stringToPrint.len() ; i++)
		{
			writeData(stringToPrint[i])
		}
	}

	function printChar(ascii = 65)
	{
		// Print a string at the current cursor location
		//
		// Parameters:
		// 1. Integer value for the Ascii code of the character to be printed

		if (ascii < 0) ascii = 32
		if (ascii > 7 && ascii < 32) ascii = 32
		if (ascii > 127) ascii = 32

		writeData(ascii)
	}

	function centerText(stringToPrint)
	{
		// Returns a string formatted to be centred on the display, ie. it pads with spaces
		// so the string can be printed at column 0
		//
		// Parameters:
		// 1. String value to be printed

		if (stringToPrint == "" || stringToPrint == null) return
		if (typeof stringToPrint != "string") return
		local inset = stringToPrint.len()

		if (inset > _lcdWidth)
		{
			inset = inset - _lcdWidth
			inset = inset / 2
			stringToPrint = stringToPrint.slice(inset, inset + _lcdWidth)
		}
		else if (inset < _lcdWidth)
		{
			inset = _lcdWidth - inset
			inset = inset / 2
			local spaces = "                    "
			stringToPrint = spaces.slice(0, inset) + stringToPrint + spaces.slice(0, inset)
		}

		return stringToPrint
	}

	function createCustomChar(charMatrix = [], asciiCode = 0)
	{
		// Set one of the HD44780's eight custom 5 x 8 user-definable characters

		if (asciiCode < 0 || asciiCode > 7) return
		if (charMatrix.len() == 0 || charMatrix == null) return

		sendCommand(LCD_SETCGRAMADDR | (asciiCode << 3))

		for (local i = 0 ; i < 8 ; i++)
		{
			writeData(charMatrix[i])
		}
	}

	function sendCommand(command)
	{
		// Send a command to the HD77480

		send(command, LOW)
	}

	function writeData(dataByte)
	{
		// Send data to the HD77480

		send(dataByte, HIGH)
	}

	function send(value, rsPinValue)
	{
		// Generic send function to pass both a command or data byte (value) to the HD44780
		// We use the controller's 4-bit mode to send the data in two batches, each of which
		// also contains the HD44780 pin settings we need. Each byte sent is packaged as follows:
		//
		// Register Select pin = bit 1
		// Enable pin = bit 2
		// Data pin 4 = bit 3
		// Data pin 5 = bit 4
		// Data pin 6 = bit 5
		// Data pin 7 = bit 6
		// Backlight = bit 7
		//
		// The format is set by the backpack, which decodes the data and puts it onto the appropriate
		// HD44780 lines

		// Get the passed value's upper four bits and shift down to bits 6-3 (data pins)
		// of the byte we will actually send

		local buffer = (value & 0xF0) >> 1

		if (rsPinValue == HIGH)
		{
			// Set the transmission byte's E + RS bits

			buffer = buffer | 0x06
		}
		else
		{
			// Set the transmission byte's E bit

			buffer = buffer | 0x04
		}

		// Set backlight bit if the backlight has been enabled in _displayControl

		if (_displayControl & LCD_BACKLIGHT)
		{
		    buffer = buffer | 0x80
		}
		else
		{
		    buffer = buffer & 0x7F
		}

		// Write the byte ot the backpack via I2C

		_device.write(_devAddress, MCP23008_GPIO + buffer.tochar())

		// Clear the E bit and send the byte again

		buffer = buffer & 0xFB
		_device.write(_devAddress, MCP23008_GPIO + buffer.tochar())

		// Get the passed value's lower four bits and shift down to bits 6-3

		buffer = (value & 0x0F) << 3

		if (rsPinValue == HIGH)
		{
			// Set the transmission byte's E + RS bits

			buffer = buffer | 0x06
		}
		else
		{
			// Set the transmission byte's E bit

			buffer = buffer | 0x04
		}

		// Set backlight bit if the backlight has been enabled in _displayControl

		if (_displayControl & LCD_BACKLIGHT)
		{
		    buffer = buffer | 0x80
		}
		else
		{
		    buffer = buffer & 0x7F
		}

		// Write the byte ot the backpack via I2C

		_device.write(_devAddress, MCP23008_GPIO + buffer.tochar())

		// clear the E bit and send again

		buffer = buffer & 0xFB
		_device.write(_devAddress, MCP23008_GPIO + buffer.tochar())
	}

	function delay(value)
	{
		// Blocking delay for ‘value’ milliseconds

		local a = hardware.millis() + value;

		while (hardware.millis() < a) {}
	}
}
