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
// To use:
//  - tie data line to pull-up resistor (10K)
class SHT10 {
    
    static WAIT_LIMIT    =  0.35;
    static WAIT_INTERVAL =  0.01;
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
        this.clk = _clk;
        this.dta = _dta;
        
        this.clk.configure(DIGITAL_OUT);
        this.dta.configure(DIGITAL_OUT);
    }
    
    // Clock Pulse
    // Input: number of pulses, defaults to 1 (int)
    // Return: (none)
    function clkPulse(pulseNum = 1) {
        for (local i = 0; i < pulseNum; i++) {
            clk.write(1);
            clk.write(0);
        }
    }
    
    // Transmission Start Bit-Banging
    // Input: (none)
    // Return: (none)
    function transStart() {
        clk.write(0);
        dta.write(1);
        clk.write(1);
        dta.write(0);
        clk.write(0);
        clk.write(1);
        dta.write(1);
        clk.write(0);
    }
    
    // Sensor Address Bit-Banging
    // Input: (none)
    // Return: (none)
    function address() {
        dta.write(0);
        clkPulse(3);
    }
    
    // Temperature Command Bit-Banging
    // Input: (none)
    // Return: (none)
    function tempCommand() {
        dta.write(0);
        clkPulse(3);
        dta.write(1);
        clkPulse(2);
    }
    
    // Humidity Command Bit-Banging
    // Input: (none)
    // Return: (none)
    function humidCommand() {
        dta.write(0);
        clkPulse(2);
        dta.write(1);
        clkPulse();
        dta.write(0);
        clkPulse();
        dta.write(1);
        clkPulse();
    }
    
    // Wait for the sensor to finish the measurement
    // Throws error if measurement takes too long to return
    // Input: (none)
    // Return: (none)
    function waitForMeasure() {
        dta.configure(DIGITAL_IN);
        clkPulse();
        local counter = 0;
        while (dta.read()) {
            if (counter > WAIT_LIMIT) {
                throw "Sensor measurement unsuccessful";
            }
            imp.sleep(WAIT_INTERVAL);
            counter += WAIT_INTERVAL;
        }
    }
    
    // Read the result of the measurement
    // Input: (none)
    // Return: result of reading the sensor's output (int)
    function readResult() {
        local result = 0;
        for (local i = 1; i <= 8; i++) {
            result += (dta.read() << (16 - i));
            clkPulse();
        }
        dta.configure(DIGITAL_OUT);
        dta.write(0);
        clkPulse();
        dta.configure(DIGITAL_IN);
        for (local i = 1; i <= 8; i++) {
            result += (dta.read() << (8 - i));
            clkPulse();
        }
        dta.configure(DIGITAL_OUT);
        dta.write(1);
        clkPulse();
        return result;
    }
    
    // read the temperature
    // Input: (none)
    // Return: temperature in celsius (float)
    function readTemp() {
        transStart();
        address();
        tempCommand();
        waitForMeasure();
        local result = readResult();
        local output = D1 + (D2 * result);
        return output;

    }
    
    // read the humidity
    // Input: temperature in celsius (float) to compensate (optional)
    // Return: relative humidity (float)
    function readHumid(temp = null) {
        if (temp == null) {
            temp = AMBIENT;
        }
        transStart();
        address();
        humidCommand();
        waitForMeasure();
        local result = readResult();
        local unComp = C1 + (C2 * result) + (C3 * result * result);
        local output = (temp - AMBIENT) * (T1 + (T2 * result)) + unComp;
        return output;
    }
}

clk <- hardware.pin5;
dta <- hardware.pin7;
sht10 <- SHT10(clk, dta);

try {
    temperature <- sht10.readTemp();
    humidity <- sht10.readHumid(temperature);
    server.log(format("Temperature: %0.1f C & Humidity: %0.1f", temperature, humidity) + "%");
}
catch(e) {
    server.log(e);
}