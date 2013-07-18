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

/* Lala Audio Impee

 Tom Buttner, April 2013
 Electric Imp, inc
 tom@electricimp.com
*/

/* GLOBAL CONSTANTS ---------------------------------------------------------*/
// determines size of data chunks sent to/from the agent
const CHUNKSIZE = 4096;

/* REGISTER WITH IMP SERVICE and do power-sensitive configuration -----------*/

// turn on powersave to reduce average wifi power by skipping beacons
// note that this increases network latency by up to 300 ms
imp.setpowersave(true);

// register with the imp service
imp.configure("Lala Audio Impee", [],[]);

/* GLOBAL PARAMETERS AND FLAGS ----------------------------------------------*/

// parameters for wav file are passed in from the agent
inParams <- {};

// parameters for files uploaded to agent
outParams <- {
    compression = A_LAW_COMPRESS | NORMALISE,
    width = 'b',
    samplerate = 16000,
    len = 0,
}

// pointers and flags for playback and recording
playbackPtr <- 0;
playing <- false;
recordPtr <- 0;
recording <- false;

// flag for new message downloaded from the agent
newMessage <- false;

/* PIN CONFIGURATION AND ALIASING -------------------------------------------*/
/*
 Pinout:
 1 = Wake / SPI CLK
 2 = Sampler (Audio In)
 5 = DAC (Audio Out)
 6 = Button 1
 7 = SPI CS_L
 8 = SPI MOSI
 9 = SPI MISO
 A = Battery Check (ADC) (Enabled on Mic Enable)
 B = Speaker Enable
 C = Mic Enable
 D = User LED
 E = Button 2
*/
// buttons
button1 <- hardware.pin6;
button1.configure(DIGITAL_IN);
button2 <- hardware.pinE;
button2.configure(DIGITAL_IN);

// SPI CS_L
hardware.pin7.configure(DIGITAL_OUT);

// Battery Check
hardware.pinA.configure(ANALOG_IN);

// speaker enable
speakerEnable <- hardware.pinB;
speakerEnable.configure(DIGITAL_OUT);
speakerEnable.write(0);

// mic enable
hardware.pinC.configure(DIGITAL_OUT);
hardware.pinC.write(0);

// user LED driver
led <- hardware.pinD;
led.configure(DIGITAL_OUT);
led.write(0);

// configure spi bus for spi flash
//hardware.spi189.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);

/* SAMPLER AND FIXED-FREQUENCY DAC -------------------------------------------*/

// callback and buffers for the sampler
function samplesReady(buffer, length) {
    if (length > 0) {
        flash.writeChunk((flash.recordOffset+recordPtr), buffer);
        // advance the record pointer
        recordPtr += length;
    } else {
        server.log("Device: Sampler Buffer Overrun");
    }
}

// clean up after stopping the sampler
function finishRecording() {
    server.log("Device: done recording, stopping.");
    server.log("Device: free memory: "+imp.getmemoryfree());
    
    // put the flash to sleep to save power
    flash.sleep();
    
    // remember how long the recorded buffer is
    outParams.len = recordPtr;
    
    // reset the record pointer; we'll use it to walk through flash and upload the message to the agent
    recordPtr = 0;

    // turn off powersave to reduce latency while uploading to the agent
    imp.setpowersave(false);

    // reconfigure the sampler to free the memory allocated for sampler buffers
    hardware.sampler.configure(hardware.pin2, outParams.samplerate, [blob(2),blob(2),blob(2)], 
        samplesReady, outParams.compression);

    // signal to the agent that we're ready to upload this new message
    agent.send("newMessage", outParams);
    // the agent will call back with a "pull" request, at which point we'll read the buffer out of flash and upload
}

function stopSampler() {
    if (recording) {
        server.log("Device: Stopping Sampler");
        // stop the sampler
        hardware.sampler.stop();

        // the sampler will immediately call samplesReady to empty its last buffer
        // following samplesReady, the imp will idle, and finishRecording will be called
        imp.onidle(finishRecording);

        // clear the recording flag
        recording = false;

        // we erase pages at startup and after upload, so we don't need to do so again here
        // disable the microphone preamp
        mic.disable();
    }   
}

// callback for the fixed-frequency DAC
function playbackBufferEmpty(buffer) {
    //server.log("Playback buffer empty");
    //server.log("Device: free memory: "+imp.getmemoryfree());
    if (!buffer) {
        if (playbackPtr >= inParams.dataChunkSize) {
            // we've just played the last buffer; time to stop the ffd
            stopPlayback();
            return;
        } else {
            server.log("FFD Buffer underrun");
            return;
        }
    }
    if (playbackPtr >= inParams.dataChunkSize) {
        server.log("Not reloading buffers; end of message");
        // we're at the end of the message buffer, so don't reload the DAC
        // the DAC will be stopped before it runs out of buffers anyway
        return;
    }

    // read another buffer out of the flash and load it back into the DAC
    hardware.fixedfrequencydac.addbuffer( flash.read( playbackPtr, buffer.len() ) );

    playbackPtr += buffer.len();
}

// prep buffers to begin message playback
function loadPlayback() {
    server.log("Device: loading buffers before starting playback");

    // advance the playback pointer to show we've loaded the first three buffers
    playbackPtr = 3*CHUNKSIZE;

    local compression = 0;
    if (inParams.compressionCode == 0x06) {
        compression = A_LAW_DECOMPRESS;
    }

    // configure the DAC
    hardware.fixedfrequencydac.configure( hardware.pin5, inParams.samplerate,
         [flash.read(0, CHUNKSIZE),
            flash.read(CHUNKSIZE, CHUNKSIZE),
            flash.read((2*CHUNKSIZE), CHUNKSIZE)],
         playbackBufferEmpty, compression );

    server.log("Device: DAC configured");
}

function stopPlayback() {
    server.log("Device: Stopping Playback");
    // stop the DAC
    hardware.fixedfrequencydac.stop();
    // disable the speaker
    speakerEnable.write(0);
    // put the flash back to sleep
    flash.sleep();
    // return the playback pointer for the next time we want to play this message (now that it's cached);
    playbackPtr = 0;
    // set the flag to show that there is no longer a playback in progress
    playing = false;
}

/* GLOBAL FUNCTIONS ----------------------------------------------------------*/
lastState1 <- 1;
lastState2 <- 1;
blinkCntr <- 0;
function pollButtons() {
    imp.wakeup(0.1, pollButtons);
    // manage LED blink here
    if (newMessage) {
        // turn LED for 200 ms out of every 2 seconds
        if (blinkCntr == 18) {
            led.write(1);
        } else if (blinkCntr == 20) {
            led.write(0);
        }
    } else if (recording) {
        // let the LED stay on if we're recording
        led.write(1);
    } else {
        // make sure the LED is off
        led.write(0);
    }
    if (blinkCntr > 19) {
        //server.log("Device: free memory: "+imp.getmemoryfree());
        blinkCntr = 0;
    }
    blinkCntr++;
    // now handle the buttons
    local state1 = button1.read();
    local state2 = button2.read();
    if (state1 != lastState1) {
        lastState1 = state1;
        if (!lastState1) {
            if (recording || playing) {
                server.log("Device: operation already in progress");
                return;
            }
            recordMessage();
        } else {
            // stop recording on button release
            if (recording) {
                stopSampler();
            }
        }
    }
    if (state2 != lastState2) {
        lastState2 = state2;
        if (!lastState2) {
            if (recording || playing) {
                server.log("Device: operation already in progress");
                return;
            }
            if (inParams.dataChunkSize) {
                playMessage();
            }
        }
    }
}

function recordMessage() {
    server.log("Device: recording message to flash");

    // set the recording flag
    recording = true;

    // set the record pointer to zero; this points filled buffers to the proper area in flash
    recordPtr = 0;

    // wake up the flash
    flash.wake();

    // we erase pages at startup and after upload, so we don't need to do so again here
    // enable the microphone preamp
    mic.enable();

    // configure the sampler

    hardware.sampler.configure(hardware.pin2, outParams.samplerate, 
        [blob(CHUNKSIZE),
            blob(CHUNKSIZE),
            blob(CHUNKSIZE)], 
        samplesReady, outParams.compression);

    // schedule the sampler to stop running at our max record time
    // if the sampler has already stopped, this does nothing
    imp.wakeup(30.0, stopSampler);

    // start the sampler
    server.log("Device: recording to flash");
    hardware.sampler.start();
}

function playMessage() {
    server.log("Device: playing back stored message from flash");

    // clear new message flag
    newMessage = false;

    // wake the flash, as we'll be using it now
    flash.wake();

    // load the first set of buffers before we start the dac
    loadPlayback();

    // set the playing flag
    playing = true;

    // start the dac
    server.log("Device: starting the DAC");
    hardware.fixedfrequencydac.start();

    // enable the speaker
    speakerEnable.write(1);
}

function checkBattery() {
    imp.wakeup((5*60), checkBattery);     // check every 5 minutes
    // lala rev2 requires LED to be turned on to read battery
    led.write(1);
    // lala rev1 requires mic to be enabled to read battery
    //mic.enable();
    local Vbatt = (hardware.pinA.read()/65535.0) * hardware.voltage() * (6.9/2.2);
    server.log(format("Battery Voltage %.2f V",Vbatt));
    //mic.disable();
    led.write(0);
}

/* CLASS DEFINITIONS ---------------------------------------------------------*/
class microphone {
    function enable() {
        hardware.pinC.write(1);
        // wait for the LDO to stabilize
        imp.sleep(0.05);
        server.log("Microphone Enabled");
    }

    function disable() {
        hardware.pinC.write(0);
        server.log("Microphone Disabled");
    }
}

class spiFlash {
    // MX25L3206E SPI Flash
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN     = "\x06"; // write enable
    static WRDI     = "\x04"; // write disable
    static RDID     = "\x9F"; // read identification
    static RDSR     = "\x05"; // read status register
    static READ     = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP   = "\x5A"; // read SFDP
    static RES      = "\xAB"; // read electronic ID
    static REMS     = "\x90"; // read electronic mfg & device ID
    static DREAD    = "\x3B"; // double output mode, which we don't use
    static SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE       = "\x60"; // chip erase (full device set to 0xff)
    static PP       = "\x02"; // page program 
    static RDSCUR   = "\x2B"; // read security register
    static WRSCUR   = "\x2F"; // write security register
    static ENSO     = "\xB1"; // enter secured OTP
    static EXSO     = "\xC1"; // exit secured OTP
    static DP       = "\xB9"; // deep power down
    static RDP      = "\xAB"; // release from deep power down

    // offsets for the record and playback sectors in memory
    // 64 blocks
    // first 48 blocks: playback memory
    // blocks 49 - 64: recording memory
    static totalBlocks = 64;
    static playbackBlocks = 48;
    static recordOffset = 0x2FFFD0;
    
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
    
    // spi interface
    spi = null;
    cs_l = null;

    // constructor takes in spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        this.spi = spiBus;
        this.cs_l = csPin;

        spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);
        cs_l.configure(DIGITAL_OUT);
        cs_l.write(1);

        // read the manufacturer and device ID
        cs_l.write(0);
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        cs_l.write(1);
    }
    
    function wrenable() {
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
    
    function wrdisable() {
        cs_l.write(0);
        spi.write(WRDI);
        cs_l.write(1);
    }
    
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
        
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
        
        cs_l.write(0);
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        cs_l.write(1);
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        
        return 0;
    }

    // allow data chunks greater than one flash page to be written in a single op
    function writeChunk(addr, data) {
        // separate the chunk into pages
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - data.tell();
            if (leftInBuffer < 256) {
                flash.write((addr+i),data.readblob(leftInBuffer));
            } else {
                flash.write((addr+i),data.readblob(256));
            }
        }
    }

    function read(addr, bytes) {
        cs_l.write(0);
        // to read, send the read command and a 24-bit address
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
    
    function getStatus() {
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }
    
    function sleep() {
        cs_l.write(0);
        spi.write(DP);
        cs_l.write(1);     
   }
    
    function wake() {
        cs_l.write(0);
        spi.write(RDP);
        cs_l.write(1);
    }
    
    // erase any 4kbyte sector of flash
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        this.wrenable();
        cs_l.write(0);
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        //server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        cs_l.write(0);
        spi.write(CE);
        cs_l.write(1);
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
    
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    function erasePlayBlocks() {
        server.log("Device: clearing playback flash sectors");
        for(local i = 0; i < this.playbackBlocks; i++) {
            if(this.blockErase(i*65535)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*65535));
                return 1;
            }
        }
        return 0;
    }
    
    // erase the record buffer portion of the SPI flash
    // this is a 960000-byte sector, beginning at block 46 and going to block 60
    function eraseRecBlocks() {
        server.log("Device: clearing recording flash sectors");
        for (local i = this.playbackBlocks; i < this.totalBlocks; i++) {
            if(this.blockErase(i*65535)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*65535));
                return 1;
            }
        }
        return 0;
    }
}

/* AGENT CALLBACK HOOKS ------------------------------------------------------*/
// allow the agent to signal that it's got new audio data for us, and prepare for download
agent.on("newAudio", function(parameters) {
    // turn off power save for latency
    imp.setpowersave(false);
    // set our inbound parameters to the values provided by the agent
    inParams = parameters;

    server.log(format("Device: New playback buffer in agent, len: %d bytes", inParams.dataChunkSize));
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (inParams.dataChunkSize > 2880000) {
        server.error("Device: new audio buffer length too large ("+inParams.dataChunkSize+" bytes, max 2880000 bytes)");
        return 1;
    }
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    // wake the flash in preparation for download
    flash.wake();
    flash.erasePlayBlocks();
    server.log("Device: playback flash sectors clear");
    
    // signal to the agent that we're ready to download a chunk of data
    agent.send("pull", CHUNKSIZE);
});

// when device sends "pull" request to agent for new chunk of data, agent responds with "push"
agent.on("push", function(data) {
    // agent sends a two-element table
    // data.index is the segment number of this chunk
    // data.chunk is the chunk itself
    // allows for out-of-order delivery, and helps us place chunks in flash
    local index = data.index;
    local chunk = data.chunk;
    server.log(format("Got buffer chunk %d from agent, len %d", index, chunk.len()));
    // stash this chunk away in flash, then pull another from the agent

    flash.writeChunk((index*CHUNKSIZE), chunk);
    
    // see if we're done downloading
    if ((index+1)*CHUNKSIZE >= inParams.dataChunkSize) {
        // we're done. set the global new message flag
        // this will cause the LED to blink (in the button-poll function) as well
        newMessage = true;
        // we can put the flash back to sleep now to save power
        flash.sleep();
        server.log("Device: New message downloaded to flash");
        imp.setpowersave(true);
    } else {
        // not done yet, get more data
        agent.send("pull", CHUNKSIZE);
    }
});

// when agent sends a "pull" request, we respond with a "push" and a chunk of recorded audio
agent.on("pull", function(size) {
    // make sure the flash is awake
    flash.wake();
    // read a chunk from flash
    local numChunks = (outParams.len / size) + 1;
    local chunkIndex = (recordPtr / size) + 1;
    local bytesLeft = outParams.len - recordPtr;
    if (bytesLeft < size) {
        size = bytesLeft;
    }
    local buffer = flash.read(flash.recordOffset+recordPtr, size);
    // advance the pointer for the next chunk
    recordPtr += size;
    // send the buffer up to the agent
    server.log(format("Device: sending chunk %d of %d, len %d",chunkIndex, numChunks, size));
    agent.send("push", buffer);

    // if we're done uploading, clean up
    if (recordPtr >= outParams.len - 1) {
        server.log("Device: Done with audio upload, clearing flash");
        flash.eraseRecBlocks();
        flash.sleep();
        recordPtr = 0;
        outParams.len = 0;
        imp.setpowersave(true);
        server.log("Device: ready.");
    }
});

/* BEGIN EXECUTION -----------------------------------------------------------*/
// instantiate class objects
mic <- microphone();
// flash constructor takes pre-configured spi bus and cs_l pin
flash <- spiFlash(hardware.spi189, hardware.pin7);
// in case this is software reload and not a full power-down reset, make sure the flash is awake
flash.wake();
// make sure the flash record sectors are clear so that we're ready to record as soon as the user requests
flash.eraseRecBlocks();
// flash initialized; put it to sleep to save power
flash.sleep();

// start polling the buttons
pollButtons(); // 100 ms polling interval

// check the battery voltage
checkBattery();

server.log("Device: ready.");