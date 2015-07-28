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

/* 
 * GPIO Expander Abstraction.
 * Requires Hardware Base Class, passed in as argument (See SX150X)
 * Tom Byrne
 * tom@electricimp.com
 * 11/21/2013
 */

class expGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    // Optional initial state (defaults to 0 just like the imp)
    function configure(mode, callback_initialstate = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if (callback_initialstate != null) {
                _expander.setPin(_gpio, callback_initialstate);    
            } else {
                _expander.setPin(_gpio, 0);
            }
            
            return this;
        }
            
        if (mode == DIGITAL_IN) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (typeof callback_initialstate == "function") {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, callback_initialstate);
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
        
        return this;
    }
    
    function write(state) { _expander.setPin(_gpio,state); }
    
    function read() { return _expander.getPin(_gpio); }
}

/* EXAMPLE RUNTIME STARTS HERE ----------------------------------------------*/
/*

ioexp_int_l     <- hardware.pin1;   // I/O Expander Alert (Active Low)
i2c             <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
// SCL          <- hardware.pin8;   // I2C CLOCK
// SDA          <- hardware.pin9;   // I2C DATA

ioexp <- SX1505(i2c,IOEXP_ADDR);    // instantiate I/O Expander
// configure I/O Expander interrupt pin to check for callbacks on the I/O Expander
ioexp_int_l.configure(DIGITAL_IN, function(){ ioexp.callback(); });

// Two buttons on GPIO Expander
btn1            <- expGPIO(ioexp, 0).configure(DIGITAL_IN, function() { server.log("Button 1 Changed."); });     // User Button 1 (GPIO 0)
btn2            <- expGPIO(ioexp, 1).configure(DIGITAL_IN, function() { server.log("Button 2 Changed."); });     // User Button 2 (GPIO 1)
*/
