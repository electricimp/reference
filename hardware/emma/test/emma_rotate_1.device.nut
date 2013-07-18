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

// Emma Test Firmware - clock a 1 through all digits, rotating ten times per second
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

// Configure oe_l and load as GPIO
hardware.pin2.configure(DIGITAL_OUT);
// pin 2 is pulled up inside the AS1110 driver, nominally disable
hardware.pin2.write(0);
hardware.pin1.configure(DIGITAL_OUT);
// pin 2 is pulled up inside the AS1110 driver, nominally disable
hardware.pin1.write(0);

local function load() {
    imp.sleep(0.001);
    hardware.pin1.write(1);
    imp.sleep(0.001);
    hardware.pin1.write(0);
}

local lightByte = 0;
local lightBit = 0;

function rotate() {
    local blobLen = 17;
    local outputVal = blob(blobLen);
    for (local i = 0; i < blobLen; i++) {
        // blobs must be written by byte, so we'll need to loop through each byte
        if (i == lightByte) {
            outputVal.writen((0x00 | (0x01 << lightBit)), 'b');
        } else {
            outputVal.writen(0x00, 'b');
        }
    }
    hardware.spi257.write(outputVal);
    load();

    // increment / rollover bit counter
    lightBit++;
    if (lightBit == 8) {
        lightBit = 0;
        lightByte++;
    }
    // rollover byte counter if necessary
    if (lightByte == blobLen) {
        lightByte = 0;
    }
    imp.wakeup(0.1, rotate);
}

// Time mm:ss
imp.configure("Emma Rotate-1", [], []);

rotate();

// Emergency use only - recover from erroring imp not in planner case
//imp.configure("Help me", [], []);