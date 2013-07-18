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

// Kaylee controlling lighting devices via DMX-512

// configure Serial UART
// dmx512 uses 8 data bits, 1 start bit, 2 stop bits, no parity bits, no flow control
//hardware.uart12.configure(250000, 8, PARITY_NONE, 2, NO_CTSRTS);

// pin 5 is a GPIO used to select between receive and transmit modes on the RS-485 translator
// externally pulled down (100k)
// set high to transmit
hardware.pin5.configure(DIGITAL_OUT);
hardware.pin5.write(1);

// build up a static 512-device DMX frame 
local outBlob = blob(1024);

// populate the blob with null data
for (local i = 0; i < 512; i++) {
    outBlob.writen(0x00, 'b');
}

function setLevel(addr, level) {
    // send DMX512 command to set device at "addr"
    outBlob.seek(addr);
    outBlob.writen(level, 'b');
    
    // enable transmitter
    //hardware.pin5.write(1);
    
    // manually send out the break and mark-after-break
    hardware.pin1.configure(DIGITAL_OUT);
    // break
    hardware.pin1.write(0);
    imp.sleep(0.0001);
    /*
    hardware.pin1.write(1);
    imp.sleep(0.00001);
    */
    
    hardware.uart12.configure(250000, 8, PARITY_NONE, 2, NO_CTSRTS);
    hardware.uart12.write(outBlob);
}

function refreshLevels() {
    // manually send out the break and mark-after-break
    hardware.pin1.configure(DIGITAL_OUT);
    // break
    hardware.pin1.write(0);
    imp.sleep(0.0001);

    hardware.uart12.configure(250000, 8, PARITY_NONE, 2, NO_CTSRTS);
    hardware.uart12.write(outBlob);
}

class RGBInput extends InputPort {
    name = "color input"
    type = "addr,level"
    red = 0
    green = 0
    blue = 0
    
    function set(value) {
        try {
            local command = split(value, ",");
            red = command[0].tointeger();
            green = command[1].tointeger();
            blue = command[2].tointeger();
            server.log(format("red: 0x%02x green: 0x%02x blue: 0x%02x", red, green, blue));
        } catch (err) {
            server.error("Invalid Input");
        }
        setLevel(1, red);
        setLevel(2, green);
        setLevel(3, blue);
    }
}

imp.configure("Kaylee DMX512 Controller",[RGBInput()],[]);

setLevel(1,0x00);
setLevel(2,0x00);
setLevel(3,0xff);

function refresh() {
    //server.log("Refreshing DMX devices");
    refreshLevels();
    imp.wakeup(0.2, refresh);
}

refresh();