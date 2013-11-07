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
 * Class(es) for SX150X I/O Expander Family
 * http://www.semtech.com/images/datasheet/sx150x_789.pdf
 * Tom Byrne
 * tom@electricimp.com
 * 10/21/2013
 */

class SX1505 {
    
    i2cPort = null;
    i2cAddress = null;
    alertpin = null;
    // callback functions {pin,callback}
    callbacks = {};
    
    // I/O Expander internal registers
    REGDATA     = 0x00;
    REGDIR      = 0x01;
    REGPULLUP   = 0x02;
    REGPULLDN   = 0x03;
    REGINTMASK  = 0x05;
    REGSNSHI    = 0x06;
    REGSNSLO    = 0x07;
    REGINTSRC   = 0x08;
    REGEVNTSTS  = 0x09;
    REGPLDMODE  = 0x10;
    REGPLDTBL0  = 0x11;
    REGPLDTBL1  = 0x12;
    REGPLDTBL2  = 0x13;
    REGPLDTBL3  = 0x14;
    REGPLDTBL4  = 0x15;
    
    function decode_callback() {
        //server.log("Decoding Callback");
        if (!alertpin.read()) {
            local irqPinMask = this.readReg(REGINTSRC);
            /*
            server.log(format("REGINTSRC:  0x%02x",irqPinMask));
            server.log(format("REGDATA:    0x%02x",this.readReg(REGDATA)));
            server.log(format("REGDIR:     0x%02x",this.readReg(REGDIR)));
            server.log(format("REGPULLUP:  0x%02x",this.readReg(REGPULLUP)));
            server.log(format("REGPULLDN:  0x%02x",this.readReg(REGPULLDN)));
            server.log(format("REGINTMASK: 0x%02x",this.readReg(REGINTMASK)));
            server.log(format("REGSNSHI:   0x%02x",this.readReg(REGSNSHI)));
            server.log(format("REGSNSLO:   0x%02x",this.readReg(REGSNSLO)));
            server.log(format("REGEVNTSTTS:0x%02x",this.readReg(REGEVNTSTS)));
            */
            clearAllIrqs();
            callbacks[irqPinMask]();   
        }
    }
    
    constructor(port, address, alertpin) {
        try {
            i2cPort = port;
            i2cPort.configure(CLOCK_SPEED_100_KHZ);
            this.alertpin = alertpin;
        } catch (err) {
            server.error("Error configuring I2C for I/O Expander: "+err);
        }
        
        // 7-bit addressing
        i2cAddress = address << 1;
        
        // configure alert pin to figure out which callback needs to be called
        if (alertpin) {
            alertpin.configure(DIGITAL_IN_PULLUP,decode_callback.bindenv(this));
        }
        
        // clear all IRQs just in case
        clearAllIrqs();
    }
    
    function readReg(register) {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if (data == null) {
            server.error("I2C Read Failure");
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        //server.log("made it to writebit");
        local value = readReg(register);
        //server.log(format("writebit got 0x%x",value));
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        //server.log(format("writing back 0x%x",value));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }
    // set or clear a selected GPIO pin, 0-15
    function setPin(gpio, level) {
        writeBit(REGDATA, gpio, level ? 1 : 0);
    }
    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        //server.log("made it to setDir");
        writeBit(REGDIR, gpio, output ? 0 : 1);
    }
    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        //server.log("made it to setPullUp");
        writeBit(REGPULLUP, gpio, enable ? 0 : 1);
    }
    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(REGINTMASK, gpio, enable ? 0 : 1);
    }
    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? REGSNSHI : REGSNSLO, data, mask);
    }
    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(REGINTMASK, gpio, 1);
    }
    function clearAllIrqs() {
        writeReg(REGINTSRC,0xff);
    }
    
    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(REGDATA) & (1<<gpio)) ? 1 : 0);
    }
}

class expGpio extends SX1505 {
    
    // pin number of this GPIO pin
    gpio = null;
    // imp pin to throw interrupt on, if configured
    alertpin = null;
    
    constructor(port, address, gpio, alertpin = null) {
        base.constructor(port, address, alertpin);
        this.gpio = gpio;
    }
    
    function configure(mode, callback = null) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        if (mode == DIGITAL_OUT) {
            base.setDir(gpio,1);
            base.setPullUp(gpio,0);
        } else if (mode == DIGITAL_IN) {
            base.setDir(gpio,0);
            base.setPullUp(gpio,0);
            //server.log("GPIO Expander Pin "+gpio+" Configured");
        } else if (mode == DIGITAL_IN_PULLUP) {
            base.setDir(gpio,0);
            base.setPullUp(gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (callback) {
            base.setIrqMask(gpio,1);
            base.setIrqEdges(gpio,1,1);
            
            // add this callback to the base's callbacks table
            base.callbacks[(0xff & (0x01 << gpio))] <- callback;
            //server.log("GPIO Expander Callback added to table");
        } else {
            base.setIrqMask(gpio,0);
            base.setIrqEdges(gpio,0,0);
        }
    }
    
    function write(state) {
        base.setPin(gpio,state);
    }
    
    function read() {
        return base.getPin(gpio);
    }
}