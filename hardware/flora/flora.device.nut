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

// water level sensor
server.log("Flora booted");

local out1 = OutputPort("Water level");
imp.configure("Water level sensor", [], [out1]);

// moar battery life
// imp.setpowersave(true);

local enable = hardware.pin9;
local counter = hardware.pin1;

enable.configure(DIGITAL_OUT);
enable.write(1);

counter.configure(PULSE_COUNTER, 0.01);

local prev = -1.0;

function sample() {
    local count;
    local level;

    // turn on oscillator, sample, turn off
    enable.write(1);
    count = counter.read();
    enable.write(0);
    
    // work out level
    if (count > 5000) level=0;
    else {
        // see http://www.xuru.org/rt/PowR.asp#CopyPaste
        level = math.pow(count/3035.162425, -1.1815893306620);
        if (level<0.0) level=0.0;
    }

    // convert to a zero to one type thing
    level=level/10.0;
    if (level>1.0) level=1.0;
    
    //level = 4.0*level;

    if (math.fabs(level - prev) > 0.005) {
        server.show(format("%.2f",level)); 
        //server.log(format("%.2f",level));        
        out1.set(level);
        prev = level;
    }

    // changed this to every second
    imp.wakeup(0.05, sample); 
}

sample();
