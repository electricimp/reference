// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Class for Sharp Memory LCD

const HEIGHT = 96;
const WIDTH  = 96;

// See specific model for typycal values
const SPICLK = 500;
const VCOMFREQ = 20;

// Class to write on the Sharp Memory LCD
// See http://www.sharpmemorylcd.com/resources/LS013B4DN04_Application_Info.pdf
// This display uses write only SPI which the imp emulates using two wire SPI
// in combination with a CS pin.
// The display's VCOM can either be generated in hardware or software.
class SharpMemLCD {
    static WRITE = 0x01;
    static CLEAR = 0x04;
    static VCOM  = 0x02;
    static ZERO  = 0x00;
    
    height       = null;
    width        = null;
    lineBytes    = null;
    screenBytes  = null;
    cs           = null;
    spi          = null;
    vcom         = null;
    vcomFreq     = null;
    
    // class constructor
    // Input: 
    //      _heigh: hardware pin for the clock line
    //      _width: hardware pin for the data line
    //      _cs: hardware pin for the chip select line
    //      _spi: hardware pin configured to two wire spi
    //      _vcomFreq: frequency with which to update VCOM range
    //                 if 0 it does not update through software
    // Return: (None)
    constructor(_height, _width, _cs, _spi, _vcomFreq = 0) {
        this.height = _height;
        this.width  = _width;
        if ((height % 8) !=0 || (width % 8) != 0) {
            throw "Dimensions must be divisible by 8";
        }
        this.lineBytes = _width / 8;
        this.screenBytes = lineBytes * height;
        this.cs = _cs;
        this.spi = _spi;
        this.vcom = ZERO;
        this.vcomFreq = _vcomFreq;
        if (_vcomFreq != 0) {
            _toggleVCOM();
        }
    }
    
    // (Private) Toggles the VCOM bit at vcomFreq frequency
    // Input: (none)
    // Return: (none)
    function _toggleVCOM () {
        if (vcom == ZERO) {
            vcom = VCOM;
        }  else {
            vcom = ZERO;
        }
        _sendCommand(vcom);
        imp.wakeup(1.0/vcomFreq, _toggleVCOM.bindenv(this));
    }
    
    // (Private) Outputs a command with optional data for the LCD to read
    // Input: command (byte) and optional data (blob)
    // Return: (none)
    function _sendCommand(command, data = blob(0)) {
        local buffer = blob(2+data.len());
        buffer.writen(command, 'b');
        buffer.writeblob(data);
        buffer.writen(ZERO, 'b');
        cs.write(1)
        spi.write(buffer);
        cs.write(0);
    }
    
    // Writes lines given line numbers and their contents
    // If no line numbers are given it will start from 0 and count up
    // Input: lines (blob) and optional line numbers (blob)
    // Return: (none)
    function writeLine (data, number=null) {
        local buffer = blob(2*data.len()/lineBytes + data.len());
        local counter = 0x00;
        while (buffer.eos() == null) {
            local line = counter;
            if (number != null) {
                line = number.readn('b');
            }
            buffer.writen(line,'b');
            buffer.writeblob(data.readblob(lineBytes));
            buffer.writen(ZERO,'b');
            counter += 0x01;
        }
        _sendCommand(WRITE|vcom, buffer);
    }
    
    // Updates the full screen with data
    // If there is no data given it clears the screen
    // Input: optional screen data (blob)
    // Return: (none)
    function updateScreen (data=null) {
        if (data == null) {
            _sendCommand(CLEAR|vcom);
        } else {
            writeLine(data);
        }
    }

}

cs  <- hardware.pin2;
spi <- hardware.spi257;
cs.configure(DIGITAL_OUT);
spi.configure(SIMPLEX_TX | LSB_FIRST, SPICLK);
lcd <- SharpMemLCD(HEIGHT, WIDTH, cs, spi, VCOMFREQ);
lcd.updateScreen();

agent.on("displayData", function(data) {
    lcd.updateScreen(data);
});
agent.send("getImage", null);