// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Class for SHT10 Temp/Humidity Sensor

// Class to read the SHT10 temperature/humidity sensor
// See http://www.adafruit.com/datasheets/Sensirion_Humidity_SHT1x_Datasheet_V5.pdf
// These sensors us a proprietary clock and data, two wire protocol. The imp
// emulates this protocol via bit-banging. 
// Configured or unconfigured pins for clk and dta. Please note that these pins
// will be reconfigured inside the class.
class SHT10 {
    // cmds
    static SHT10_ADDR       = 0x0; //0b000, 3 bits
    static SHT10_CMD_TEMP   = 0x03; //0b00011, 5 bits
    static SHT10_CMD_RH     = 0x05; //0b00101, 5 bits
    static SHT10_CMD_RESTATUS = 0x07; //0b00111
    static SHT10_CMD_WRSTATUS = 0x06; //0b00110
    static SHT10_CMD_SOFTRESET = 0x1E; //0b1110
    
    static TIMEOUT  = 0.5; // seconds
    static D1            = -39.7;
    static D2            =  0.01;
    static C1            = -2.0468;
    static C2            =  0.0367;
    static C3            = -0.0000015955;
    static T1            =  0.01;
    static T2            =  0.00008;
    static AMBIENT       =  25.0;
    
    dta = null;
    clk = null;
    
    // class constructor
    // Input: 
    //      _clk: hardware pin for the clock line
    //      _dta: hardware pin for the data line
    // Return: (None)
    constructor(_clk, _dta) {
        clk = _clk;
        dta = _dta;
        
        init();
    }
    
    function init() {
        clk.configure(DIGITAL_OUT);
        dta.configure(DIGITAL_OUT);
        softReset();
    }
    
    // Clock Pulse
    // Input: number of pulses, defaults to 1 (int)
    // Return: (none)
    function _pulseClk(numPulses = 1) {
        for (local i = 0; i < numPulses; i++) {
            clk.write(1);
            clk.write(0);
        }
    }
    
    // Send a Command Byte (5 command bits and 3 address bits)
    // max 32 per transaction (bit mask is an integer)
    function _sendCmd(cmd) {
        _sendStart();
        cmd = ((SHT10_ADDR & 0x3) << 5) | (cmd & 0x1F);
        clk.write(0);
        for (local i = 7; i >= 0; i--) {
            dta.write((cmd & (0x01 << i)) ? 1 : 0);
            clk.write(1);
            clk.write(0);
        }
    }
    
    // Send Transmission Start Cmd
    function _sendStart() {
        clk.write(0);
        dta.write(1);
        clk.write(1);
        dta.write(0);
        clk.write(0);
        clk.write(1);
        dta.write(1);
        clk.write(0);
    }
    
    // Read a 16-bit word from the sensor
    // Input: None
    // Return: integer
    // used to retrieve sensor readings (temp, rh)
    function _read16() {
        local result = 0;
        // read high byte, msb first
        for (local i = 1; i <= 8; i++) {
            result += (dta.read() << (16 - i));
            _pulseClk();
        }
        // clock out one low bit to ack
        dta.configure(DIGITAL_OUT);
        dta.write(0);
        _pulseClk();
        dta.configure(DIGITAL_IN_PULLUP);
        // read low byte, msb first
        for (local i = 1; i <= 8; i++) {
            result += (dta.read() << (8 - i));
            _pulseClk();
        }
        // clock out one high bit to ack
        dta.configure(DIGITAL_OUT);
        dta.write(1);
        _pulseClk();
        return result;
    }
    
    // issue a soft reset
    // clears the status register
    // wait 11ms before sending other commands
    function softReset() {
        _sendCmd(SHT10_CMD_SOFTRESET);
    }
    
    // read the temperature
    // Input: callback function, takes 1 argument (table)
    // Return: None
    // Callback will be called with table containing at least the "temp" key
    // If an error occurs, the "err" key will be present in the table
    function readTemp(cb) {
        _sendCmd(SHT10_CMD_TEMP);
        
        // schedule a callback to catch a timeout
        local response_timer = imp.wakeup(TIMEOUT, function() {
            // cancel state change callback
            dta.configure(DIGITAL_OUT);
            cb({"err": "temperature reading timed out", "temp": 0});
        }.bindenv(this));
    
        // wait for SHT10 to pull DATA line low
        dta.configure(DIGITAL_IN_PULLUP, function() {
            if (dta.read()) return;
            imp.cancelwakeup(response_timer);
            cb({"temp": D1 + (D2 * _read16())});
        }.bindenv(this));
        _pulseClk();
    }
    
    // read the temperature and relative humidity
    // Input: callback function, temperature for compensation (optional)
    // Return: None
    // Callback will be called with one argument (table)
    // Table will contain at least the "rh" key, with relative humidity as a percentage (float)
    // If an error occurs, table will contain "err" key
    function readTempRh(cb, temp = null) {
        // user skipped putting in the temp, so we'll go get it
        if (temp == null) {
            // go read the temp
            readTemp(function(tempResult) {
                if ("err" in tempResult) {
                    // if the temp result failed, call the readTempRh callback with an error
                    cb({"err": tempResult.err, "temp": tempResult.temp, "rh": 0.0}); 
                    return;
                }
                // if readTemp manages to get the temp, it calls us back with it 
                readTempRh(cb, tempResult.temp);
                // we've gotten through readTemp and back to readTempRh with the temp now, so end this path
                return;
            });
            // we've scheduled readTemp, which will call us back when done, so end this path
            return;
        }
        
        // we'll wind up here if readTemp calls us back or if the user calls with temp explicitly
        _sendCmd(SHT10_CMD_RH);        
        
        local response_timer = imp.wakeup(TIMEOUT, function() {
            // cancel state change callback
            dta.configure(DIGITAL_OUT);
            cb({"err": "humidity reading timed out", "temp": temp, "rh": 0});
        }.bindenv(this));
        dta.configure(DIGITAL_IN_PULLUP, function() {
            if (dta.read()) return;
            imp.cancelwakeup(response_timer);
            local result = _read16();
            local unComp = C1 + (C2 * result) + (C3 * result * result);
            local rhComp = (temp - AMBIENT) * (T1 + (T2 * result)) + unComp;
            cb({"temp": temp, "rh": rhComp});
        }.bindenv(this));
        _pulseClk();
    }
}

// clk <- hardware.pin5;
// dta <- hardware.pin7;
// sht10 <- SHT10(clk, dta);

// sht10.readTemp( function(result) {
//     if ("err" in result) {
//         server.error(result.err);
//         return;
//     }
//     server.log(format("Temperature: %0.1f C", result.temp));
// });
// sht10.readTempRh( function(result) {
//     if ("err" in result) {
//         server.error(result.err);
//         return;
//     }
//     server.log(format("Temperature: %0.1f C & Humidity: %0.1f", result.temp, result.rh) + "%");
// });