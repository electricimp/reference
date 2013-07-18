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

// Lala sleep cycler
// deep sleep, waking every (programmable) seconds
// log battery voltage and wake count to COSM

// A = Battery Check (ADC) (Enabled on Mic Enable)
// C = Mic Enable

// sleep time in seconds
// NOTE: server.sleepfor always adds 4 seconds to your sleep time
sleepTime <- 1;

// Battery measurement pin
hardware.pinA.configure(ANALOG_IN);

// mic enable / battery check enable
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);

//Check Battery Usage Over a series of wakeups
if (!("nv" in getroottable()) || !("count" in nv)){nv <- {count = 0, vtot = 0, vcnt = 0};}
 
cnt <- OutputPort("Count", "number");
vin <- OutputPort("Vbatt", "number");
 
imp.configure("Sleep Cycler", [], [cnt,vin]);

function checkBattery() {
    // no need to schedule callback here because we'll deep sleep and therefore reload
    // enable the battery check
    hardware.pinC.write(1);
    // this turns on the LDO, too, so let that settle
    imp.sleep(0.05);
    // read the ADC
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    // turn the battery check back off
    hardware.pinC.write(0);
    // log the value
    server.log(format("Battery Voltage %.2f V",Vbatt));
    return Vbatt;
}
 
//Boot Count
nv.count += 1;

// Averaging Sum and Counter
nv.vtot += checkBattery();
nv.vcnt += 1;
 
//Only send every 10th sample so Cosm doesn't hate us.
if(nv.count == 1 || nv.vcnt == 10){
    server.log("Posting Values to COSM");
    vin.set(nv.vtot/nv.vcnt);
    cnt.set(nv.count);
    nv.vtot = 0;
    nv.vcnt = 0;
}
 
imp.onidle( function() {server.sleepfor(sleepTime);});