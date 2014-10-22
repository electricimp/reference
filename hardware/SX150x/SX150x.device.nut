// Copyright (c) 2013,2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Description: Driver for Semtech SX1504, SX1505 and SX1506 I2C GPIO Expanders
// Datasheet: http://www.semtech.com/images/datasheet/sx150x_456.pdf

class SX150x{
    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;

    //Pass in pre-configured I2C since it may be used by other devices
    constructor(i2c, address = 0x40) {
        _i2c  = i2c;
        _addr = address;  //8-bit address
        _callbacks = [];
    }

    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error("I2C Read Failure. Device: "+_addr+" Register: "+register);
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
    }
    
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0)?(value & ~(1<<bitn)):(value | (1<<bitn));
        writeReg(register, value);
    }
    
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 0 : 1);
    }
    
    // enable or disable internal pull down resistor for specified GPIO
    function setPullDown(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 0 : 1);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    //configure which callback should be called for each pin transition
    function setCallback(gpio, callback){
        _callbacks[gpio] = callback;
    }

    function callback(){
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i]();
            }
        }
    }
}

class SX1505 extends SX150x{
    // I/O Expander internal registers
    BANK_A = {  REGDATA    = 0x00
                REGDIR     = 0x01
                REGPULLUP  = 0x02
                REGPULLDN  = 0x03
                REGINTMASK = 0x05
                REGSNSHI   = 0x06
                REGSNSLO   = 0x07
                REGINTSRC  = 0x08
            }

    constructor(i2c, address=0x20){
        base.constructor(i2c, address);
        _callbacks.resize(8,null);
        this.clearAllIrqs();
    }
    
    function bank(gpio){ return BANK_A; }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? BANK_A.REGSNSHI : BANK_A.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
    }
    
    function getIrq(){
        return (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
}

class SX1506 extends SX150x{
    // I/O Expander internal registers
    static BANK_A = {   REGDATA    = 0x01,
                        REGDIR     = 0x03,
                        REGPULLUP  = 0x05,
                        REGPULLDN  = 0x07,
                        REGINTMASK = 0x09,
                        REGSNSHI   = 0x0B,
                        REGSNSLO   = 0x0D,
                        REGINTSRC  = 0x0F}

    static BANK_B = {   REGDATA    = 0x00,
                        REGDIR     = 0x02,
                        REGPULLUP  = 0x04,
                        REGPULLDN  = 0x06,
                        REGINTMASK = 0x08,
                        REGSNSHI   = 0x0A,
                        REGSNSLO   = 0x0C,
                        REGINTSRC  = 0x0E}

    constructor(i2c, address=0x40){
        base.constructor(i2c, address);
        _callbacks.resize(16,null);
        this.reset();
        this.clearAllIrqs();
    }
    
    //Write registers to default values
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);
        
        writeReg(BANK_B.REGDIR, 0xFF);
        writeReg(BANK_B.REGDATA, 0xFF);
        writeReg(BANK_B.REGPULLUP, 0x00);
        writeReg(BANK_B.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_B.REGSNSHI, 0x00);
        writeReg(BANK_B.REGSNSLO, 0x00);
    }

    function debug(){
        server.log(format("A-DATA   (0x%02X): 0x%02X",BANK_A.REGDATA, readReg(BANK_A.REGDATA)));
        imp.sleep(0.1);
        server.log(format("A-DIR    (0x%02X): 0x%02X",BANK_A.REGDIR, readReg(BANK_A.REGDIR)));
        imp.sleep(0.1);
        server.log(format("A-PULLUP (0x%02X): 0x%02X",BANK_A.REGPULLUP, readReg(BANK_A.REGPULLUP)));
        imp.sleep(0.1);
        server.log(format("A-PULLDN (0x%02X): 0x%02X",BANK_A.REGPULLDN, readReg(BANK_A.REGPULLDN)));
        imp.sleep(0.1);
        server.log(format("A-INTMASK (0x%02X): 0x%02X",BANK_A.REGINTMASK, readReg(BANK_A.REGINTMASK)));
        imp.sleep(0.1);
        server.log(format("A-SNSHI  (0x%02X): 0x%02X",BANK_A.REGSNSHI, readReg(BANK_A.REGSNSHI)));
        imp.sleep(0.1);
        server.log(format("A-SNSLO  (0x%02X): 0x%02X",BANK_A.REGSNSLO, readReg(BANK_A.REGSNSLO)));
        imp.sleep(0.1);
        server.log(format("B-DATA   (0x%02X): 0x%02X",BANK_B.REGDATA, readReg(BANK_B.REGDATA)));
        imp.sleep(0.1);
        server.log(format("B-DIR    (0x%02X): 0x%02X",BANK_B.REGDIR, readReg(BANK_B.REGDIR)));
        imp.sleep(0.1);
        server.log(format("B-PULLUP (0x%02X): 0x%02X",BANK_B.REGPULLUP, readReg(BANK_B.REGPULLUP)));
        imp.sleep(0.1);
        server.log(format("B-PULLDN (0x%02X): 0x%02X",BANK_B.REGPULLDN, readReg(BANK_B.REGPULLDN)));
        imp.sleep(0.1);
        server.log(format("B-INTMASK (0x%02X): 0x%02X",BANK_B.REGINTMASK, readReg(BANK_B.REGINTMASK)));
        imp.sleep(0.1);
        server.log(format("B-SNSHI  (0x%02X): 0x%02X",BANK_B.REGSNSHI, readReg(BANK_B.REGSNSHI)));
        imp.sleep(0.1);
        server.log(format("B-SNSLO  (0x%02X): 0x%02X",BANK_B.REGSNSLO, readReg(BANK_B.REGSNSLO)));
        
        // imp.sleep(0.1);
        // foreach(idx,val in BANK_A){
        //     server.log(format("Bank A %s (0x%02X): 0x%02X", idx, val, readReg(val)));
        //     imp.sleep(0.1);
        // }
        // foreach(idx,val in BANK_B){
        //     server.log(format("Bank B %s (0x%02X): 0x%02X", idx, val, readReg(val)));
        //     imp.sleep(0.1);
        // }
        // for(local i =0; i < 0x2F; i++){
        //     server.log(format("0x%02X: 0x%02X", i, readReg(i)));
        // }

    }

    function bank(gpio){
        return (gpio > 7) ? BANK_B : BANK_A;
    }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges( gpio, rising, falling) {
        local bank = bank(gpio);
        gpio = gpio % 8;
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? bank.REGSNSHI : bank.REGSNSLO, data, mask);
    }

    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
        writeReg(BANK_B.REGINTSRC,0xff);
    }

    function getIrq(){
        return ((readReg(BANK_B.REGINTSRC) & 0xFF) << 8) | (readReg(BANK_A.REGINTSRC) & 0xFF);
    }
}


//----------------------------------------------------------------------------------
//  Example Code
//----------------------------------------------------------------------------------

//Check the repo for lastest variant of the ExpGPIO class
class ExpGPIO{
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }
    
    //Optional initial state (defaults to 0 just like the imp)
    function configure(mode, callback = null, initialstate=0) {
        // set the pin direction and configure the internal pullup resistor, if applicable
        _expander.setPin(_gpio,initialstate);
        if (mode == DIGITAL_OUT) {
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
        } else if (mode == DIGITAL_IN_PULLUP) {
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
        }
        
        // configure the pin to throw an interrupt, if necessary
        if (callback) {
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio,callback);            
        } else {
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }
    }
    
    function write(state) { _expander.setPin(_gpio,state); }
    
    function read() { return _expander.getPin(_gpio); }
}

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

// Initialize an 8-channel I2C I/O Expander (SX1505)
ioexp <- SX1505(i2c,0x40);    // instantiate I/O Expander

// Imp Pin configuration
ioexp_int_l     <- hardware.pin1;   // I/O Expander Alert (Active Low)

//Make GPIO instances for each IO on the expander
btn1            <- ExpGPIO(ioexp, 4);     // User Button 1 (GPIO 4)
btn2            <- ExpGPIO(ioexp, 5);     // User Button 2 (GPIO 5)

//Initialize the interrupt Pin
ioexp_int_l.configure(DIGITAL_IN_PULLUP, ioexp.callback.bindenv(ioexp))

// Configure the Two buttons
btn1.configure(DIGITAL_IN_PULLUP, function(){server.log("Button 1:"+btn1.read())});
btn2.configure(DIGITAL_IN_PULLUP, function(){server.log("Button 2:"+btn2.read())});
