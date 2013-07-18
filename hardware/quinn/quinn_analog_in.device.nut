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

// 6-channel 5A PWM Driver (Float 0.0 to 1.0 In)
 
/* Pin Assignments according to silkscreen
 * Pin 1 = Red 1
 * Pin 2 = Blue 1
 * Pin 5 = Blue 2
 * Pin 7 = Red 2
 * Pin 8 = Green 2
 * Pin 9 = Green 1 
 */
 
/* Note: Green and Blue are switched on the LED strips we purchased
 * blue and green have therefore been switched below:
 * Pin 2 = Green 1
 * Pin 5 = Green 2
 * Pin 8 = Blue 1
 * Pin 9 = Blue 2
 */

// initialize some handy values
// PWM frequency in Hz
local pwm_f = 500.0;

// Configure hardware
hardware.pin1.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin8.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);
hardware.pin9.configure(PWM_OUT, 1.0/pwm_f, 256.0, 256);

server.log("Hardware Configured");

class rgbInput extends InputPort
{
    type = "float"
    redPin = null
    grnPin = null
    bluPin = null
    
    constructor(name, redPin, grnPin, bluPin) {
        base.constructor(name)
        this.redPin = redPin
        this.grnPin = grnPin
        this.bluPin = bluPin
    }
    
    function set(value) {
        // fully counterclockwise = red
        local red = 255.0 - (510.0) * value;
        if (red < 0.0) {
            red = 0.0;
        }
        server.log(format("%s Red set to %.2f", name, red));
        
        // 50% = green
        local green = 0.0;
        if (value < 0.5) {
            green = 255.0 - (510.0 * (0.5 - value));
        } else {
            green = 255.0 - (510.0 * (value - 0.5));
        }
        server.log(format("%s Green set to %.2f", name, green));

        // fully clockwise = blue
        local blue = 0.0;
        if (value <= 0.5) {
            blue = 0.0;
        } else {
            blue = 510.0 * (value-0.5);
        }
        server.log(format("%s Blue set to %.2f,", name, blue));
        
        // now write the values out to the pins
        this.redPin.write(red);
        this.grnPin.write(green);
        this.bluPin.write(blue);
    }
}

class switchInput extends InputPort
{
    name = "Switch Input"
    type = "On/Off"
    
    function set(value) {
        if (value == 0) {
            hardware.pin1.write(0.0);
            hardware.pin2.write(0.0);
            hardware.pin5.write(0.0);
            hardware.pin7.write(0.0);
            hardware.pin8.write(0.0);
            hardware.pin9.write(0.0);
        }
    }
}

server.log("Quinn Started");
local ch1 = rgbInput("Channel 1", hardware.pin1, hardware.pin2, hardware.pin9);
local ch2 = rgbInput("Channel 2", hardware.pin7, hardware.pin5, hardware.pin8);
imp.configure("Quinn", [ch1, ch2, switchInput() ], []);

//EOF