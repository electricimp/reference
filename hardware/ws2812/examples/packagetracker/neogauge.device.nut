// Progress Gauge WS2812 "Neopixel" LED Driver
// Copyright (C) 2014 Electric Imp, inc. 
//
// Uses SPI to emulate 1-wire
// http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding

// This class requires the use of SPI257, which must be run at 7.5MHz 
// to support neopixel timing.
const SPICLK = 7500; // kHz

// This is used for timing testing only
us <- hardware.micros.bindenv(hardware);

class NeoPixels {
    
    // This class uses SPI to emulate the newpixels' one-wire protocol. 
    // This requires one byte per bit to send data at 7.5 MHz via SPI. 
    // These consts define the "waveform" to represent a zero or one 
    ZERO            = 0xC0;
    ONE             = 0xF8;
    BYTESPERPIXEL   = 24;
    
    // when instantiated, the neopixel class will fill this array with blobs to 
    // represent the waveforms to send the numbers 0 to 255. This allows the blobs to be
    // copied in directly, instead of being built for each pixel - which makes the class faster.
    bits            = null;
    // Like bits, this blob holds the waveform to send the color [0,0,0], to clear pixels faster
    clearblob       = blob(24);
    
    // private variables passed into the constructor
    spi             = null; // imp SPI interface (pre-configured)
    frameSize       = null; // number of pixels per frame
    frame           = null; // a blob to hold the current frame

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*27 + 1);
        
        // prepare the bits array and the clearblob blob
        initialize();
        
        clearFrame();
        writeFrame();
    }
    
    // fill the array of representative 1-wire waveforms. 
    // done by the constructor at instantiation.
    function initialize() {
        // fill the bits array first
        bits = array(256);
        for (local i = 0; i < 256; i++) {
            local valblob = blob(BYTESPERPIXEL / 3);
            valblob.writen((i & 0x80) ? ONE:ZERO,'b');
            valblob.writen((i & 0x40) ? ONE:ZERO,'b');
            valblob.writen((i & 0x20) ? ONE:ZERO,'b');
            valblob.writen((i & 0x10) ? ONE:ZERO,'b');
            valblob.writen((i & 0x08) ? ONE:ZERO,'b');
            valblob.writen((i & 0x04) ? ONE:ZERO,'b');
            valblob.writen((i & 0x02) ? ONE:ZERO,'b');
            valblob.writen((i & 0x01) ? ONE:ZERO,'b');
            bits[i] = valblob;
        }
        
        // now fill the clearblob
        for(local j = 0; j < 24; j++) {
            clearblob.writen(ZERO, 'b');
        }
        // must have a null at the end to drive MOSI low
        clearblob.writen(0x00,'b');
    }

    // sets a pixel in the frame buffer
    // but does not write it to the pixel strip
    // color is an array of the form [r, g, b]
    function writePixel(p, color) {
        frame.seek(p*BYTESPERPIXEL);
        // red and green are swapped for some reason, so swizzle them back 
        frame.writeblob(bits[color[1]]);
        frame.writeblob(bits[color[0]]);
        frame.writeblob(bits[color[2]]);    
    }
    
    // Clears the frame buffer
    // but does not write it to the pixel strip
    function clearFrame() {
        frame.seek(0);
        for (local p = 0; p < frameSize; p++) frame.writeblob(clearblob);
    }
    
    // writes the frame buffer to the pixel strip
    // ie - this function changes the pixel strip
    function writeFrame() {
        spi.write(frame);
    }
}

class NeoDial extends NeoPixels {
    
    basebrightness = 16;
    gaugecolors = [
        [15, 0, 0],
        [0, 15, 0],
        [0, 0, 15],
        [8, 7, 0],
        [0, 8, 7], 
        [7, 0, 8]];
    newcoloridx = 0
    dialvalues = [];
    gauges = {}
    
    constructor(_spi, _frameSize) {
        base.constructor(_spi, _frameSize);
        dialvalues = array(_frameSize);
        clearDial();
    }
    
    function clearDial() {
        for (local i = 0; i < dialvalues.len(); i++) {
            dialvalues[i] = [0,0,0];
        }
        drawDial();
    }

    
    function newcolor() {
        local color = gaugecolors[newcoloridx++];
        if (newcoloridx >= gaugecolors.len()) {newcoloridx = 0};
        return color;
    }
    
    function drawDial(emphasisname = null, emphasisfactor = null) {
        for (local i = 0; i < dialvalues.len(); i++) {
            dialvalues[i] = [0,0,0];
        }
        clearFrame();
        // during a fade animation, emphasize one gauge over all the other markers
        foreach (gaugename, gauge in gauges) {
            local markerpixel = gauge.level * (dialvalues.len() - 1);
            if (gaugename == emphasisname) {
                for (local pixel = 0; pixel <= markerpixel; pixel++) {
                    dialvalues[pixel][0] += (gauge.color[0] * emphasisfactor);
                    dialvalues[pixel][1] += (gauge.color[1] * emphasisfactor);
                    dialvalues[pixel][2] += (gauge.color[2] * emphasisfactor);
                }
            } else {
                dialvalues[markerpixel][0] += gauge.color[0];
                dialvalues[markerpixel][1] += gauge.color[1];
                dialvalues[markerpixel][2] += gauge.color[2];
            }
        }
        
        for (local pixel = 0; pixel < dialvalues.len(); pixel++) {
            writePixel(pixel, dialvalues[pixel]);
        }
        
        writeFrame();
    }
    
    function fade(name, start, end) {
        for (local i = start; i < basebrightness; i++) {
            drawDial(name, i);
            imp.sleep(0.025);
        }
        imp.sleep(0.65);
        for (local i = basebrightness-1; i >= end; i--) {
            drawDial(name, i);
            imp.sleep(0.025);
        }
    }
    
    function setLevel(name, newlevel) {
        if (newlevel > 1) {newlevel = 1};
        if (newlevel < 0) {newlevel = 0};
        
        if (name in gauges) {
            gauges[name].level = newlevel;
        } else {
            gauges[name] <- {};
            gauges[name].color <- this.newcolor();
            gauges[name].level <- newlevel;
        }
        
        this.fade(name,0,1);
        this.drawDial();
    }
    
    function remove(name) {
        if (!(name in gauges)) { return; }
        this.fade(name,1,0);
        delete gauges[name];
    }
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("set", function(val) {
    server.log("Setting "+val.name+" to "+val.level);
    dial.setLevel(val.name, val.level);
});

agent.on("remove", function(gaugename) {
    dial.remove(gaugename);
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// The number of pixels in your chain
const NUMPIXELS = 24;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
dial <- NeoDial(spi, NUMPIXELS);

agent.send("start", 0);
