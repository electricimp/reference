// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// SPI Clock Rate in kHz
const SPICLK = 7500;
const IOEXP_ADDR = 0x40; // 8-bit address
const DISPWIDTH = 264;
const DISPHEIGHT = 176;

// class to drive Pervasive Displays epaper display
// see http://repaper.org
class Epaper {

    WIDTH           = null;
    HEIGHT          = null;
    PIXELS          = null;
    BYTESPERSCREEN  = null;
    FRAMEREPEATS    = 2;
    spi             = null;
    epd_cs_l        = null;
    busy            = null;
    rst_l           = null;
    pwr_en_l        = null;
    panel           = null;
    border          = null;
    discharge       = null;
    
    epd_cs_l_write  = null;
    spi_write       = null;

    constructor(_width, _height, _spi, _epd_cs_l, _busy, _rst_l, _pwr_en_l, _discharge, _border) {
        WIDTH = _width;
        HEIGHT = _height;
        PIXELS = WIDTH * HEIGHT;
        BYTESPERSCREEN = PIXELS / 4;
        spi = _spi;
        server.log("Display Running at: " + spiOff() + " kHz");
        epd_cs_l = _epd_cs_l;
        epd_cs_l.configure(DIGITAL_OUT, 0);
        busy = _busy;
        busy.configure(DIGITAL_IN);
        rst_l = _rst_l;
        rst_l.configure(DIGITAL_OUT, 0);
        discharge = _discharge;
        discharge.configure(DIGITAL_OUT, 0);
        border = _border;
        border.configure(DIGITAL_OUT, 0);
        pwr_en_l = _pwr_en_l;
        pwr_en_l.configure(DIGITAL_OUT, 1);

        // alias speed-critical calls
        epd_cs_l_write = epd_cs_l.write.bindenv(epd_cs_l);
        spi_write      = spi.write.bindenv(spi);
    }
    function spiOn() {
        local freq = spi.configure(CLOCK_IDLE_HIGH | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        spi.write("\x00");
        return freq;
    }
    function spiOff() {
        local freq = spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        spi.write("\x00");
        return freq;
    }
    // Write to EPD registers over SPI
    function writeEPD(index, ...) {
        epd_cs_l_write(1);                    
        epd_cs_l_write(0);          
        spi_write(format("%c%c", 0x70, index)); // Write header, then register index
        epd_cs_l_write(1);      
        epd_cs_l_write(0);        
        spi_write(format("%c", 0x72));          // Write data header
        
        foreach (word in vargv) {
            spi_write(format("%c", word)); 
        }
        epd_cs_l_write(1);        
    }
    function write_epd_pair(index, value) {
        epd_cs_l_write(1);                 
        epd_cs_l_write(0);                   
        spi_write(format(CHARCHAR, 0x70, index)); // Write header, then register index
        epd_cs_l_write(1);                 
        epd_cs_l_write(0);            
        spi_write(format(CHARCHAR, 0x72, value)); // Write data header, then register data
        epd_cs_l_write(1);                    
    }
    function writeEPD_raw(...) {
        epd_cs_l_write(0);                  
        foreach (word in vargv) {
            spi_write(format("%c", word));    
        }
        epd_cs_l_write(1);                  
    }
    function readEPD(...) {
        local result = "";
        epd_cs_l_write(0);              
        foreach (word in vargv) {
            result += spi.writeread(format("%c", word));
        }
        epd_cs_l_write(1);                
        return result;
    }
    function start() {
        server.log("Powering On EPD.");
 
        /* Power-On Sequence ------------------------------------------------*/
 
        // make sure SPI is low to avoid back-powering things through the SPI bus
        spiOn();
 
        // Make sure signals start unasserted (rest, panel-on, discharge, border, cs)
        pwr_en_l.write(1);
        rst_l.write(0);
        discharge.write(0);
        border.write(0);
        epd_cs_l_write(0);

        // Turn on panel power
        pwr_en_l.write(0);
        rst_l.write(1);
        epd_cs_l_write(1);
        border.write(1);
        
        // send reset pulse
        rst_l.write(0);
        imp.sleep(0.005);
        rst_l.write(1);
        imp.sleep(0.005);
        
        /* EPD Driver Initialization ----------------------------------------*/

        writeEPD(0x02, 0x40);         // Disable OE
        writeEPD(0x0b, 0x02);         //Power Saving Mode
        writeEPD(0x01,0x00,0x00,0x00,0x7F,0xFF,0xFE,0x00,0x00);        // Channel Select for 2.7" Display
        //writeEPD(0x07, 0x9D);         // High Power Mode Oscillator Setting
        writeEPD(0x07, 0xD1);         // High Power Mode Oscillator Setting 
        //writeEPD(0x08, 0x00);         // Disable ADC
        writeEPD(0x08, 0x02);         // "Power Setting"
        //writeEPD(0x09, 0xD0, 0x00);   // Set Vcom level
        writeEPD(0x09, 0xc2);         // Set Vcom level
        //writeEPD(0x04, 0x00);         // power setting
        writeEPD(0x04, 0x03);         // "Power Setting"
        writeEPD(0x03, 0x01);         // Driver latch on ("cancel register noise")
        writeEPD(0x03, 0x00);         // Driver latch off
        
        imp.sleep(0.05);
        
        // writeEPD(0x05, 0x01);         // Start charge pump positive V (VGH & VDH on)
        // imp.sleep(0.240);
        // writeEPD(0x05, 0x03);         // Start charge pump negative voltage
        // imp.sleep(0.04);
        // writeEPD(0x05, 0x0f);         // Set charge pump Vcom driver to ON
        // imp.sleep(0.04);
 
        local dc_ok = false;
        
        for (local i = 0; i < 4; i++) {
            // Start charge pump positive V (VGH & VDH on)
            this.writeEPD(0x05, 0x01);
            imp.sleep(0.240);
            // Start charge pump negative voltage
            this.writeEPD(0x05, 0x03);
            imp.sleep(0.040);
            // Set charge pump Vcom driver to ON
            this.writeEPD(0x05, 0x0f);
            imp.sleep(0.040);
            writeEPD_raw(0x70, 0x0f);
            local dc_state = readEPD(0x73, 0x00)[1];
            //server.log("dc state: " + dc_state);
            if (0x40 == (0x40 & dc_state)) {
                dc_ok = true;
                break;
            }
        }
        
        if (!dc_ok) {
            server.error("DC state failed");
            // Output enable to disable
            this.writeEPD(0x02, 0x40);
            this.stop();
            // TODO led error blink
            return;
        }
        
        server.log("COG Driver Initialized.");
    }
    // Power off COG Driver
    function stop() {
        server.log("Powering Down EPD");

        border.write(0);
        imp.sleep(0.2);
        border.write(1);
        
        // Check DC/DC
        writeEPD_raw(0x70, 0x0f);
        local dc_state = readEPD(0x73, 0x00)[1];
        //server.log("dc state: " + dc_state);
        if (0x40 != (0x40 & dc_state)) {
            // TODO fail properly
            server.log("dc failed");
        }
 
        writeEPD(0x03, 0x01);        // latch reset on
        writeEPD(0x02, 0x05);        // output enable off
        writeEPD(0x05, 0x03);        // VCOM power off
        writeEPD(0x05, 0x01);        // power off negative charge pump
        imp.sleep(0.240);
        writeEPD(0x05, 0x00);        // power off all charge pumps
        writeEPD(0x07, 0x01);        // turn off oscillator
        writeEPD(0x04, 0x83);        // discharge internal on

        imp.sleep(0.030);
 
        // turn off all power and set all inputs low
        rst_l.write(0);
        pwr_en_l.write(1);
        border.write(0);
 
        // ensure MOSI is low before CS Low
        spiOff();
        imp.sleep(0.001);
        epd_cs_l.write(0);
 
        // send discharge pulse
        discharge.write(1);
        imp.sleep(0.15);
        discharge.write(0);
        epd_cs_l.write(1);
        server.log("Display Powered Down.");
    }
    function drawScreen(screenData) {
        for (local repeat = 0; repeat < FRAMEREPEATS; repeat++) {   
            foreach (line in screenData) {    
                writeEPD(0x04, 0x00); // set charge pump voltage level
                writeEPD_raw(0x70, 0x0A)
                epd_cs_l_write(0);
                spi_write("\x72");      // line header byte
                spi_write("\x00");      // null border byte
                spi_write(line);
                spi_write("\x00");   
                epd_cs_l_write(1);
                writeEPD(0x02, 0x2F); // Output enable  
            }
        }
    }
}

/* REGISTER AGENT CALLBACKS -------------------------------------------------*/

agent.on("newImg", function(data) {
    server.log("Drawing new image, memory free = "+imp.getmemoryfree());
    display.start();
    // agent sends the inverted version of the current image first
    display.drawScreen(data);
    agent.send("readyForWhite",0);
});

agent.on("white", function(data) {
    display.drawScreen(data);
    agent.send("readyForNewImgInv",0);
});

agent.on("newImgInv", function(data) {
    display.drawScreen(data);
    agent.send("readyForNewImgNorm",0);
});

agent.on("newImgNorm", function(data) {
    display.drawScreen(data);
    display.stop();
})

agent.on("clear", function(val) {
    server.log("Force-clearing screen.");
    display.start();
    display.white()
    display.stop();
});

