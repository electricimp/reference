/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Ambient Light Sensor Firmware
// A great example of how to communicate with a peripheral via I2C

server.log("Imp Light Sensor Started");

// I2C Interface to TSL2561FN Light Sensor
// Pin 8 is SCLK
// Pin 9 is SDA
hardware.configure(I2C_89);
// set the I2C clock speed. We can do 10 kHz, 50 kHz, 100 kHz, or 400 kHz
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
// the slave address for this device is set in hardware. Saving it here is helpful.
local alsAddr = 0x52;

// function to tell the sensor to start taking a reading
// we send this command, then wait a bit, then collect the reading
function startAls() {
    // i2c.write takes two arguments: address and string. 
    // here, we send 16 bits of data: the first byte is a register, the second is a command
    // your needs will vary with the device you are trying to communicate with
    hardware.i2c89.write(alsAddr, "\x80\x03");
    // 400 ms required to integrate and complete conversion

    // schedule the imp to go read the sensor in half a second, after it's done taking a reading
    imp.wakeup(0.5, readAls);
}

// function to collect the reading from the sensor. 
// this function is long mostly because the sensor wants us to do funny math with the values
function readAls() {
    // i2c.read takes three arguments: address, subaddress, and number of bytes to read
    // subaddress is often used for a command or a register to read from
    // if you don't need a subaddress, use "" for none
    local reg0 = hardware.i2c89.read(alsAddr, "\xAC", 2);
    local reg1 = hardware.i2c89.read(alsAddr, "\xAE", 2);

    local lux = 0;
    
    // make sure we got legitimate data back from the sensor
    if (reg0 == null || reg1 == null) {
        server.error("Lux conversion failed");
        return;
    }

    // now that we have the sensor data, we can do the funny math provided in the datasheet
    local channel0 = ((reg0[1] & 0xFF) << 8) | (reg0[0] & 0xFF);
    local channel1 = ((reg1[1] & 0xFF) << 8) | (reg1[0] & 0xFF);
    local ratio = channel1/channel0.tofloat();
    if (ratio <= 0.52) {
        lux = (0.0315 * channel0 - 0.0593 * channel0 * math.pow(ratio,1.4));
    } else if (0.52 < ratio <= 0.65) {
        lux = (0.0229 * channel0 - 0.0291 * channel1);
    } else if (0.65 < ratio <= 0.8) {
        lux = (0.0157 * channel0 - 0.0180 * channel1);
    } else if (0.80 < ratio <= 1.30) {
        lux = (0.00338 * channel0 - 0.00260 * channel1);
    } else {
        lux = 0;
    }

    // done with the math! Now we can display the value in the planner
    server.show(format("%.2f lux", lux));

    // schedule the imp to take another reading in 5 minutes
    imp.wakeup(300, startAls);
}

imp.configure("Imp Light Sensor", [], []);
startAls();

//EOF