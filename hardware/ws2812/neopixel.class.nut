class NeoPixels {
    
	// Driver for the World Semi WS2812 - aka Adafruit NeoPixel
	// By Matt Haines (@beardedinventor)
	
	// See https://electricimp.com/docs/resources/neopixels/
    
	// Copyright 2014 Electric Imp
	// Issued under the MIT license (MIT)

	// Permission is hereby granted, free of charge, to any person obtaining a copy
	// of this software and associated documentation files (the "Software"), to deal
	// in the Software without restriction, including without limitation the rights
	// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	// copies of the Software, and to permit persons to whom the Software is
	// furnished to do so, subject to the following conditions:
	// 	The above copyright notice and this permission notice shall be included in
	// 	all copies or substantial portions of the Software.

	// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	// THE SOFTWARE.
	
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
		this.frame[frameSize*BYTESPERPIXEL] = 0;
        
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
