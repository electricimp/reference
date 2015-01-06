
// Shift register SN54LS164W
class Pin
{
    _register = null;
    _pin = null;
    
    constructor(register, pin) {
        _register = register;
        _pin = pin;
    }
    
    function configure(mode, init = null, extra = null) {
        if (mode != DIGITAL_OUT) throw "SN54LS164W only supports DIGITAL_OUT";
        if (init != null) write(init);
    }
    
    function read() {
        return _register.read(_pin);
    }
    
    function write(value) {
        return _register.write(_pin, value);
    }
}

class SN54LS164W
{
    pin_data = null;
    pin_clr = null;
    pin_clk = null;
    
    channelStates = 0;
    
    pinA = null;
    pinB = null;
    pinC = null;
    pinD = null;
    pinE = null;
    pinF = null;
    pinG = null;
    pinH = null;
    
    constructor(data, clear, clock) {

        pin_data = data;
        pin_data.configure(DIGITAL_OUT, 0);
        pin_clr = clear;
        pin_clr.configure(DIGITAL_OUT, 1);
        pin_clk = clock;
        pin_clk.configure(DIGITAL_OUT, 1);

        pinA = Pin(this, 0);
        pinB = Pin(this, 1);
        pinC = Pin(this, 2);
        pinD = Pin(this, 3);
        pinE = Pin(this, 4);
        pinF = Pin(this, 5);
        pinG = Pin(this, 6);
        pinH = Pin(this, 7);
        
    }
    
    function write(channel, state) {
        if (channel < 0 || channel >= 8) return;
        
        if (state) {
            channelStates = channelStates | (0x01 << channel);
        } else {
            channelStates = channelStates & ~(0x01 << channel);
        }
        // server.log(format("Setting channel %d to %3s = 0x%02X", channel, state ? "on" : "off", channelStates));
        
        // Pulse the clear line
        pin_clr.write(0);
        pin_clr.write(1);
        
        // Clock out the bits
        local bit = 0;
        for (local i = 7; i >= 0; i--) {
            bit = (channelStates >> i) & 0x01;
            pin_clk.write(0);
            pin_data.write(bit);
            pin_clk.write(1);
        }
    
        return this;
    }
    
    function read(channel) {
        return (channelStates & (0x01 << channel)) != 0x0;
    }
}
