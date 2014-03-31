// WS2812 "Neopixel" LED Driver
// Copyright (C) 2014 Electric Imp, inc.
//
// Uses SPI to emulate 1-wire
// http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding


// This class requires the use of SPI257, which must be run at 7.5MHz 
// to support neopixel timing.
const SPICLK = 3750; // kHz

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
    clearblob       = blob(12);
    
    // private variables passed into the constructor
    spi             = null; // imp SPI interface (pre-configured)
    frameSize       = null; // number of pixels per frame
    frame           = null; // a blob to hold the current frame

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*BYTESPERPIXEL + 1);
        
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
        for(local j = 0; j < BYTESPERPIXEL; j++) {
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

/* RUNTIME STARTS HERE -------------------------------------------------------*/

const NUMPIXELS = 24;
const DELAY = 0.025;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
pixelStrip <- NeoPixels(spi, NUMPIXELS);

pixels <- [0,0,0,0,0]
currentPixel <- 0;
pAdd <- 1;

function test(d = null) { 
  pixelStrip.writePixel(pixels[0],[0,0,0]);
  for(local i = 1; i < 5; i++) {
      local b = math.pow(2, i);
      pixelStrip.writePixel(pixels[i], [ b, b / 2, b * 1.5 ]);
  }
  
  pixelStrip.writeFrame();
  if (currentPixel >= NUMPIXELS-1) pAdd = -1;
  if (currentPixel <= 0) pAdd = 1;
  currentPixel += pAdd;
  
  for (local i = 0; i < 4; i++) pixels[i] = pixels[i+1];
  pixels[4] = currentPixel;
  
  imp.wakeup(DELAY, test);
} 

test();
