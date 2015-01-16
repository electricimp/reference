// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// WS2812 "Neopixel" LED Driver

// Uses SPI to emulate 1-wire
// http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding
// This class requires the use of SPI257, which must be run at 7.5MHz 
// to support neopixel timing.

class WS2812 {
    
    static ZERO            = 0xC0;
    static ONE             = 0xF8;
    static BYTESPERPIXEL   = 24;
    static SPICLK          = 7500; // kHz
    
    // when instantiated, the neopixel class will fill this array with blobs to 
    // represent the waveforms to send the numbers 0 to 255. This allows the blobs to be
    // copied in directly, instead of being built for each pixel - which makes the class faster.
    _bits            = null;

    // Like bits, this blob holds the waveform to send the color [0,0,0], to clear pixels faster
    _clearblob       = blob(12);
    
    // private variables passed into the constructor
    _spi             = null; // imp SPI interface (pre-configured)
    _frameSize       = null; // number of pixels per frame
    _frame           = null; // a blob to hold the current frame

    // spi - An unconfigured spi object
    // frameSize - Number of Pixels per frame
    constructor(spi, frameSize) {
        _spi = spi;
        _spi.configure(MSB_FIRST, SPICLK);

        _frameSize = frameSize;
        _frame = blob(_frameSize*BYTESPERPIXEL + 1);
        _frame[_frameSize*BYTESPERPIXEL] = 0;
        
        // prepare the bits array and the clearblob blob
        _initialize();
        
        // Blank out the pixels initially
        clearFrame();
        writeFrame();
    }
    
    /*
     * fill the array of representative 1-wire waveforms. 
     * done by the constructor at instantiation.
     */
    function _initialize() {

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
    }

    /* sets a pixel in the frame buffer
     * but does not write it to the pixel strip
     * color is an array of the form [r, g, b]
     */
    function writePixel(p, color) {
        frame.seek(p*BYTESPERPIXEL);
        // red and green are swapped for some reason, so swizzle them back 
        frame.writeblob(bits[color[1]]);
        frame.writeblob(bits[color[0]]);
        frame.writeblob(bits[color[2]]);    
    }
    
    /* Clears the frame buffer
     * but does not write it to the pixel strip
     */
    function clearFrame() {
        frame.seek(0);
        for (local p = 0; p < _frameSize; p++) frame.writeblob(clearblob);
    }
    
    /* writes the frame buffer to the pixel strip
     * ie - this function changes the pixel strip
     */
    function writeFrame() {
        spi.write(frame);
    }
}

