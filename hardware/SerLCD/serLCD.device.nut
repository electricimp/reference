/*
The MIT License (MIT)

Copyright (c) 2013 Jason Snell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

//Custom Characters
//8 custom characters can be created and stored.
//Use this website to create characters: http://www.quinapalus.com/hd44780udg.html
//degree <- [0xe,0xa,0xe,0x0,0x0,0x0,0x0, 0x0]; //This is the "degree" symbol.

LCD_SETCGRAMADDR <- 0x40;

class SerLCD {
    port = null;
    lines = null;
    positions = null;

    constructor(_port) {
        port = _port;
        lines = ["booting...", ""];
        positions = [0, 0];
    }
    
    function set0(line) {
        lines[0] = line;
    }
    
    function set1(line) {
        lines[1] = line;
    }
    
    function clear_screen() {
        port.write(0xFE);
        port.write(0x01);
    }
    
    function cursor_at_line0() {
        port.write(0xFE);
        port.write(128);
    }
    
    function cursor_at_line1() {
        port.write(0xFE);
        port.write(192);
    }
    
    function write_string(string) {
        foreach(i, char in string) {
            port.write(char);
        }
    }
    
    function createChar(location, charmap) {
        location -=1;
        location &0x07;
        for (local i = 0; i<8; i++) {
            command(LCD_SETCGRAMADDR | (location << 3) | i);
            port.write(charmap[i]);
        }
    }
    
    function printCustomChar(num) {
        port.write(num-1);
    }
    
    function command(value) {
        port.write(0xFE);
        port.write(value);
    }
    
    function start() {
        update_screen();
    }
    
    function update_screen() {
        imp.wakeup(0.4, update_screen.bindenv(this));
        
        cursor_at_line0();
        display_message(0);
        
        cursor_at_line1();
        display_message(1);
    }
    
    function display_message(idx) {  
        local message = lines[idx];
        
        local start = positions[idx];
        local end   = positions[idx] + 16;
        
    
        if (end > message.len()) {
            end = message.len();
        }
    
        local string = message.slice(start, end);
        for (local i = string.len(); i < 16; i++) {
            string  = string + " ";
        }
    
        write_string(string);
    
        if (message.len() > 16) {
            positions[idx]++;
            if (positions[idx] > message.len() - 1) {
                positions[idx] = 0;
            }
        }
    }
}

// Register with the server
imp.configure("Serial Display", [], []);

// Configure the UART port
local port0 = hardware.uart57
port0.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);

// Boot!
server.log("booting!");

// Allocate and start a screen
screen <- SerLCD(port0);
screen.clear_screen();
screen.start();

screen.set0("Hello"); // Write the first line
screen.set1("World"); // Write the second line
