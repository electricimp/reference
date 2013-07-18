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

// Set Hannah's on-board RGB LED to the "inverse" of input temperature in C

class IoExpander {
    
    i2cPort = null;
    i2cAddress = null;
    
    constructor(port, address) {
        if(port == I2C_12) {
            hardware.configure(I2C_12);
            i2cPort = hardware.i2c12;
            //server.log("Configure I2C 12")
        } else if (port == I2C_89) {
            hardware.configure(I2C_89);
            i2cPort = hardware.i2c89;
            //server.log("Configure I2C 89")
        } else {
            server.error("Invalid I2C port specified.")
        }
        
        // 7-bit addressing
        i2cAddress = address << 1;
    }
    
    function read(register) {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if(data == null) {
            server.log("I2C Read Failure");
            return -1;
        }
        
        return data[0];
    }
    
    function write(register, data) {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = read(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        write(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = read(register);
        value = (value & ~mask) | (data & mask);
        write(register, value);
    }
    // set or clear a selected GPIO pin, 0-15
    function setPin(gpio, level) {
        writeBit(gpio >= 8 ? 0x10 : 0x11, gpio & 7, level ? 1 : 0);
    }
    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(gpio >= 8 ? 0x0e : 0x0f, gpio & 7, output ? 0 : 1);
    }
    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(gpio >= 8 ? 0x06 : 0x07, gpio & 7, enable);
    }
    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit( gpio >= 8 ? 0x12 : 0x13, gpio & 7, enable);
    }
    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local addr = 0x17 - (gpio >> 2);
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(addr, data, mask);
    }
    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(gpio >= 8 ? 0x18 : 0x19, gpio & 7, 1);
    }
    
    // get state of specified GPIO
    function getPin(gpio) {
        return (read(gpio >= 8 ? 0x10: 0x11) & (1<<(gpio & 7))) ? 1 : 0;
    }
}

// RgbLed Class derived from IoExpander to represent an RGB LED. 
class RgbLed extends IoExpander
{
    pinR = null;
    pinG = null;
    pinB = null;
    
    constructor(port, address, r, g, b) {
        base.constructor(port, address);
        
        // save pin assignments
        pinR = r;
        pinG = g;
        pinB = b;
        
        // Disable pin input buffers
        writeBit(pinR > 7 ? 0x00 : 0x01, pinR > 7 ? (pinR - 7) : pinR, 1);
        writeBit(pinG > 7 ? 0x00 : 0x01, pinG > 7 ? (pinG - 7) : pinG, 1);
        writeBit(pinB > 7 ? 0x00 : 0x01, pinB > 7 ? (pinB - 7) : pinB, 1);
        
        // set pins as outputs
        writeBit(pinR > 7 ? 0x0E : 0x0F, pinR > 7 ? (pinR - 7) : pinR, 0);
        writeBit(pinG > 7 ? 0x0E : 0x0F, pinG > 7 ? (pinG - 7) : pinG, 0);
        writeBit(pinB > 7 ? 0x0E : 0x0F, pinB > 7 ? (pinB - 7) : pinB, 0);
        
        // set pins as open drain
        writeBit(pinR > 7 ? 0x0A : 0x0B, pinR > 7 ? (pinR - 7) : pinR, 1);
        writeBit(pinG > 7 ? 0x0A : 0x0B, pinG > 7 ? (pinG - 7) : pinG, 1);
        writeBit(pinB > 7 ? 0x0A : 0x0B, pinB > 7 ? (pinB - 7) : pinB, 1);
        
        // Enable LED drive
        writeBit(pinR > 7 ? 0x20 : 0x21, pinR > 7 ? (pinR - 7) : pinR, 1);
        writeBit(pinG > 7 ? 0x20 : 0x21, pinG > 7 ? (pinG - 7) : pinG, 1);
        writeBit(pinB > 7 ? 0x20 : 0x21, pinB > 7 ? (pinB - 7) : pinB, 1);
        
        // Set to use internal 2 MHz clock, linear fading
        write(0x1e, 0x50);
        write(0x1f, 0x10);
        
        // Initialize as inactive
        setLevels(0, 0, 0);
        setPin(pinR, 0);
        setPin(pinG, 0);
        setPin(pinB, 0);

    }
    
    // enables or disables each color segment, or makes no change
    function setLed(r, g, b) {
        if(r != null) writeBit(pinR > 7 ? 0x20 : 0x21, pinR & 7, r);
        if(g != null) writeBit(pinG > 7 ? 0x20 : 0x21, pinG & 7, g);
        if(b != null) writeBit(pinB > 7 ? 0x20 : 0x21, pinB & 7, b);
    }
    
    // set rgb intensity 
    function setLevels(r, g, b) {
        if( r != null ) write( pinR < 4 ? 0x2A+pinR*3 : 0x36+(pinR-4)*5, r );
        if( g != null ) write( pinG < 4 ? 0x2A+pinG*3 : 0x36+(pinG-4)*5, g );
        if( b != null ) write( pinB < 4 ? 0x2A+pinB*3 : 0x36+(pinB-4)*5, b );
    }
}


class paintTempInv {
    
    name = "Temp Input";
    type = "number";
    
    function set(value) {
        server.log(format("Temp: %d C", value));
        server.show(format("Temp: %d C", value));
        
        // Construct an LED
        local led = RgbLed(I2C_89, 0x3E, 7, 5, 6);
        
        // min temp is 0 C (full-on red)
        // max temp is 30 C (full-on blue)
        if (value < 0) {
            value = 0;
        } else if (value > 30) {
            value = 30;
        }
        
        // scale red inverse to temp, from 0 to 20 C
        local r = 255.0 - (255.0/20.0) * value;
        if (r < 0) {
            r = 0;
        }
        server.log(format("Red level set to %f", r));
        
        // scale green proportionally to temp from 5 to 15, inversely from 15 to 25
        local g = 255 - (25.5 * (math.abs(value-15)));
        if (g < 0) {
            g = 0;
        }
        server.log(format("Green set to %f", g));

        // scale blue proportionally to temp, from 10 to 30 C
        local b = (255.0/20.0) * (value-10);
        if (b < 0) {
            b = 0;
        }
        server.log(format("Blue level set to %f", b));        
        
        // Set LED color
        led.setLevels(r, g, b);           
    }
}

// Register with the server

imp.configure("Inverse Weather Painter", [paintTempInv()], []);
