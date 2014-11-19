// WS2812 "Neopixel" LED Driver
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

class NeoWeather extends NeoPixels {
    
    /* control parameter for raindrop and thunder effects */
    REFRESHPERIOD       = 0.05; // normal effects refresh 20 times per second
    SLOWREFRESHPERIOD   = 0.2;  // slow effects refresh 5 times per second 
    NEWPIXELFACTOR      = 1000; // 1/100 pixels will show a new "drop" for a factor 1 effect
    LIGHTNINGFACTOR     = 5000; // factor/5000 refreshes will yield lightning
    SCALE               = 100;  // NEWPIXELFACTOR / maximum "factor" value provided to an effect
                            // this class uses factor 0-10 to set intensity
    MAXNEWDROP          = 500;  // max percent chance a new drop will occur on an empty pixel
    MAXLIGHTNING        = 10;   // max percentage chance lightning will occur on an frame
    LTBRTSCALE          = 3.1;  // amount to scale lightning brightness with intensity factor
    DIMPIXELPERCENT     = 0.8;  // percent of previous value to dim a pixel to when fading
    MAXBRIGHTNESS       = 24;   // maximum sum of channels to fade up to for ice, fog, and mist effects
    
    /* control parameters for temperature color effect */
    TEMPFACTORDIV   = 4.0;
    TEMPRANGE       = 40; // 40 degrees C of range
    TEMPMIN         = -10;
    TEMPRBOFFSET    = 10; // red and green stay out of the middle by 10 degrees each to avoid white
    
    /* default color values */
    RED         = [16,0,0];
    GREEN       = [0,16,0];
    BLUE        = [0,0,16];
    YELLOW      = [8,8,0];
    CYAN        = [0,8,8];
    MAGENTA     = [8,0,8];
    ORANGE      = [16,8,0];
    WHITE       = [8,8,8];
    
    // an array of [r,g,b] arrays to describe the next frame to be displayed
    pixelvalues = [];
    wakehandle = 0; // keep track of the next imp.wakeup handle, so we can cancel if changing effects
    
    constructor(_spi, _frameSize) {
        base.constructor(_spi, _frameSize);
        pixelvalues = [];
        for (local x = 0; x < _frameSize; x++) { pixelvalues.push([0,0,0]); }
    }

    /* Stop all effects from displaying and blank out all the pixels.
     * Input: (none)
     * Return: (none)
     */
    function stop() {
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
        dialvalues = array(_frameSize, [0,0,0]);
        clearFrame();
        writeFrame();
    }
    
    /* Blue and Purple fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function rain(factor) {
        local NUMCOLORS = 2;
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rain(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0:
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = BLUE[channel];
                            }
                            break;
                        default: 
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function snow(factor) {
        local NUMCOLORS = 1;
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {snow(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    for (local channel = 0; channel < 3; channel++) {
                        pixelvalues[pixel][channel] = WHITE[channel];
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Blue and White fading dots effect.
     * Factor is 1 to 10 and scales the number of new raindrops per refresh.
     */
    function hail(factor) {
        local NUMCOLORS = 3; // colors used in this effect
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {hail(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        local next = false;
        clearFrame();
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            // if there's any color data in this pixel, fade it down 
            next = false;
            if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
            if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
            // skip random number generation if we just dimmed
            if (!next) {
                newdrop = math.rand() % NEWPIXELFACTOR;
                if (newdrop <= threshold) {
                    switch (newdrop % NUMCOLORS) {
                        case 0: 
                            //server.log("cyan");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = CYAN[channel];
                            }
                            break;
                        case 1: 
                            //server.log("magenta");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = MAGENTA[channel];
                            }
                            break;
                        default: 
                            //server.log("white");
                            for (local channel = 0; channel < 3; channel++) {
                                pixelvalues[pixel][channel] = WHITE[channel];
                            }
                            break;
                    }
                }
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Blue and Purple fading dots effect with yellow "lightning strikes".
     * Factor is 0 to 10 and scales the number of new raindrops per refresh, 
     * as well as frequency of lightning.
     */
    function thunder(factor) {
        local NUMCOLORS = 2;
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
 
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {thunder(factor)}.bindenv(this));
        
        local newdrop = 0;
        local threshold = (factor * SCALE);
        if (threshold < NUMCOLORS) { threshold = NUMCOLORS; }
        if (threshold > MAXNEWDROP) { threshold = MAXNEWDROP; }
        //server.log(threshold);
        
        local lightningthreshold = factor;
        if (lightningthreshold > MAXLIGHTNING) { threshold = MAXLIGHTNING; }
        
        local lightningcheck = math.rand() % LIGHTNINGFACTOR;
        local next = false;
        clearFrame();
        if (lightningcheck <= lightningthreshold) {
            local lightningbrightness = math.floor(factor * LTBRTSCALE);
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                for (local channel = 0; channel < 3; channel++) {
                    pixelvalues[pixel][channel] = lightningbrightness * YELLOW[channel];
                }
            }
        } else {
            for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
                //server.log(pixel);
                // if there's any color data in this pixel, fade it down 
                next = false;
                if (pixelvalues[pixel][0]) { pixelvalues[pixel][0] = math.floor(pixelvalues[pixel][0] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][1]) { pixelvalues[pixel][1] = math.floor(pixelvalues[pixel][1] * DIMPIXELPERCENT); next = true;}
                if (pixelvalues[pixel][2]) { pixelvalues[pixel][2] = math.floor(pixelvalues[pixel][2] * DIMPIXELPERCENT); next = true;}
                // skip random number generation if we just dimmed
                if (!next) {
                    newdrop = math.rand() % NEWPIXELFACTOR;
                    if (newdrop <= threshold) {
                        switch (newdrop % NUMCOLORS) {
                            case 0:
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = BLUE[channel];
                                }
                                break;
                            default: 
                                for (local channel = 0; channel < 3; channel++) {
                                    pixelvalues[pixel][channel] = MAGENTA[channel];
                                }
                                break;
                        }
                    }
                }
                writePixel(pixel, pixelvalues[pixel]);
            }
        }
        writeFrame();
    }
    
    /* Rotate pixelvalues array
     * this is used to animate the ice, mist, and fog effects. */
    function rotate_gradient() {
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rotate_gradient()}.bindenv(this));
        
        // wrap around the end of the array
        for (local ch = 0; ch < 3; ch++) {
            pixelvalues[frameSize - 1][ch] = pixelvalues[0][ch];
        }
        writePixel(frameSize - 1, pixelvalues[frameSize - 1]);
        
        //shift each pixel over by one
        for (local pixel = 0; pixel < (frameSize - 1); pixel++) {
            for (local ch = 0; ch < 3; ch++) {
                pixelvalues[pixel][ch] = pixelvalues[pixel + 1][ch]; 
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Blue / white gradient circles the display
     * No input parameters
     */
    function ice() {
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
        
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rotate_gradient()}.bindenv(this));
        
        local opposite = frameSize / 2;
        local step = (1.0 * WHITE[0]) / ((1.0 * opposite));
        
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            if (pixel < opposite) {
                pixelvalues[pixel][0] = math.floor((opposite - pixel) * step);
                pixelvalues[pixel][1] = math.floor((opposite - pixel) * step);
                pixelvalues[pixel][2] = math.floor(((opposite - pixel) * step) + (pixel * step));
            } else {
                pixelvalues[pixel][0] = math.floor((pixel - opposite) * step);
                pixelvalues[pixel][1] = math.floor((pixel - opposite) * step);
                pixelvalues[pixel][2] = math.floor(((pixel - opposite) * step) + (frameSize - pixel) * step);
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Cyan / white gradient circles the display
     * No input parameters
     */
    function mist() {
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
        
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rotate_gradient()}.bindenv(this));
        
        local opposite = frameSize / 2;
        local step = (1.0 * WHITE[0]) / ((1.0 * opposite));
        
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            if (pixel < opposite) {
                pixelvalues[pixel][0] = math.floor((opposite - pixel) * step);
                pixelvalues[pixel][1] = math.floor(((opposite - pixel) * step) + (pixel * step));
                pixelvalues[pixel][2] = math.floor(((opposite - pixel) * step) + (pixel * step));
            } else {
                pixelvalues[pixel][0] = math.floor((pixel - opposite) * step);
                pixelvalues[pixel][1] = math.floor(((pixel - opposite) * step) + (frameSize - pixel) * step);
                pixelvalues[pixel][2] = math.floor(((pixel - opposite) * step) + (frameSize - pixel) * step);
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* White gradient circles the display
     * No input parameters
     */
    function fog() {
        local baseval = 4;
        
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
        
        // schedule refresh
        wakehandle = imp.wakeup((REFRESHPERIOD), function() {rotate_gradient()}.bindenv(this));
        
        local opposite = frameSize / 2;
        local step = (2.0 * WHITE[0]) / ((1.0 * opposite));
        server.log(step);
        
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            if (pixel < opposite) {
                pixelvalues[pixel][0] = math.floor((opposite - pixel) * step) + baseval;
                pixelvalues[pixel][1] = math.floor((opposite - pixel) * step) + baseval;
                pixelvalues[pixel][2] = math.floor((opposite - pixel) * step) + baseval;
            } else {
                pixelvalues[pixel][0] = math.floor((pixel - opposite) * step) + baseval;
                pixelvalues[pixel][1] = math.floor((pixel - opposite) * step) + baseval;
                pixelvalues[pixel][2] = math.floor((pixel - opposite) * step) + baseval;
            }
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
    
    /* Set the color based on the temperature, and the brightness based on the 
     * factor. Temperature range is -10 to 30 C, where -10 is all-blue, and 
     * 30 is all-red. */
    function temp(val, factor) {
        // cancel any previous effect currently running
        if (wakehandle) { imp.cancelwakeup(wakehandle); }
        
        factor = factor / TEMPFACTORDIV;
        
        // min temp is -10 C (full-on blue)
        // max temp is 30 C (full-on red)
        // scale temp up by 10 so we're dealing only with positive numbers
        if (TEMPMIN < 0) { val += (-1 * TEMPMIN); } 
        if (val < 0) { val = 0; }
        if (val > TEMPRANGE) { val = TEMPRANGE; } 
        
        // scale red proportionally to temp, from -10 to 20 C
        local r_scale = (RED[0] * 1.0) / (TEMPRANGE - TEMPRBOFFSET);
        local r = (factor * r_scale * (val - TEMPRBOFFSET));
        if (val < TEMPRBOFFSET) { r = 0 }
        
        // scale green proportionally to temp from 0 to 10, inversely to temp from 10 to 20
        local g_range = (TEMPRANGE - (2 * TEMPRBOFFSET)) / 2; // green shifts over a 10-degree range
        local g_max = (2 * TEMPRBOFFSET);               // green max occurs at val = 20 (10 degrees)
        local g_scale = 2 * ((GREEN[1] * 1.0) / g_range);
        local g = 0;
        if ((val < TEMPRBOFFSET) || (val > (TEMPRANGE - TEMPRBOFFSET))) { g = 0; } 
        else {
            g = factor * g_scale * (g_range - math.abs(g_max - val));
        }
        
        // scale blue inverse to temp, from -10 to 20 C
        local b_scale = (BLUE[2] * 1.0) / (TEMPRANGE - TEMPRBOFFSET);
        local b = (factor * b_scale * ((TEMPRANGE - TEMPRBOFFSET) - val));
        if (val > (TEMPRANGE - TEMPRBOFFSET)) { b = 0; }
        
        for (local pixel = 0; pixel < pixelvalues.len(); pixel++) {
            pixelvalues[pixel][0] = r;
            pixelvalues[pixel][1] = g;
            pixelvalues[pixel][2] = b;
            writePixel(pixel, pixelvalues[pixel]);
        }
        writeFrame();
    }
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("seteffect", function(val) {
    local cond = null;
    local temp = null;
    
    server.log("Got new conditions from agent: "+val);
    
    try {
        cond = val.conditions;
        temp = val.temperature;
    } catch (err) {
        server.error("Invalid Request from Agent: "+err);
        return;
    }
    
    if (cond.find("Thunderstorm") != null){
        if (cond.find("Light") != null) {
            display.thunder(0);
        } else if (cond.find("Heavy") != null) {
            display.thunder(4);
        } else {
            display.thunder(2);
        }
    } else if (cond.find("Hail") != null) {
        if (cond.find("Light") != null) {
            display.hail(0);
        } else if (cond.find("Heavy") != null) {
            display.hail(4);
        } else {
            display.hail(2);
        }
    } else if (cond.find("Drizzle") != null){
        if (cond.find("Light") != null) {
            display.rain(0);
        } else if (cond.find("Heavy") != null) {
            display.rain(2);
        } else {
            display.rain(1);
        }
    } else if (cond.find("Rain") != null) {
        if (cond.find("Light") != null) {
            display.rain(3);
        } else if (cond.find("Heavy") != null) {
            display.rain(5);
        } else {
            display.rain(4);
        }
    } else if (cond.find("Snow") != null) {
        if (cond.find("Light") != null) {
            display.snow(2);
        } else if (cond.find("Heavy") != null) {
            display.snow(8);
        } else {
            display.snow(4);
        }
    } else if (cond.find("Ice") != null) {
        display.ice();
    } else if ((cond.find("Fog") != null)|| (cond.find("Haze") != null) || (cond.find("Dust") != null) || (cond.find("Sand") != null) || (cond.find("Smoke") != null) || (cond.find("Ash") != null)) {
        display.fog();
    } else if ((cond.find("Mist") != null) || (cond.find("Spray") != null)) {
        display.mist();
    } else if (cond.find("Clear") != null) {
        display.temp(temp, 3);    
    } else if (cond.find("Cloud") != null) {
        display.temp(temp, 2);    
    } else if (cond.find("Overcast") != null) {
        display.temp(temp, 1);    
    } else {
        display.temp(temp, 1);
    }
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// The number of pixels in your chain
const NUMPIXELS = 24;

spi <- hardware.spi257;
spi.configure(MSB_FIRST, SPICLK);
display <- NeoWeather(spi, NUMPIXELS);

server.log("Ready, running impOS "+imp.getsoftwareversion());

//let the agent know we've just booted, which will trigger a weather update.
agent.send("start", 0);
