class MAX72XX {
    displays = [
        "\x01",
        "\x02",
        "\x03",
        "\x04",
        "\x05",
        "\x06",
        "\x07",
        "\x08"
    ];

    digits = [
        "\x7E", //0
        "\x30", //1
        "\x6D", //2
        "\x79", //3
        "\x33", //4
        "\x5B", //5
        "\x5F", //6
        "\x70", //7
        "\x7F", //8
        "\x73", //9
        "\x00"  //ALLOFF
    ];

    OFF = 10;
    
    _spi = null;
    _latch = null;
    
    constructor(spi, latchPin) {
        this._spi = spi;
        this._spi.configure(SIMPLEX_TX | MSB_FIRST, 400)
        
        this._latch = latchPin;
        this._latch.configure(DIGITAL_OUT);
        this._latch.write(0);
        
        setup();
    }
    
    function setup() {
        // leave shutdown mode
        _spi.write("\x0C\x01");
        latch();
        
        // scanner limit
        _spi.write("\x0B\x07")
        latch();
        
        // no decode
        _spi.write("\x09\x00");
        latch();
        
        // no test mode
        _spi.write("\x0F\x00");
        latch();
        
        // set brightness
        _spi.write("\x0A\x0F")
        latch();
        
        // turn all digits off
        foreach(d in displays) {
            _spi.write(d+digits[OFF]);
            latch();
        }
    }
    
    function latch() {
        _latch.write(1);
        imp.sleep(0.01)
        _latch.write(0);
    }
    
    function writeDigit(d,v) {
        _spi.write(displays[d] + digits[v]);
        latch();
    }
    
    function writeNum(num, firstDigit = 0, lastDigit = 7) {
        local numString = num.tostring();
        foreach(k,v in numString) {
            local digit = numString.len() - k - 1 + firstDigit;
            if (digit <= lastDigit) writeDigit(numString.len()-k-1+firstDigit, (v-48));
        }
        
        for(local i = lastDigit; i > numString.len() - 1 + lastDigit; i--) {
            writeDigit(i, OFF);
        }
        
    }
    
}

display <- MAX72XX(hardware.spi257, hardware.pin1);
display.writeNum(12345678);

