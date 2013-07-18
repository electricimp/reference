// RePaper E-Ink Display

// Add "device" tag to logs to differentiate from agent logs
function log(msg) {
    server.log("Device: "+msg);
}


class rePaper {
    /*
     * class to drive rePaper epaper display
     * http://repaper.org
     */

    WIDTH           = null;
    HEIGHT          = null;
    PIXELS          = null;
    BYTESPERSCREEN  = null;

    spi             = null;
    epd_cs_l        = null;
    busy            = null;
    tempsense       = null;
    pwm             = null;
    rst_l           = null;
    panel           = null;
    border          = null;
    discharge       = null;
    flash           = null;

    constructor(width, height, spi, epd_cs_l, busy, tempsense, pwm, rst_l, panel, discharge, border) {
        // set display size parameters
        this.WIDTH = width;
        this.HEIGHT = height;
        this.PIXELS = this.WIDTH * this.HEIGHT;
        this.BYTESPERSCREEN = this.PIXELS / 4;

        // verify the display dimensions and quit if they're bogus
        switch (this.WIDTH) {
            case 128: // 1.44" screen check
                if (this.HEIGHT != 96) {
                    invalidDimensions();
                    return -1;
                }
                // otherwise, dimensions are valid
                break;
            case 200: // 2.0" screen check
                if (this.HEIGHT != 96) {
                    invalidDimensions();
                    return -1;
                }
                break;
            case 264: 
                if (this.HEIGHT != 176) {
                    invalidDimensions();
                    return -1;
                }
                break;
            default:
                invalidDimensions();
                return -1;
        }
        // dimensions OK

        // initialize the SPI bus
        // this is tricky since we're likely sharing it with the SPI flash. Need to use a clock speed that both 
        // are ok with, or reconfigure the bus on every transaction
        // As it turns out, the ePaper display is content with 4 MHz to 12 MHz, all of which are ok with the flash
        // Furthermore, the display seems to work just fine at 15 MHz. 
        this.spi = spi;
        server.log("Display Running at: "+this.spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000)+" kHz");
        this.epd_cs_l = epd_cs_l; 
        this.epd_cs_l.configure(DIGITAL_OUT);
        this.epd_cs_l.write(1);

        // initialize the other digital i/o needed by the display
        this.busy = busy;
        this.busy.configure(DIGITAL_IN);

        this.tempsense = tempsense;
        this.tempsense.configure(ANALOG_IN);

        this.pwm = pwm;
        this.pwm.configure(PWM_OUT, 1/200000, 0.0);

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

    // Write to EPD registers over SPI
    function writeEPD(index, ...) {
        epd_cs_l.write(1);                      // CS = 1
        epd_cs_l.write(0);                      // CS = 0
        spi.write(format("%c%c", 0x70, index)); // Write header, then register index
        epd_cs_l.write(1);                      // CS = 1
        epd_cs_l.write(0);                      // CS = 0    
        spi.write(format("%c", 0x72));          // Write data header
        foreach (datum in vargv) {
            spi.write(format("%c", datum));     // then register data
        }
        epd_cs_l.write(1);                      // CS = 1
    }

    // Power on COG Driver
    function start() {
        server.log("Device: Powering On EPD.");

        /* POWER-ON SEQUENCE ------------------------------------------------*/

        // make sure SPI is low to avoid back-powering things through the SPI bus
        spi.write("\x00");

        // Make sure signals start unasserted (rest, panel-on, discharge, border, cs)
        rst_l.write(0);
        panel.write(0);
        discharge.write(0);
        border.write(0);
        epd_cs_l.write(0);

        // Start PWM input
        pwm.write(0.5);         

        // Let PWM toggle for 5ms
        imp.sleep(0.005);
        
        // Turn on panel power
        panel.write(1);             

        // let PWM toggle for 10 ms
        imp.sleep(0.010);

        rst_l.write(1);
        border.write(1);
        epd_cs_l.write(1);
        imp.sleep(0.005);

        // send reset pulse
        epd_cs_l.write(0);
        imp.sleep(0.005);
        epd_cs_l.write(1);  

        // Wait for screen to be ready (dunno if this works)
        while (busy.read()) {
            server.log("Device: Waiting for COG Driver to Power On...");
            imp.sleep(0.5);
        }

        server.log("Device: COG Driver Powered On");

        /* INITIALIZATION SEQUENCE ------------------------------------------*/
        server.log("Device: Initializing EPD.");

        // Channel Select
        switch(this.WIDTH) {
            case 128:
                // 1.44" Display
                writeEPD(0x01,0x00,0x00,0x00,0x00,0x00,0x0F,0xFF,0x00);
                return;
            case 200:
                // 2" Display
                writeEPD(0x01,0x00,0x00,0x00,0x00,0x01,0xFF,0xE0,0x00);
                break;
            case 264:
                // 2.7" Display
                writeEPD(0x01,0x00,0x00,0x00,0x7F,0xFF,0xFE,0x00,0x00);
                break;
            default:
                server.error("Invalid Display Size");
                this.stop();
                return;
        }

        // DC/DC Frequency Setting
        writeEPD(0x06, 0xFF);

        // High Power Mode Oscillator Setting
        writeEPD(0x07, 0x9D);

        // Disable ADC
        writeEPD(0x08, 0x00);

        // Set Vcom level
        writeEPD(0x09, 0xD0, 0x00);

        // Gate and Source Voltage Level
        if (this.WIDTH == 264) {
            writeEPD(0x04, 0x00);
        } else {
            writeEPD(0x04, 0x03);    
        }
        
        imp.sleep(0.005);

        // Driver latch on (cancel register noise)
        writeEPD(0x03, 0x01);

        // Driver latch off
        writeEPD(0x03, 0x00);

        // Start charge pump positive V (VGH & VDH on)
        writeEPD(0x05, 0x01);

        // last delay before stopping PWM
        imp.sleep(0.030); 
        
        // Stop PWM
        pwm.write(0.0);
        
        // Start charge pump negative voltage
        writeEPD(0x05, 0x03);
        imp.sleep(0.030);

        // Set charge pump Vcom driver to ON
        writeEPD(0x05, 0x0F);

        // Output "enable to disable", whatever that means
        writeEPD(0x02, 0x24);

        server.log("Device: COG Driver Initialized.");
    }

    // Power off COG Driver
    function stop() {
        server.log("Device: Powering Down EPD");

        // Write a dummy frame and dummy line
        local dummyScreen = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            dummyScreen.writen(0x55,'b');
        }
        drawScreen(dummyScreen);
        dummyScreen.seek(0,'b');
        writeLine(0x7fff,dummyScreen.readblob(BYTESPERSCREEN/HEIGHT));

        imp.sleep(0.025);

        // set BORDER low for 30 ms
        border.write(0);
        imp.sleep(0.030);
        border.write(1);

        // latch reset on
        writeEPD(0x03, 0x01);

        //output enable off
        writeEPD(0x02, 0x05);

        // VCOM power off
        writeEPD(0x05, 0x0e);

        // power off negative charge pump
        writeEPD(0x05, 0x02);

        // discharge
        writeEPD(0x04, 0x0c);
        imp.sleep(0.120);

        // all charge pumps off
        writeEPD(0x05, 0x00);

        // turn off oscillator
        writeEPD(0x07, 0x0d);

        // discharge internal - 1 (?)
        writeEPD(0x04, 0x50);
        imp.sleep(0.040);

        // discharge internal - 2 (??)
        writeEPD(0x04, 0xA0);
        imp.sleep(0.040);

        // discharge internal - 3 (???)
        writeEPD(0x04, 0x00);
        imp.sleep(0.040);

        // ensure MOSI is low before CS Low
        spi.write(format("%c",0x00)); 
        epd_cs_l.write(0);

        // turn off all power and set all inputs low
        rst_l.write(0);
        panel.write(0);
        border.write(0);

        // send discharge pulse
        discharge.write(1);
        server.log("Device: Discharging Rails");
        imp.sleep(0.25);
        discharge.write(0);

        server.log("Device: Display Powered Down.");
    }

    // draw a line on the screen
    function writeLine(line, data) { 

        local linedata = blob((this.WIDTH / 4) + (this.HEIGHT / 4));

        // Set charge pump voltage levels
        if (this.WIDTH == 264) {
            writeEPD(0x04, 0x00);
        } else {
            writeEPD(0x04, 0x03);
        }
        
        // Send index "0x0A" and keep CS asserted
        epd_cs_l.write(0);                      // CS = 0
        spi.write(format("%c%c", 0x70, 0x0A)); // Write header, then register index
        epd_cs_l.write(1);                      // CS = 1
        epd_cs_l.write(0);                      // CS = 0   
        linedata.writen(0x72, 'b');

        // Even pixels
        for (local i = 0; i < (this.WIDTH / 8); i++) {
            linedata.writen(data[i],'b');
        }

        // Scan Lines
        for (local j = 0; j < (this.HEIGHT / 4); j++) {
            if (line / 4 == j) {
                linedata.writen((0xC0 >> (2 * (line & 0x03))), 'b');
            } else {
                linedata.writen(0x00,'b');
            }       
        }

        // Odd Pixels
        for (local k = (this.WIDTH / 8); k < (this.WIDTH / 4); k++) {
            linedata.writen(data[k], 'b');
        }

        // null byte to end each line
        linedata.writen(0x00,'b');

        spi.write(linedata);

        epd_cs_l.write(1);

        // Turn on output enable
        writeEPD(0x02, 0x2F);
    }

    // draw the full screen
    function drawScreen(screenData) {
        screenData.seek(0,'b');
        while(!screenData.eos()) {
            writeLine(screenData.tell()/(BYTESPERSCREEN/HEIGHT), screenData.readblob(BYTESPERSCREEN/HEIGHT));
        }
    }

    /* 
     * fill the screen with a fixed value
     *
     * takes in a 32-byte value to fill the screen with
     */
    function fillScreen(fillValue) {
        local screenData = blob(BYTESPERSCREEN);
        for (local i = 0; i < BYTESPERSCREEN; i++) {
            screenData.writen(fillValue, 'b');
        }
        drawScreen(screenData);
    }

    // clear display
    function clear() {
        // We don't know what's on the screen, so just clear it
        // draw the screen white first
        server.log("Device: Clearing Screen");
        fillScreen(0xAA);
        // draw the screen black
        fillScreen(0xFF);
        // draw the screen white again
        fillScreen(0xAA);
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
            rawTemp += tempsense.read();
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
agent.on("image", function(imageData) {
    log("Got new image data from Agent. Height = "+imageData.height+" px, Width = "+imageData.width+" px.");
    log("Drawing Screen");
    display.start();
    display.clear();
    display.drawScreen(imageData.data);
    display.stop();
});

/* RUNTIME BEGINS HERE ------------------------------------------------------*/

/*
 * display dimensions
 * 
 * Standard sizes from repaper.org:
 * 1.44" = 128 x 96  px
 * 2.0"  = 200 x 96  px
 * 2.7"  = 264 x 176 px
 */
const displayWidth  = 200;
const displayHeight = 96;

// Pin configuration
// epd_cs_l    <- hardware.pin1;   // EPD Chip Select (active-low)
// busy        <- hardware.pin6;   // Busy input
// tempsense   <- hardware.pin8;   // Temperature sensor
// pwm         <- hardware.pin9;   // PWM (200kHz, 50% duty cycle)
// rst_l       <- hardware.pinA;   // Reset (active-low)
// panel       <- hardware.pinB;   // Panel On
// discharge   <- hardware.pinC;   // Discharge
// border      <- hardware.pinD;   // Border Control
// flash_cs_l  <- hardware.pinE;   // Flash Chip Select (active low)

// ePaper(WIDTH, HEIGHT, SPI_IFC, EPD_CS_L, BUSY, TEMPSENSE, PWM, RESET, PANEL_ON, DISCHARGE, BORDER)
display <- rePaper(displayWidth, displayHeight, hardware.spi257, hardware.pin1, hardware.pin6, hardware.pin8,
    hardware.pin9, hardware.pinA, hardware.pinB, hardware.pinC, hardware.pinD);

log("Classes instantiated, memory: "+imp.getmemoryfree());
log("Display is "+display.WIDTH+" x "+display.HEIGHT+" px ("+display.BYTESPERSCREEN+" bytes).");

/*
display.start();
display.clear();
display.stop();
*/

log(format("Temperature: %.2f C",display.getTemp()));

log("Done.");
