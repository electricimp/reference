// Copyright (c) 2013,2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Description: DMX512 Controller via impee-Kaylee

const DMXBAUD     = 250000;
const FRAMESIZE   = 513;  // max 512 devices per frame ("universe"), 1 bytes per device, plus 1-byte start code
const FRAMEPERIOD = 0.2; // send frame once per 200 ms

class Dmx512Controller {
    
    uart        = null;
    tx_en       = null;
    tx_pin      = null;
    
    frame = blob(FRAMESIZE);
    
    constructor(_uart, _tx_pin, _tx_en_pin) {
        uart = _uart;
        tx_pin = _tx_pin;
        tx_en = _tx_en_pin;
        clearFrame();
        sendFrame();
    }
    
    function clearFrame() {
        frame.seek(0);
        while(!frame.eos()) {
            frame.writen(0x00,'b');
        }
    }
    
    function sendFrame() {
        // schedule this function to run again in FRAMEPERIOD
        imp.wakeup(FRAMEPERIOD, sendFrame.bindenv(this));
        
        // send the break
        tx_pin.configure(DIGITAL_OUT,0);

        // uart.configure takes more than long enough to be the mark after break. 
        // It would be great if this were faster.
        uart.configure(DMXBAUD, 8, PARITY_NONE, 2, NO_CTSRTS);
        
        // send the frame
        uart.write(frame);
    }
    
    function setChannel(channel, value) {
        // DMX channels are 1-based, with frame slot 0 reserved for the start code
        // currently, only start code 0x00 is used (default value)
        if (channel < 1) { channel = 1; } 
        if (channel > 512) { channel = 512; }
        frame[channel] = (value & 0xff);
        // value will be sent to device next time frame is sent
    }
    
}

// RUNTIME STARTS --------------------------------------------------------------

imp.enableblinkup(true);
server.log(imp.getmacaddress());
server.log(hardware.getdeviceid());
server.log(imp.getsoftwareversion());

// pin 5 is a GPIO used to select between receive and transmit modes on the RS-485 translator
// externally pulled down (100k)
// set high to transmit
tx_en <- hardware.pin5;
tx_en.configure(DIGITAL_OUT);
tx_en.write(1);
uart <- hardware.uart12;
uart.configure(DMXBAUD, 8, PARITY_NONE, 2, NO_CTSRTS)
tx_pin <- hardware.pin1;

dmx <- Dmx512Controller(uart, tx_pin, tx_en);

dmx.setChannel(7, 0xAA);