/*
Copyright (C) 2013 Electric Imp, Inc.

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

// Sleep duration in seconds
// DISABLED BY DEFAULT - uncomment the last line to sleep
const SLEEP_DURATION = 300;
const BACKLIGHT_DURATION = 10;

// -----------------------------------------------------------------------------
function char_to_bin(c) {
    switch (c) {
      case ' ':  return "\x00\x00";                  // SP ----- -O--- OO-OO ----- -O--- OO--O -O--- -O---
      case '!':  return "\xfa";                      // !  ----- -O--- OO-OO -O-O- -OOO- OO--O O-O-- -O---
      case '"':  return "\xe0\xc0\x00\xe0\xc0";      // "  ----- -O--- O--O- OOOOO O---- ---O- O-O-- -----
      case '#':  return "\x24\x7e\x24\x7e\x24";      // #  ----- -O--- ----- -O-O- -OO-- --O-- -O--- -----
      case '$':  return "\x24\xd4\x56\x48";          // $  ----- -O--- ----- -O-O- ---O- -O--- O-O-O -----
      case '%':  return "\xc6\xc8\x10\x26\xc6";      // %  ----- ----- ----- OOOOO OOO-- O--OO O--O- -----
      case '&':  return "\x6c\x92\x6a\x04\x0a";      // &  ----- -O--- ----- -O-O- --O-- O--OO -OO-O -----
      case '\'': return "\xc0";                      // '  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case '(':  return "\x7c\x82";                  // (  ---O- -O--- ----- ----- ----- ----- ----- -----
      case ')':  return "\x82\x7c";                  // )  --O-- --O-- -O-O- --O-- ----- ----- ----- ----O
      case '*':  return "\x10\x7c\x38\x7c\x10";      // *  --O-- --O-- -OOO- --O-- ----- ----- ----- ---O-
      case '+':  return "\x10\x10\x7c\x10\x10";      // +  --O-- --O-- OOOOO OOOOO ----- OOOOO ----- --O--
      case ',':  return "\x06\x07";                  // ,  --O-- --O-- -OOO- --O-- ----- ----- ----- -O---
      case '-':  return "\x10\x10\x10\x10\x10";      // -  --O-- --O-- -O-O- --O-- -OO-- ----- -OO-- O----
      case '.':  return "\x06\x06";                  // .  ---O- -O--- ----- ----- -OO-- ----- -OO-- -----
      case '/':  return "\x04\x08\x10\x20\x40";      // /  ----- ----- ----- ----- --O-- ----- ----- -----
    //
      case '0':  return "\x7c\x8a\x92\xa2\x7c";      // 0  -OOO- --O-- -OOO- -OOO- ---O- OOOOO --OOO OOOOO
      case '1':  return "\x42\xfe\x02";              // 1  O---O -OO-- O---O O---O --OO- O---- -O--- ----O
      case '2':  return "\x46\x8a\x92\x92\x62";      // 2  O--OO --O-- ----O ----O -O-O- O---- O---- ---O-
      case '3':  return "\x44\x92\x92\x92\x6c";      // 3  O-O-O --O-- --OO- -OOO- O--O- OOOO- OOOO- --O--
      case '4':  return "\x18\x28\x48\xfe\x08";      // 4  OO--O --O-- -O--- ----O OOOOO ----O O---O -O---
      case '5':  return "\xf4\x92\x92\x92\x8c";      // 5  O---O --O-- O---- O---O ---O- O---O O---O -O---
      case '6':  return "\x3c\x52\x92\x92\x8c";      // 6  -OOO- -OOO- OOOOO -OOO- ---O- -OOO- -OOO- -O---
      case '7':  return "\x80\x8e\x90\xa0\xc0";      // 7  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case '8':  return "\x6c\x92\x92\x92\x6c";      // 8  -OOO- -OOO- ----- ----- ---O- ----- -O--- -OOO-
      case '9':  return "\x60\x92\x92\x94\x78";      // 9  O---O O---O ----- ----- --O-- ----- --O-- O---O
      case ':':  return "\x36\x36";                  // :  O---O O---O -OO-- -OO-- -O--- OOOOO ---O- O---O
      case ';':  return "\x36\x37";                  // ;  -OOO- -OOOO -OO-- -OO-- O---- ----- ----O --OO-
      case '<':  return "\x10\x28\x44\x82";          // <  O---O ----O ----- ----- -O--- ----- ---O- --O--
      case '=':  return "\x24\x24\x24\x24\x24";      // =  O---O ---O- -OO-- -OO-- --O-- OOOOO --O-- -----
      case '>':  return "\x82\x44\x28\x10";          // >  -OOO- -OO-- -OO-- -OO-- ---O- ----- -O--- --O--
      case '?':  return "\x60\x80\x9a\x90\x60";      // ?  ----- ----- ----- --O-- ----- ----- ----- -----
    //
      case '@':  return "\x7c\x82\xba\xaa\x78";      // @  -OOO- -OOO- OOOO- -OOO- OOOO- OOOOO OOOOO -OOO-
      case 'A':  return "\x7e\x90\x90\x90\x7e";      // A  O---O O---O O---O O---O O---O O---- O---- O---O
      case 'B':  return "\xfe\x92\x92\x92\x6c";      // B  O-OOO O---O O---O O---- O---O O---- O---- O----
      case 'C':  return "\x7c\x82\x82\x82\x44";      // C  O-O-O OOOOO OOOO- O---- O---O OOOO- OOOO- O-OOO
      case 'D':  return "\xfe\x82\x82\x82\x7c";      // D  O-OOO O---O O---O O---- O---O O---- O---- O---O
      case 'E':  return "\xfe\x92\x92\x92\x82";      // E  O---- O---O O---O O---O O---O O---- O---- O---O
      case 'F':  return "\xfe\x90\x90\x90\x80";      // F  -OOO- O---O OOOO- -OOO- OOOO  OOOOO O---- -OOO-
      case 'G':  return "\x7c\x82\x92\x92\x5c";      // G  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case 'H':  return "\xfe\x10\x10\x10\xfe";      // H  O---O -OOO- ----O O---O O---- O---O O---O -OOO-
      case 'I':  return "\x82\xfe\x82";              // I  O---O --O-- ----O O--O- O---- OO-OO OO--O O---O
      case 'J':  return "\x0c\x02\x02\x02\xfc";      // J  O---O --O-- ----O O-O-- O---- O-O-O O-O-O O---O
      case 'K':  return "\xfe\x10\x28\x44\x82";      // K  OOOOO --O-- ----O OO--- O---- O---O O--OO O---O
      case 'L':  return "\xfe\x02\x02\x02\x02";      // L  O---O --O-- O---O O-O-- O---- O---O O---O O---O
      case 'M':  return "\xfe\x40\x20\x40\xfe";      // M  O---O --O-- O---O O--O- O---- O---O O---O O---O
      case 'N':  return "\xfe\x40\x20\x10\xfe";      // N  O---O -OOO- -OOO- O---O OOOOO O---O O---O -OOO-
      case 'O':  return "\x7c\x82\x82\x82\x7c";      // O  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case 'P':  return "\xfe\x90\x90\x90\x60";      // P  OOOO- -OOO- OOOO- -OOO- OOOOO O---O O---O O---O
      case 'Q':  return "\x7c\x82\x92\x8c\x7a";      // Q  O---O O---O O---O O---O --O-- O---O O---O O---O
      case 'R':  return "\xfe\x90\x90\x98\x66";      // R  O---O O---O O---O O---- --O-- O---O O---O O-O-O
      case 'S':  return "\x64\x92\x92\x92\x4c";      // S  OOOO- O-O-O OOOO- -OOO- --O-- O---O O---O O-O-O
      case 'T':  return "\x80\x80\xfe\x80\x80";      // T  O---- O--OO O--O- ----O --O-- O---O O---O O-O-O
      case 'U':  return "\xfc\x02\x02\x02\xfc";      // U  O---- O--O- O---O O---O --O-- O---O -O-O- O-O-O
      case 'V':  return "\xf8\x04\x02\x04\xf8";      // V  O---- -OO-O O---O -OOO- --O-- -OOO- --O-- -O-O-
      case 'W':  return "\xfc\x02\x3c\x02\xfc";      // W  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case 'X':  return "\xc6\x28\x10\x28\xc6";      // O  O---O O---O OOOOO -OOO- ----- -OOO- --O-- -----
      case 'Y':  return "\xe0\x10\x0e\x10\xe0";      // Y  O---O O---O ----O -O--- O---- ---O- -O-O- -----
      case 'Z':  return "\x86\x8a\x92\xa2\xc2";      // Z  -O-O- O---O ---O- -O--- -O--- ---O- O---O -----
      case '[':  return "\xfe\x82\x82";              // [  --O-- -O-O- --O-- -O--- --O-- ---O- ----- -----
      case '\\': return "\x40\x20\x10\x08\x04";      // \  -O-O- --O-- -O--- -O--- ---O- ---O- ----- -----
      case ']':  return "\x82\x82\xfe";              // ]  O---O --O-- O---- -O--- ----O ---O- ----- -----
      case '^':  return "\x20\x40\x80\x40\x20";      // ^  O---O --O-- OOOOO -OOO- ----- -OOO- ----- OOOOO
      case '_':  return "\x02\x02\x02\x02\x02";      // _  ----- ----- ----- ----- ----- ----- ----- -----
    //
      case '`':  return "\xc0\xe0";                  // `  -OO-- ----- O---- ----- ----O ----- --OOO -----
      case 'a':  return "\x04\x2a\x2a\x2a\x1e";      // a  -OO-- ----- O---- ----- ----O ----- -O--- -----
      case 'b':  return "\xfe\x22\x22\x22\x1c";      // b  --O-- -OOO- OOOO- -OOO- -OOOO -OOO- -O--- -OOOO
      case 'c':  return "\x1c\x22\x22\x22";          // c  ----- ----O O---O O---- O---O O---O OOOO- O---O
      case 'd':  return "\x1c\x22\x22\x22\xfc";      // d  ----- -OOOO O---O O---- O---O OOOO- -O--- O---O
      case 'e':  return "\x1c\x2a\x2a\x2a\x10";      // e  ----- O---O O---O O---- O---O O---- -O--- -OOOO
      case 'f':  return "\x10\x7e\x90\x90\x80";      // f  ----- -OOOO OOOO- -OOO- -OOOO -OOO- -O--- ----O
      case 'g':  return "\x18\x25\x25\x25\x3e";      // g  ----- ----- ----- ----- ----- ----- ----- -OOO-
    //
      case 'h':  return "\xfe\x20\x20\x20\x1e";      // h  O---- -O--- ----O O---- O---- ----- ----- -----
      case 'i':  return "\xbe\x02";                  // i  O---- ----- ----- O---- O---- ----- ----- -----
      case 'j':  return "\x02\x01\x01\x21\xbe";      // j  OOOO- -O--- ---OO O--O- O---- OO-O- OOOO- -OOO-
      case 'k':  return "\xfe\x08\x14\x22";          // k  O---O -O--- ----O O-O-- O---- O-O-O O---O O---O
      case 'l':  return "\xfe\x02";                  // l  O---O -O--- ----O OO--- O---- O-O-O O---O O---O
      case 'm':  return "\x3e\x20\x18\x20\x1e";      // m  O---O -O--- ----O O-O-- O---- O---O O---O O---O
      case 'n':  return "\x3e\x20\x20\x20\x1e";      // n  O---O -OO-- O---O O--O- OO--- O---O O---O -OOO-
      case 'o':  return "\x1c\x22\x22\x22\x1c";      // o  ----- ----- -OOO- ----- ----- ----- ----- -----
    //
      case 'p':  return "\x3f\x22\x22\x22\x1c";      // p  ----- ----- ----- ----- ----- ----- ----- -----
      case 'q':  return "\x1c\x22\x22\x22\x3f";      // q  ----- ----- ----- ----- -O--- ----- ----- -----
      case 'r':  return "\x22\x1e\x22\x20\x10";      // r  OOOO- -OOOO O-OO- -OOO- OOOO- O--O- O---O O---O
      case 's':  return "\x12\x2a\x2a\x2a\x04";      // s  O---O O---O -O--O O---- -O--- O--O- O---O O---O
      case 't':  return "\x20\x7c\x22\x22\x04";      // t  O---O O---O -O--- -OOO- -O--- O--O- O---O O-O-O
      case 'u':  return "\x3c\x02\x02\x3e";          // u  O---O O---O -O--- ----O -O--O O--O- -O-O- OOOOO
      case 'v':  return "\x38\x04\x02\x04\x38";      // v  OOOO- -OOOO OOO-- OOOO- --OO- -OOO- --O-- -O-O-
      case 'w':  return "\x3c\x06\x0c\x06\x3c";      // w  O---- ----O ----- ----- ----- ----- ----- -----
    //
      case 'x':  return "\x22\x14\x08\x14\x22";      // x  ----- ----- ----- ---OO --O-- OO--- -O-O- -OO--
      case 'y':  return "\x39\x05\x06\x3c";          // y  ----- ----- ----- --O-- --O-- --O-- O-O-- O--O-
      case 'z':  return "\x26\x2a\x2a\x32";          // z  O---O O--O- OOOO- --O-- --O-- --O-- ----- O--O-
      case '{':  return "\x10\x7c\x82\x82";          // {  -O-O- O--O- ---O- -OO-- ----- --OO- ----- -OO--
      case '|':  return "\xee";                      // |  --O-- O--O- -OO-- --O-- --O-- --O-- ----- -----
      case '}':  return "\x82\x82\x7c\x10";          // }  -O-O- -OOO- O---- --O-- --O-- --O-- ----- -----
      case '~':  return "\x40\x80\x40\x80";          // ~  O---O --O-- OOOO- ---OO --O-- OO--- ----- -----
      case '_':  return "\x60\x90\x90\x60";          // _  ----- OO--- ----- ----- ----- ----- ----- -----
    //
      case '\t': return "\x00\x00\x00\x00\x00\x00\x00\x00";      // Tab
      case '\n': return "\x24\x6E\xFE\xEF\x07\x07\x0E\x0E\x04";  // Duck
      default:   return "\x00\x00\x00\x00\x00";                  // Blank    
    }
}

// Flips a bitmap top-to-bottom / left-to-right.
const reverse_map = "\x00\x80\x40\xc0\x20\xa0\x60\xe0\x10\x90\x50\xd0\x30\xb0\x70\xf0\x08\x88\x48\xc8\x28\xa8\x68\xe8\x18\x98\x58\xd8\x38\xb8\x78\xf8\x04\x84\x44\xc4\x24\xa4\x64\xe4\x14\x94\x54\xd4\x34\xb4\x74\xf4\x0c\x8c\x4c\xcc\x2c\xac\x6c\xec\x1c\x9c\x5c\xdc\x3c\xbc\x7c\xfc\x02\x82\x42\xc2\x22\xa2\x62\xe2\x12\x92\x52\xd2\x32\xb2\x72\xf2\x0a\x8a\x4a\xca\x2a\xaa\x6a\xea\x1a\x9a\x5a\xda\x3a\xba\x7a\xfa\x06\x86\x46\xc6\x26\xa6\x66\xe6\x16\x96\x56\xd6\x36\xb6\x76\xf6\x0e\x8e\x4e\xce\x2e\xae\x6e\xee\x1e\x9e\x5e\xde\x3e\xbe\x7e\xfe\x01\x81\x41\xc1\x21\xa1\x61\xe1\x11\x91\x51\xd1\x31\xb1\x71\xf1\x09\x89\x49\xc9\x29\xa9\x69\xe9\x19\x99\x59\xd9\x39\xb9\x79\xf9\x05\x85\x45\xc5\x25\xa5\x65\xe5\x15\x95\x55\xd5\x35\xb5\x75\xf5\x0d\x8d\x4d\xcd\x2d\xad\x6d\xed\x1d\x9d\x5d\xdd\x3d\xbd\x7d\xfd\x03\x83\x43\xc3\x23\xa3\x63\xe3\x13\x93\x53\xd3\x33\xb3\x73\xf3\x0b\x8b\x4b\xcb\x2b\xab\x6b\xeb\x1b\x9b\x5b\xdb\x3b\xbb\x7b\xfb\x07\x87\x47\xc7\x27\xa7\x67\xe7\x17\x97\x57\xd7\x37\xb7\x77\xf7\x0f\x8f\x4f\xcf\x2f\xaf\x6f\xef\x1f\x9f\x5f\xdf\x3f\xbf\x7f\xff";
function reverse(x)
{
        return reverse_map[x];
}

class PCD8544_LCD {
    // PCD8544-driven monochrome LCD class
    // Tested on the "Nokia 5110" LCD screen from adafruit:
    // http://www.adafruit.com/products/338
    
    // Causes backlight to fade out after a brief delay and enables WiFi powersave mode
    // Set to 1 for battery power, 0 otherwise
    static BATTERY_POWER = 1;

    // Configuration string: Extended instruction mode, Operating voltage (contrast),
    // temperature coefficient, bias voltage, normal instruction mode, normal display mode

    // Good values for op voltage (second byte) are around 0xB0. Go higher if the image is washed out, lower if too dark
    static DEFAULT_CONFIG = "\x21\xB6\x04\x13\x20\x0C";
    
    static SPACE_WIDTH = 3;
    
    brightness = 0.0;      // Start with backlight off
    byteCount = null;     // width * height / 8
    
    width = null;
    height = null;
    
    // Pin aliases
    spi = null;
    lite = null;
    rst = null;
    dc = null;
    cs = null;
    
    // Constructor
    constructor(screenWidth, screenHeight, spiBus, litePin, rstPin, dcPin, csPin) {
        width = screenWidth;
        height = screenHeight;
        byteCount = width * height / 8;
        spi = spiBus;
        lite = litePin;
        rst = rstPin;
        dc = dcPin;
        cs = csPin;
        
        // Pin configuration
        spi.configure(SIMPLEX_TX | MSB_FIRST | CLOCK_IDLE_LOW, 4000);
        dc.configure(DIGITAL_OUT); // High for data, low for command
        dc.write(0);
        cs.configure(DIGITAL_OUT); // Chip Select (active-low)
        cs.write(1);
    }
    
    // Send a command string
    function command(c) {
        dc.write(0);   // data/command line set to command
        cs.write(0);    // Select PCD8544
        spi.write(c);   // write the command string
        cs.write(1);    // Deselect PCD8544
        dc.write(1);   // data/command line set back to data
    }
    
    // Write data followed by a NOP (required for the last byte to display properly)
    function write(data) {
        cs.write(0);    // Select PCD8544
        spi.write(data);
        cs.write(1);    // Deselect PCD8544
        command("\x00");    // NOP
    }
    
    // Clear screen by writing a blob of zeros
    function clearScreen() {
        command("\x80\x40"); // Reset X and Y addresses to 0
        local clr = blob(byteCount);
        cs.write(0);    // Select PCD8544
        spi.write(clr);
        cs.write(1);    // Deselect PCD8544
        command("\x00");    // NOP
    }
    
    // Send a 10ms reset pulse
    function reset() {
        rst.configure(DIGITAL_OUT_OD);
        rst.write(0);
        imp.sleep(0.01);
        rst.write(1);
        server.log("LCD reset.")
    }
    
    // Turn on the backlight, with brightness and duration specified
    // If duration is 0 (or negative) then leave backlight on
    function backlight(newbrightness, duration) {
        brightness = newbrightness;
        if (brightness) {
                lite.configure(PWM_OUT, 0.002, brightness);
        }
        else {
            backlightOff();
        }
        if (duration > 0 && BATTERY_POWER) {
            imp.wakeup(duration, backlightFadeOut.bindenv(this));        
        }
    }
    
    // Flash the backlight (e.g. to notify a new message has arrived)
    function backlightFlash() {
        lite.configure(PWM_OUT, 0.002, 0.0);
        for (local i = 0; i < 2; i++) {
            lite.write(1.0);
            imp.sleep(0.1);
            lite.write(0.0);
            imp.sleep(0.1);
        }
    }
    
    // Turn off the backlight by changing pin type to DIGITAL_OUT and writing low.
    // This method uses 6-8mA less than setting a 0% PWM duty cycle!
    function backlightOff() {
        brightness = 0.0;
        lite.configure(DIGITAL_OUT);
        lite.write(0);
    }
    
    // Fade out the backlight. This takes a bit more power.
    function backlightFadeOut() {
        local step = brightness / 100;
        for (local i = 0; i < 100; i++) {
            brightness = brightness - step;
            lite.write(brightness);
            imp.sleep(0.01);
        }
        backlightOff(); // Put the backlight into low power mode
    }

    // Turn all pixels on, run through some patterns to make sure everything works
    function test() {
        backlight(1.0, 0);
        server.log("Test mode.");
        command("\x08");  // Display blank
        imp.sleep(0.2);
        command("\x09");  // All display segments on
        imp.sleep(0.2);    
        command("\x0D");  // Inverse display mode
        imp.sleep(0.2);
        clearScreen();
        cs.write(0);    // Select PCD8544
        for (local i = 0; i < 127; i+=1) {  // Write a bunch of vertical lines
            write("\x00\x00\x00\xFF");
        }
        cs.write(1);    // Deselect PCD8544
        imp.sleep(0.2);
        command("\x0C");  // Normal display mode
        imp.sleep(0.2);
        scan();
        backlightOff();
    }

    // Scan through each pixel in the default addressing order
    function scan() {
        clearScreen();
        command("\x80\x40"); // Set X/Y addresses to zero
        cs.write(0);    // Select PCD8544
        for (local i = 0; i < 504; i++) {
            write("\xFF");
            imp.sleep(0.003);
        }
        cs.write(1);    // Deselect PCD8544
        command("\x00");    // NOP
        clearScreen();
    }
    
    // Handler for loading preformatted bytes from the agent
    function displayFrame(updateRequest) {
        server.log("Receiving data!");
        updateRequest.data.resize(byteCount);    // Make sure the blob is the right size
        write(updateRequest.data);               // Write the data to the screen
        if (updateRequest.isFresh) {             // If the data is fresh, flash the backlight
            backlightFlash();
            backlight(0.5, BACKLIGHT_DURATION);  // 50% brightness for BACKLIGHT_DURATION seconds
        }
    }
    
    function displayText(textString) {
        local currentWord = blob(); // Build each word into a blob
        local wordArray = [];       // Store those blobs in a word array
        local lineArray = [];       // Then copy them to a line array
        server.log("Displaying new text: " + textString);
        // Iterate through the input string and place each word into an array
        // If the word is longer than the line, split it up into multiple words so it wraps well
        foreach(charIndex, character in textString) {
            local charBytes = char_to_bin(character);
            // If we hit a space, start a new word
            if (character == ' ') {
                wordArray.append(currentWord);      // Add the current word to the array
                currentWord = blob();               // and reset the current word
            }
            else {
                // If we run out of room, start a new word
                if (charBytes.len() + currentWord.len() >= width) {
                    wordArray.append(currentWord);      // Add the current word to the array
                    currentWord = blob();               // and reset the current word  
                }
                local currentChar = blob();         // Start building a character
                if (currentWord.len() > 0) {        // If this isn't the first char, add a small gap for kerning
                    currentChar.writen('\x00', 'b');
                }
                // Build the character from the included font
                foreach(byte in charBytes) {
                    currentChar.writen(reverse(byte & 0xFF), 'b');
                }
                currentWord.writeblob(currentChar);     // Add the current character to the current word
            }
        }
        wordArray.append(currentWord); // Add the last word to the array
        
        // Now we have an array of individual word blobs, which we will add one at a time
        // to the line blobs until we run out of space.
        local line = 0;
        lineArray.append(blob());
        foreach (word in wordArray) {
            // Is the current word too long to fit on the line?
            // If so, pad to the end of the line with spaces and start a new line
            if (lineArray[line].len() + word.len() > width) {
                while(lineArray[line].len() < width) {
                    lineArray[line].writen('\x00', 'b');
                }
                lineArray.append(blob());
                line++;
            }
            // Add the current word to the current line
            lineArray[line].writeblob(word);
            
            if (line > 5) {
                break;
            }
            
            // Pad SPACE_WIDTH or until end of line
            for(local i = 0; i < SPACE_WIDTH && lineArray[line].len() < width; i++){
                lineArray[line].writen('\x00', 'b');
            }
        }
        // Write each line to a big blob to be displayed
        local imageData = blob();
        foreach (line in lineArray) {
            imageData.writeblob(line);
        }
        // Pad the blob to the proper number of bytes to overwrite the entire screen
        while (imageData.len() < byteCount) {
            imageData.seek(0, 'e');
            imageData.writen('\x00', 'b');
        }
        // Write data to screen
        screen.write(imageData);
        if (textString != nv.currentText) {
            screen.backlightFlash();
            screen.backlight(0.5, BACKLIGHT_DURATION); // 50% brightness for 5 seconds
            nv.currentText <- textString;
        }
    }
}
// End PCD8544 class

// Configure a new instance of the class
// Arguments: width, height, spiBus, litePin, rstPin, dcPin
screen <- PCD8544_LCD(84, 48, hardware.spi257, hardware.pin1, hardware.pin2, hardware.pin8, hardware.pin9);

// Reset the screen and run a test if the imp is cold booting or has new code
if (hardware.wakereason() == WAKEREASON_POWER_ON || hardware.wakereason() == WAKEREASON_NEW_SQUIRREL) {
    screen.reset();
    screen.clearScreen();
    screen.command(screen.DEFAULT_CONFIG);
    screen.test();
    nv <- {currentText = ""};
    screen.displayText("Electric Imp");
}

screen.command(screen.DEFAULT_CONFIG);

imp.configure("Nokia 5110 LCD", [], []);

// Must use bindenv() to set correct scope
agent.on("newText", screen.displayText.bindenv(screen));
agent.on("newFrame", screen.displayFrame.bindenv(screen));

agent.send("getUpdate", nv.currentText);

// UNCOMMENT THE FOLLOWING LINE TO ENABLE SLEEP!
//imp.wakeup(15, function() { imp.onidle(function () { server.sleepfor(SLEEP_DURATION) }); });
