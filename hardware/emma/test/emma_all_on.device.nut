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

// Emma Test Firmware - turn all segments of all digits on
// Pin 1 = load
// Pin 2 = oe_l
// Pin 5 = data
// Pin 7 = srclk
// Pin 8 = scl
// Pin 9 = sda

server.log("Emma Started");

// Serial Interface to AS1110 Driver ICs
hardware.configure(SPI_257);
hardware.spi.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 400);
server.log("SPI configured on 2/5/7");

// I2C Bus to TSL2561 Digital Ambient Light Sensor
hardware.configure(I2C_89);
hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
server.log("I2C configured on 8/9");

// Configure oe_l as GPIO
hardware.pin2.configure(DIGITAL_OUT);
// pin 2 is pulled up inside the AS1110 driver, nominally disable
hardware.pin2.write(1);
// Configure load as GPIO
hardware.pin1.configure(DIGITAL_OUT);
hardware.pin1.write(1);
server.log("GPIOs configured");


local function outputEnable() {
    hardware.pin2.write(0);
    imp.sleep(0.001);
    server.log("Output enabled");
}

local function outputDisable() {
    hardware.pin2.write(1);
    server.log("Output disabled");
}

local function prepareToLoad() {
    // now set load pin high
    imp.sleep(0.001);
    hardware.pin1.write(0);
    imp.sleep(0.001);
}

local function doneWithLoad() {
    imp.sleep(0.001);
    hardware.pin1.write(1);
    outputEnable();
}

function setAllOn() {
    prepareToLoad();
    hardware.spi257.write("\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff")
    //IM EMMA 
    //hardware.spi257.write("\x00\x00\x2C\x34\x53\x82\x00\x00\xA5\x27\x53\x82\x53\x82\xE5\x83\x00\x00");
    //HELLO
    //hardware.spi257.write("\x00\x00\xC1\x83\xA5\x27\x01\x26\x01\x26\x65\xA6\x00\x00\x00\x00\x00\x00");
    doneWithLoad();
}

function setAllOff() {
    prepareToLoad();
    hardware.spi257.write("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
    doneWithLoad();
}

// Time mm:ss
imp.configure("Emma All On", [], []);

setAllOn();

// Emergency use only - recover from erroring imp not in planner case
//imp.configure("Help me", [], []);