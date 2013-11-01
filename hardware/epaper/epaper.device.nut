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

/* 
 * Epaper Device Firmware
 * Tom Byrne
 * tom@electricimp.com
 * 10/9/2013
 */

// SPI Clock Rate in kHz
const SPICLK = 30000;

class epaper {
    /*
     * class to drive Pervasive Displays epaper display
     * see http://repaper.org
     */

    WIDTH           = null;
    HEIGHT          = null;
    PIXELS          = null;
    BYTESPERSCREEN  = null;

    stageTime       = null;

    spi             = null;
    epd_cs_l        = null;
    busy            = null;
    tempsense       = null;
    pwm             = null;
    rst_l           = null;
    panel           = null;
    border          = null;
    discharge       = null;

    constructor(width, height, spi, epd_cs_l, busy, tempsense, pwm, rst_l, panel, discharge, border) {
        // set display size parameters
        this.WIDTH = width;
        this.HEIGHT = height;
        this.PIXELS = this.WIDTH * this.HEIGHT;
        this.BYTESPERSCREEN = this.PIXELS / 4;
        this.stageTime = 480;

        // verify the display dimensions and quit if they're bogus
        switch (this.WIDTH) {
            case 128: // 1.44" screen check
                if (this.HEIGHT != 96) {
                    this.invalidDimensions();
                    return -1;
                }
                // otherwise, dimensions are valid
                break;
            case 200: // 2.0" screen check
                if (this.HEIGHT != 96) {
                    this.invalidDimensions();
                    return -1;
                }
                break;
            case 264:
                    this.stageTime = 630
                    if (this.HEIGHT != 176) {
                    this.invalidDimensions();
                    return -1;
                }
                break;
            default:
                this.invalidDimensions();
                return -1;
        }
        // dimensions OK

        // initialize the SPI bus
        // this is tricky since we're likely sharing it with the SPI flash. Need to use a clock speed that both
        // are ok with, or reconfigure the bus on every transaction
        // As it turns out, the ePaper display is content with 4 MHz to 12 MHz, all of which are ok with the flash
        // Furthermore, the display seems to work just fine at 15 MHz.
        this.spi = spi;
        server.log("Display Running at: " + this.spiOff() + " kHz");

        this.epd_cs_l = epd_cs_l;
        this.epd_cs_l.configure(DIGITAL_OUT);
        this.epd_cs_l.write(0);

        // initialize the other digital i/o needed by the display
        this.busy = busy;
        this.busy.configure(DIGITAL_IN);

        this.tempsense = tempsense;
        this.tempsense.configure(ANALOG_IN);

        this.pwm = pwm;
        this.pwm.configure(PWM_OUT, 1/200000.0, 0.0);

        this.rst_l = rst_l;
        this.rst_l.configure(DIGITAL_OUT);
        this.rst_l.write(0);

        this.panel = panel;
        this.panel.configure(DIGITAL_OUT);
        this.panel.write(0);

        this.discharge = discharge;
        this.discharge.configure(DIGITAL_OUT);
        this.discharge.write(0);

        this.border = border;
        this.border.configure(DIGITAL_OUT);
        this.border.write(0);

        // must call this.start before operating on panel
    }

    function invalidDimensions() {
        server.error("Device: ePaper Display Constructor called with invalid dimensions.\n"+
            " Valid sizes:\n128 x 96 (1.44\")\n200 x 96 (2.0\")\n264 x 176 (2.7\")");
        return;
    }

    // enable SPI
    function spiOn() {
        local freq = this.spi.configure(CLOCK_IDLE_HIGH | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        this.spi.write("\x00");
        imp.sleep(0.00001);
        return freq;
    }

    // disable SPI
    function spiOff() {
        local freq = this.spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | CLOCK_2ND_EDGE, SPICLK);
        this.spi.write("\x00");
        imp.sleep(0.00001);
        return freq;
    }

    // Write to EPD registers over SPI
    function writeEPD(index, ...) {
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0
        imp.sleep(0.00001);
        this.spi.write(format("%c%c", 0x70, index)); // Write header, then register index
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0
        this.spi.write(format("%c", 0x72));          // Write data header
        foreach (word in vargv) {
            this.spi.write(format("%c", word));     // then register data
        }
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
    }

    function start() {
        server.log("Powering On EPD.");

        /* POWER-ON SEQUENCE ------------------------------------------------*/

        // make sure SPI is low to avoid back-powering things through the SPI bus
        this.spiOn();

        // Make sure signals start unasserted (rest, panel-on, discharge, border, cs)
        this.rst_l.write(0);
        this.panel.write(0);
        this.discharge.write(0);
        this.border.write(0);
        this.epd_cs_l.write(0);

        // Start PWM input
        this.pwm.write(0.5);

        // Let PWM toggle for 5ms
        imp.sleep(0.005);

        // Turn on panel power
        this.panel.write(1);

        // let PWM toggle for 10 ms
        imp.sleep(0.010);

        this.rst_l.write(1);
        this.border.write(1);
        this.epd_cs_l.write(1);
        imp.sleep(0.005);

        // send reset pulse
        this.rst_l.write(0);
        imp.sleep(0.005);
        this.rst_l.write(1);
        imp.sleep(0.005);

        // Wait for screen to be ready
        while (busy.read()) {
            server.log("Waiting for COG Driver to Power On...");
            imp.sleep(0.005);
        }

        // Channel Select
        switch(this.WIDTH) {
            case 128:
                // 1.44" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x00,0x00,0x0F,0xFF,0x00);
                return;
            case 200:
                // 2" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x00,0x01,0xFF,0xE0,0x00);
                break;
            case 264:
                // 2.7" Display
                this.writeEPD(0x01,0x00,0x00,0x00,0x7F,0xFF,0xFE,0x00,0x00);
                break;
            default:
                server.error("Invalid Display Size");
                this.stop();
                return;
        }

        // DC/DC Frequency Setting
        this.writeEPD(0x06, 0xFF);

        // High Power Mode Oscillator Setting
        this.writeEPD(0x07, 0x9D);

        // Disable ADC
        this.writeEPD(0x08, 0x00);

        // Set Vcom level
        this.writeEPD(0x09, 0xD0, 0x00);

        // Gate and Source Voltage Level
        if (this.WIDTH == 264) {
            this.writeEPD(0x04, 0x00);
        } else {
            this.writeEPD(0x04, 0x03);
        }

        // delay for PWM
        imp.sleep(0.005);

        // Driver latch on ("cancel register noise")
        this.writeEPD(0x03, 0x01);

        // Driver latch off
        this.writeEPD(0x03, 0x00);

        // delay for PWM
        imp.sleep(0.005);

        // Start charge pump positive V (VGH & VDH on)
        this.writeEPD(0x05, 0x01);

        // last delay before stopping PWM
        imp.sleep(0.030);

        // Stop PWM
        this.pwm.write(0.0);

        // Start charge pump negative voltage
        this.writeEPD(0x05, 0x03);

        imp.sleep(0.030);

        // Set charge pump Vcom driver to ON
        this.writeEPD(0x05, 0x0F);

        imp.sleep(0.030);

        // "Output enable to disable" (docs grumble grumble)
        this.writeEPD(0x02, 0x24);

        server.log("COG Driver Initialized.");
    }


    // Power off COG Driver
    function stop() {
        server.log("Powering Down EPD");

        // Write a dummy frame and dummy line
        local dummyScreen = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            dummyScreen.writen(0x55,'b');
        }
        this.drawScreen(dummyScreen);
        dummyScreen.seek(0,'b');
        this.writeLine(0x7fff,dummyScreen.readblob(BYTESPERSCREEN/HEIGHT));

        imp.sleep(0.025);

        // set BORDER low for 30 ms
        this.border.write(0);
        imp.sleep(0.030);
        this.border.write(1);

        // latch reset on
        this.writeEPD(0x03, 0x01);

        //output enable off
        this.writeEPD(0x02, 0x05);

        // VCOM power off
        this.writeEPD(0x05, 0x0e);

        // power off negative charge pump
        this.writeEPD(0x05, 0x02);

        // discharge
        writeEPD(0x04, 0x0c);

        imp.sleep(0.120);

        // all charge pumps off
        this.writeEPD(0x05, 0x00);

        // turn off oscillator
        this.writeEPD(0x07, 0x0d);

        // discharge internal - 1 (?)
        this.writeEPD(0x04, 0x50);

        imp.sleep(0.040);

        // discharge internal - 2 (??)
        this.writeEPD(0x04, 0xA0);

        imp.sleep(0.040);

        // discharge internal - 3 (???)
        this.writeEPD(0x04, 0x00);

        // turn off all power and set all inputs low
        this.rst_l.write(0);
        this.panel.write(0);
        this.border.write(0);

        // ensure MOSI is low before CS Low
        this.spiOff();
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);

        // send discharge pulse
        server.log("Discharging Rails");
        this.discharge.write(1);
        imp.sleep(0.15);
        this.discharge.write(0);

        server.log("Display Powered Down.");
    }

    // draw a line on the screen
    function writeLine(line, data) {

        local line_data = blob((this.WIDTH / 4) + (this.HEIGHT / 4));

        line_data.writen(0x72, 'b');

        // Even pixels
        for (local i = 0; i < (this.WIDTH / 8); i++) {
            line_data.writen(data[i],'b');
        }

        // Scan Lines
        for (local j = 0; j < (this.HEIGHT / 4); j++) {
            if (line / 4 == j) {
                line_data.writen((0xC0 >> (2 * (line & 0x03))), 'b');
            } else {
                line_data.writen(0x00,'b');
            }
        }

        // Odd Pixels
        for (local k = (this.WIDTH / 8); k < (this.WIDTH / 4); k++) {
            line_data.writen(data[k], 'b');
        }

        // null byte to end each line
        line_data.writen(0x00,'b');

        // read from start of line
        line_data.seek(0,'b');

        // Set charge pump voltage levels
        if (this.WIDTH == 264) {
            this.writeEPD(0x04, 0x00);
        } else {
            this.writeEPD(0x04, 0x03);
        }

        // Send index "0x0A" and keep CS asserted
        this.epd_cs_l.write(0);                      // CS = 0
        imp.sleep(0.00001);
        this.spi.write(format("%c%c", 0x70, 0x0A));  // Write header, then register index
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);                      // CS = 1
        imp.sleep(0.00001);
        this.epd_cs_l.write(0);                      // CS = 0

        this.spi.write(line_data);
        imp.sleep(0.00001);
        this.epd_cs_l.write(1);

        // Turn on output enable
        this.writeEPD(0x02, 0x2F);
    }

    // draw the full screen
    function drawScreen(screenData) {
        screenData.seek(0,'b');
        local length = BYTESPERSCREEN/HEIGHT;
        while (!screenData.eos()) {
            this.writeLine(screenData.tell()/length, screenData.readblob(length));
        }
    }

    // repet drawing for the temperature compensated stage time
    function drawScreenCompensated(screenData) {
        local stageTime = this.stageTime * this.temperatureToFactor(this.getTemp());
        local start_time = hardware.millis();
        while (stageTime > 0) {
            this.drawScreen(screenData);
            stageTime = stageTime - (hardware.millis() - start_time);
        }
    }

    // convert a temperature in Celcius to scale factor
    function temperatureToFactor(temperature) {
        if (temperature <= -10) {
            return 17.0;
        } else if (temperature <= -5) {
            return 12.0;
        } else if (temperature <= 5) {
            return 8.0;
        } else if (temperature <= 10) {
            return 4.0;
        } else if (temperature <= 15) {
            return 3.0;
        } else if (temperature <= 20) {
            return 2.0;
        } else if (temperature <= 40) {
            return 1.0;
        }
        return 0.7;
    }

    /*
     * fill the screen with a fixed value
     *
     * takes in a one byte value to fill the screen
     */
    function fillScreen(fillValue) {
        local screenData = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            screenData.writen(fillValue, 'b');
        }
        this.drawScreenCompensated(screenData);
    }

    // clear display
    function clear() {
        // We don't know what's on the screen, so just clear it
        // draw the screen white first
        server.log("Clearing Screen");
        this.fillScreen(0xAA);
        // draw the screen black
        this.fillScreen(0xFF);
        // draw the screen white again
        this.fillScreen(0xAA);
    }

    /*
     * Pervasive Displays breakout includes Seiko S-5813A/5814A Series Analog Temp Sensor
     * http://datasheet.sii-ic.com/en/temperature_sensor/S5813A_5814A_E.pdf
     *
     *  -30C -> 2.582V
     *  +30C -> 1.940V
     * +100C -> 1.145V
     */
    function getTemp() {
        local rawTemp = 0;
        local rawVdda = 0;
        // Take 10 readings and average for accuracy
        for (local i = 0; i < 10; i++) {
            rawTemp += this.tempsense.read();
            rawVdda += hardware.voltage();
        }
        local vdda = (rawVdda / 10.0);
        // temp sensor has resistive divider on output
        // Rhigh = 26.7k
        // Rlow = 17.8k
        // Vout = Vsense / (17.8 / (26.7+17.8)) = Vsense * 2.5
        local vsense = ((rawTemp / 10.0) * (vdda / 65535.0)) * 2.5;
        local temp = ((vsense  - 1.145) / -0.01104) + 100;
        return temp;
     }
}

/* REGISTER AGENT CALLBACKS -------------------------------------------------*/
agent.on("start", function(data) {
    display.start();
});

agent.on("stop", function(data) {
    display.stop();
});

agent.on("wht", function(data) {
    display.fillScreen(0xAA);
});

agent.on("blk", function(data) {
    display.fillScreen(0xFF);
});

agent.on("newImgStart", function(data) {
    //server.log("Device got new image start.");
    display.start();
    // agent sends the inverted version of the current image first
    display.drawScreenCompensated(data);
    // white out the screen second
    display.fillScreen(0xAA);
    // signal we're ready for the new image data, sent inverted first
    //server.log("Device Ready for new image inverted.");
    agent.send("readyForNewImgInv",0);
});

agent.on("newImgInv", function(data) {
    //server.log("Device got new image inverted.");
    display.drawScreenCompensated(data);
    //server.log("Device ready for new image normal.");
    agent.send("readyForNewImgNorm",0);
});

agent.on("newImgNorm", function(data) {
    //server.log("Device got new image normal.");
    display.drawScreenCompensated(data);
    display.stop();
    server.log("Done Drawing New Image.");
})

agent.on("clear", function(val) {
    server.log("Force-clearing screen.");
    display.start();
    display.clear();
    display.stop();
});

/* The device requests its own parameters from the agent upon startup.
 * This handler finishes initializing the device when the agent responds with these parameters.
 */
agent.on("params_res", function(res) {
    /*
     * display dimensions
     *
     * Standard sizes from repaper.org:
     * 1.44" = 128 x 96  px
     * 2.0"  = 200 x 96  px
     * 2.7"  = 264 x 176 px
     */

    // Pin configuration
    // epd_cs_l    <- hardware.pin1;   // EPD Chip Select (active-low)
    // MISO        <- hardware.pin2;   // SPI interface
    // SCLK        <- hardware.pin5;   // SPI interface
    // busy        <- hardware.pin6;   // Busy input
    // MOSI        <- hardware.pin7;   // SPI interface
    // tempsense   <- hardware.pin8;   // Temperature sensor
    // pwm         <- hardware.pin9;   // PWM (200kHz, 50% duty cycle)
    // rst_l       <- hardware.pinA;   // Reset (active-low)
    // panel       <- hardware.pinB;   // Panel On
    // discharge   <- hardware.pinC;   // Discharge
    // border      <- hardware.pinD;   // Border Control
    // flash_cs_l  <- hardware.pinE;   // Flash Chip Select (active low)

    // ePaper(WIDTH, HEIGHT, SPI_IFC, EPD_CS_L, BUSY, TEMPSENSE, PWM, RESET, PANEL_ON, DISCHARGE, BORDER, FLASH_CS_L)
    display <- epaper(res.width, res.height, hardware.spi257, hardware.pin1, hardware.pin6, hardware.pin8,
        hardware.pin9, hardware.pinA, hardware.pinB, hardware.pinC, hardware.pinD);

    server.log("Device Started, free memory: " + imp.getmemoryfree());
    server.log("Display is " + display.WIDTH + " x " + display.HEIGHT + " px (" + display.BYTESPERSCREEN + " bytes).");
    server.log(format("Temperature: %.2f C", display.getTemp()));
    server.log("Ready.");
});

/* RUNTIME BEGINS HERE ------------------------------------------------------*/

// deactivate the FLASH chip
flash_cs_l <- hardware.pinE;
flash_cs_l.configure(DIGITAL_OUT);
flash_cs_l.write(1);

// ask the agent to remind us what we are so we can finish initialization.
agent.send("params_req",0);