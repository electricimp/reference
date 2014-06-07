// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Class for Sharp Memory LCD

const HEIGHT        = 96; // px
const WIDTH         = 96; // px

// See specific model for typycal values
const SPICLK        = 500; // kHz
const VCOM_FREQ     = 20;  // Hz

// Class to write on the Sharp Memory LCD
// See http://www.sharpmemorylcd.com/resources/LS013B4DN04_Application_Info.pdf
// This display uses write only SPI which the imp emulates using two wire SPI
// in combination with a CS pin.
// The display's VCOM can either be generated in hardware or software.
class SharpMemLCD {
    static WRITE   = 0x01;
    static CLEAR   = 0x04;
    static VCOM_H  = 0x02;
    static VCOM_L  = 0x00;
    
    _lineBytes      = null;
    _cs             = null;
    _spi            = null;
    _vcom           = null;
    _vcomFreq       = null;
    
    // class constructor
    // Input: 
    //      _heigh: hardware pin for the clock line
    //      _width: hardware pin for the data line
    //      _cs: hardware pin for the chip select line
    //      _spi: hardware pin configured to two wire spi
    //      _vcomFreq: frequency with which to update VCOM range
    //                 if 0 it does not update through software
    // Return: (None)
    constructor(height, width, cs, spi, vcomFreq = 0) {
        if ((height % 8) !=0 || (width % 8) != 0) {
            throw "Dimensions must be divisible by 8";
        }
        _lineBytes = width / 8;
        _cs = cs;
        _spi = spi;
        _vcom = VCOM_L;
        _vcomFreq = vcomFreq;
        if (_vcomFreq != 0) {
            _toggleVCOM();
        }
    }
    
    // (Private) Toggles the VCOM bit at vcomFreq frequency
    // Input: (none)
    // Return: (none)
    function _toggleVCOM () {
        if (_vcom == VCOM_L) {
            _vcom = VCOM_H;
        }  else {
            _vcom = VCOM_L;
        }
        _sendCommand(_vcom);
        imp.wakeup(1.0/_vcomFreq, _toggleVCOM.bindenv(this));
    }
    
    // (Private) Outputs a command with optional data for the LCD to read
    // Input: command (byte) and optional data (blob)
    // Return: (none)
    function _sendCommand(command, data = blob(0)) {
        local buffer = blob(2+data.len());
        buffer.writen(command, 'b');
        buffer.writeblob(data);
        buffer.writen(0x00, 'b'); // trailer byte
        _cs.write(1)
        _spi.write(buffer);
        _cs.write(0);
    }
    
    // Writes lines given line numbers and their contents
    // If no line numbers are given it will start from 0 and count up
    // Input: lines (blob) and optional line numbers (blob)
    // Return: (none)
    function writeLine (data, number=null) {
        local buffer = blob(2*data.len()/_lineBytes + data.len());
        local counter = 0x00;
        while (buffer.eos() == null) {
            local line = counter;
            if (number != null) {
                line = number.readn('b');
            }
            buffer.writen(line,'b');
            buffer.writeblob(data.readblob(_lineBytes));
            buffer.writen(0x00,'b'); // trailer byte
            counter += 0x01;
        }
        _sendCommand(WRITE|_vcom, buffer);
    }
    
    // Updates the full screen with data
    // If there is no data given it clears the screen
    // Input: optional screen data (blob)
    // Return: (none)
    function updateScreen (data=null) {
        if (data == null) {
            _sendCommand(CLEAR|_vcom);
        } else {
            writeLine(data);
        }
    }

}

cs  <- hardware.pin2;
spi <- hardware.spi257;
cs.configure(DIGITAL_OUT);
spi.configure(SIMPLEX_TX | LSB_FIRST, SPICLK);
lcd <- SharpMemLCD(HEIGHT, WIDTH, cs, spi, VCOM_FREQ);
lcd.updateScreen(); // Clear display

agent.on("displayData", function(data) {
    lcd.updateScreen(data);
});
agent.send("getImage", null);