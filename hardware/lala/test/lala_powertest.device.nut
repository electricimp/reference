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

// Lala current measurement firmware
// Press a button to cycle power modes

// Pinout:
// 1 = Wake / SPI CLK
// 2 = Sampler (Audio In)
// 5 = DAC (Audio Out)
// 6 = Button 1
// 7 = SPI CS_L
// 8 = SPI MOSI
// 9 = SPI MISO
// A = Battery Check (ADC) (Enabled on Mic Enable)
// B = Speaker Enable
// C = Mic Enable
// D = User LED
// E = Button 2

sampleRate <- 8000;

buffer1 <- blob(2000);
buffer2 <- blob(2000);
buffer3 <- blob(2000);
// callback and buffers for the sampler
function samplesReady(buffer, length) {
    if (length > 0) {
        // got a buffer
    } else {
        //server.log("Overrun");
    }
}

function stopSampler() {
    server.log("Stopping sampler");
    // stop the sampler
    hardware.sampler.stop();
}

// configure the sampler at 8kHz
hardware.sampler.configure(hardware.pin2, sampleRate, [buffer1,buffer2,buffer3], 
    samplesReady);

// buttons
hardware.pin6.configure(DIGITAL_IN);
hardware.pinE.configure(DIGITAL_IN);

// SPI CS_L
hardware.pin7.configure(DIGITAL_OUT);
// Battery Check
hardware.pinA.configure(ANALOG_IN);
// speaker enable
hardware.pinB.configure(DIGITAL_OUT);
hardware.pinB.write(0);
// mic enable
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);
// user LED driver
hardware.pinD.configure(DIGITAL_OUT);
hardware.pinD.write(0);

// configure spi bus for spi flash
hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);

button1 <- 1;
button2 <- 1;
function pollButtons() {
    imp.wakeup(0.1, pollButtons);
    local b1 = hardware.pin6.read();
    local b2 = hardware.pinE.read();
    if (b1 != button1) {
        server.log("Button 1 = "+b1);
        button1 = b1;
        if (button1) {
            nextMode();
        }
    }
    if (b2 != button2) {
        server.log("Button 2 = "+b2);
        button2 = b2;
        if (button2) {
            nextMode();
        }
    }
}

mode <- "IDLE";
server.log("In idle mode, press again to enter wifi powersave mode");

function nextMode() {
    if (mode == "IDLE") {
        mode = "PWRSAVE";
        //imp.setpowersave(true);
        server.log("Entered wifi powersave mode, press again to enter record mode");
    } else if (mode == "PWRSAVE") {
        mode = "REC";
        mic.enable();
        hardware.sampler.start();
        server.log("Entered record mode, press again to enter playback mode");
    } else if (mode == "REC") {
        mode = "PLAY";
        // stop recording and turn off the mic
        stopSampler();
        mic.disable();
        // enable speaker
        hardware.pinB.write(1);
        // hit the speaker with a PWM for full-scale signal
        tone(500);
        server.log("Entered playback mode, press again for flash erase")
    } else if (mode == "PLAY") {
        mode = "FLASH";
        // stop playing the tone
        endTone();
        // disable the speaker
        hardware.pinB.write(0);
        // wake the flash
        flash.wake();
        server.log("In flash erase mode, press again to enter deep sleep");
        // start erasing the flash
        flash.erase();
        server.log("Completed erase, flash awake and idling until next command");
    } else if (mode == "FLASH") {
        flash.sleep();
        // we won't get here unless we're already done with a flash erase, which will block (doesn't have to, we just do)
        mode = "SLEEP";
        server.log("Entering deep sleep; press again to wake and idle");
        // configure pin 1 for wakeup and go to sleep
        hardware.pin1.configure(DIGITAL_IN_WAKEUP);
        imp.onidle( function() {
            // sleep for 5 minutes
            server.sleepfor(900);
        });
    }
}

function endTone() {
    hardware.pin5.write(0.0);
}

function tone(freq) {
    hardware.pin5.configure(PWM_OUT, 1.0/freq, 0.5);
}

class microphone {
    function enable() {
        hardware.pinC.write(1);
        // wait for the LDO to stabilize
        imp.sleep(0.05);
        server.log("Microphone Enabled");
    }
    function disable() {
        hardware.pinC.write(0);
        imp.sleep(0.05);
        server.log("Microphone Disabled");
    }
}

class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    WREN = 0x06 // write enable
    WRDI = 0x04; // write disable
    RDID = 0x9F; // read identification
    RDSR = 0x05; // read status register
    READ = 0x03; // read data
    FASTREAD = 0x0B; // fast read data
    RDSFDP = 0x5A; // read SFDP
    RES = 0xAB; // read electronic ID
    REMS = 0x90; // read electronic mfg & device ID
    //const DREAD = 0x3B; // double output mode, which we don't use
    SE = 0x20; // sector erase
    BE = 0x52; // block erase
    CE = 0x60; // chip erase
    PP = 0x02; // page program
    RDSCUR = 0x2B; // read security register
    WRSCUR = 0x2F; // write security register
    ENSO = 0xB1; // enter secured OTP
    EXSO = 0xC1; // exit secured OTP
    DP = 0xB9; // deep power down
    RDP = 0xAB; // release from deep power down
    
    // manufacturer and device ID codes
    mfgID = 0;
    devID = 0;
    
    // spi interface
    spi = hardware.spi189;
    
    // drive the chip select low to select the spi flash
    function select() {
        hardware.pin7.write(0);
    }
    
    // release the chip select for the spi flash
    function unselect() {
        hardware.pin7.write(1);
    }
    
    function wrenable() {
        this.select();
        spi.write(format("%c",WREN));
        this.unselect();
    }
    
    function wrdisable() {
        this.select();
        spi.write(format("%c",WRDI));
        this.unselect();
    }
    
    // note that page write can only set a given bit from 1 to 0
    // a separate erase command must be used to clear the page
    function write(offset, data) {
        this.wrenable();
        
        // check the status register's write enabled bit
        if (!(this.getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
        
        // the command, offset, and data need to go in one burst, so copy into one blob
        local writeBlob = blob(4+data.len());
        // page program command goes first
        writeBlob.writen(PP, 'b');
        // followed by 24-bit address, with no dummy 8 bits (unlike the read command);
        writeBlob.writen((offset >> 16) & 0xFF, 'b');
        writeBlob.writen((offset >> 8) & 0xFF, 'b');
        writeBlob.writen((offset & 0xFF), 'b');
        // then the page of data
        for (local i = 0; i < data.len(); i++) {
            writeBlob.writen(data[i], 'b');
        }
        this.select();
        // now send it all off
        spi.write(writeBlob);
        // release the chip select so the chip doesn't reject the write
        this.unselect();
        
        // wait for the status register to show write complete
        // 1-second timeout
        local timeout = 1000;
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(0.001);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for write to finish");
            return 1;
        }
        
        // writes should be automatically disabled again at the end of the page program, verify.
        if (this.getStatus() & 0x02) {
            server.error("Device: Flash failed to reset write enable after program");
            return 1;
        }
        
        // write successful 
        return 0;
    }
    
    function read(offset, bytes) {
        this.select();
        // to read, send the read command, a 24-bit address, and a dummy byte
        local readBlob = blob(bytes);
        spi.write(format("%c%c%c%c", READ, (offset >> 16) & 0xFF, (offset >> 8) & 0xFF, offset & 0xFF));
        readBlob = spi.readblob(bytes);        
        this.unselect();
        return readBlob;
    }
    
    function getStatus() {
        this.select();
        spi.write(format("%c",RDSR));
        local status = spi.readblob(1);
        this.unselect();
        return status[0];
    }
    
    function getID() {
        this.select();
        spi.write(format("%c",RDID));
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        this.unselect();
    }
    
    function sleep() {
        this.select();
        spi.write(format("%c", DP));
        this.unselect();
    }
    
    function wake() {
        this.select();
        spi.write(format("%c", RDP));
        this.unselect();
    }
    
    // clear the spi flash to 0xFF
    function erase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        this.select();
        spi.write(format("%c", CE));
        this.unselect();
        // chip erase takes a *while*
        local timeout = 50;
        while ((this.getStatus() & 0x01) && timeout > 0) {
            imp.sleep(1);
            timeout--;
        }
        if (timeout == 0) {
            server.error("Device: Timed out waiting for erase to finish");
            return 1;
        }
        server.log("Device: Done with chip erase");
    }
    
    function test() {
        server.log("Testing SPI Flash...");
        local testByte = 0xCC;
        local testAddr = 0x100;
        // read 2 bytes from offset 0x (just a random reg, we're not doing 
        // rigorous memtesting here, just r/w)
        local startVal = this.read(testAddr, 2);
        server.log(format("starting value: 0x %02x %02x",startVal[0],startVal[1]));
        
        // write in one page of test data
        local writeBlob = blob(2);
        for (local i = 0; i < 2; i++) {
            writeBlob.writen(testByte, 'b');
        }
        this.write(testAddr, writeBlob);
        server.log(format("wrote two bytes of 0x%02x at address 0x%04x", testByte, testAddr));
        
        // read out some test bytes to verify
        local testVal = this.read(testAddr, 2);
        server.log(format("read back: 0x %02x %02x",testVal[0],testVal[1]));
    }
}

// instantiate class objects
mic <- microphone();
flash <- spiFlash();
flash.sleep();

// start polling the buttons and checking the battery voltage
pollButtons(); // 100 ms polling interval