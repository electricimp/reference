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

// We wait to configure Serial UART because we must bit-bang the break and mark-on-break
// DMX uses 8 data bits, 1 start bit, 2 stop bits, no parity bits, no flow control

// pin 5 is a GPIO used to select between receive and transmit modes on the RS-485 translator
// externally pulled down (100k)
// set high to transmit; we're doing DMX and therefore never receive, so just set it high now.
hardware.pin5.configure(DIGITAL_OUT);
hardware.pin5.write(1);

// build up a static 512-device DMX frame
local outBlob = blob(512);

// populate the blob with null data
for (local i = 0; i < 512; i++) {
    outBlob.writen(0x00, 'b');
}

function setLevel(addr, level) {
    // send DMX512 command to set device at "addr"
    outBlob.seek(addr);
    outBlob.writen(level, 'b');
    
    // the frame will automatically be sent on the next refresh
}

function refresh() {
    // manually send out the break and mark-after-break
    hardware.pin1.configure(DIGITAL_OUT);
    // break
    hardware.pin1.write(0);
    imp.sleep(0.0001);
    
    // mark-after-break is implicitly sent here; bus idles high while we configure the UART in SW
    hardware.uart12.configure(250000, 8, PARITY_NONE, 2, NO_CTSRTS);
    
    // send the frame
    hardware.uart12.write(outBlob);
    
    // schedule next refresh
    imp.wakeup(0.1, refresh);
}

// Two input ports: one for full 512-device DMX frame, one for individual channel levels
// This input port takes in full frames. If receiving as a string from the internet, 
// try using an agent to parse to an array and sanitize input!
class chanInput extends InputPort {
    name = "full DMX Frame input"
    type = "array[512]"
    
    function set(frame) {
        try {
            for (i = 0; i < 512; i++) {
                local val = frame[i];
                if (val > 256) {
                    val = 256;
                } else if (val < 0) {
                    val = 0;
                }
                setLevel(i, val);
            }
        } catch (err) {
            server.error("Invalid Frame Input");
        }
        // frame will be sent on next refresh (max 100ms)
    }
}

// This input port takes in individual frames (offset, value)
class frameInput extends InputPort {
    name = "channel input"
    type = "array[2] = [addr, val]"
    
    function set(channel) {
        try {
            local addr = channel[0];
            if (addr > 512 || addr < 1) {
                server.error("Invalid Address");
                return;
            }
            local val = channel[1];
            if (val > 256) {
                val = 256;
            } else if (val < 0) {
                val = 0;
            }
            setLevel(addr, val);
        } catch (err) {
            server.error("Invalid Channel Input");
        }
        // frame will be sent on next refresh (max 100ms)
    }
}

imp.configure("Kaylee DMX512 Controller",[frameInput(),chanInput()],[]);

// call refresh the first time to set up the loop
refresh();