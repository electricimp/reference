class ST7735_LCD {
    // ST7735-driven color LCD class
    // Will run with 15MHz SPI clock, but don't go above 6MHz if you want to read anything!
    // System commands
    static NOP       = "\x00"; // No operation
    static SWRESET   = "\x01"; // Software reset
    static RDDID     = "\x04"; // Read display ID
    static RDDST     = "\x09"; // Read display status
    static RDDPM     = "\x0A"; // Read display power
    static RDDMADCTL = "\x0B"; // Read display
    static RDDCOLMOD = "\x0C"; // Read display pixel
    static RDDIM     = "\x0D"; // Read display image
    static RDDSM     = "\x0E"; // Read display signal
    static SLPIN     = "\x10"; // Sleep in
    static SLPOUT    = "\x11"; // Sleep off
    static PTLON     = "\x12"; // Partial mode on
    static NORON     = "\x13"; // Partial mode off (normal)
    static INVOFF    = "\x20"; // Display inversion off
    static INVON     = "\x21"; // Display inversion on
    static GAMSET    = "\x26"; // Gamma curve select
    static DISPOFF   = "\x28"; // Display off
    static DISPON    = "\x29"; // Display on
    static CASET     = "\x2A"; // Column address set
    static RASET     = "\x2B"; // Row address set
    static RAMWR     = "\x2C"; // Memory write
    static RGBSET    = "\x2D"; // LUT (lookup table) for 4k, 65k, 262k color
    static RAMRD     = "\x2E"; // Memory read
    static PTLAR     = "\x30"; // Partial start/end address set
    static TEOFF     = "\x34"; // Tearing effect line off
    static TEON      = "\x35"; // Tearing effect mode set & on
    static MADCTL    = "\x36"; // Memory access data control
    static IDMOFF    = "\x38"; // Idle mode off
    static IDMON     = "\x39"; // Idle mode on
    static COLMOD    = "\x3A"; // Interface pixel format
    static RDID1     = "\xDA"; // Read ID1
    static RDID2     = "\xDB"; // Read ID2
    static RDID3     = "\xDC"; // Read ID3
    // Display commands
    static FRMCTR1   = "\xB1"; // In normal mode (Full colors)
    static FRMCTR2   = "\xB2"; // In idle mode (8-colors)
    static FRMCTR3   = "\xB3"; // In partial mode (full colors)
    static INVCTR    = "\xB4"; // Display inversion control
    static PWCTR1    = "\xC0"; // Power control setting
    static PWCTR2    = "\xC1"; // Power control setting
    static PWCTR3    = "\xC2"; // Power control setting
    static PWCTR4    = "\xC3"; // Power control setting
    static PWCTR5    = "\xC4"; // Power control setting
    static VMCTR1    = "\xC5"; // VCOM control 1
    static VMOFCTR   = "\xC7"; // Set VCOM offset control
    static WRID2     = "\xD1"; // Set LCM version code
    static WRID3     = "\xD2"; // Set customer project code
    static NVCTR1    = "\xD9"; // NVM control status
    static NVCTR2    = "\xDE"; // NVM read command
    static NVCTR3    = "\xDF"; // NVM write command
    static GAMCTRP1  = "\xE0"; // Gamma adjustment (+ polarity)
    static GAMCTRN1  = "\xE1"; // Gamma adjustment (- polarity)
    
    pixelCount = null;
    
    // I/O pins
    spi = null;
    lite = null;
    rst = null;
    cs_l = null;
    dc = null;
    
    // Constructor. Arguments: Width, Height, SPI, Backlight, Reset, Chip Select, Data/Command_L
    constructor(width, height, spiBus, litePin, rstPin, csPin, dcPin) {
        this.pixelCount = width * height;
        this.spi = spiBus;
        this.lite = litePin;
        this.rst = rstPin;
        this.cs_l = csPin;
        this.dc = dcPin;
    }
    
    // Send a command by pulling the D/C line low and writing to SPI
    // Takes a variable number of parameters which are sent after the command
    function command(c, ...) {
        cs_l.write(0);      // Select LCD
        dc.write(0);        // Command mode
        spi.write(c);       // Write command
        dc.write(1);        // Exit command mode to send parameters
        foreach (datum in vargv) {
            spi.write(datum);
        }
        cs_l.write(1);      // Deselect LCD
    }
    
    // Read bytes and return as a blob (this doesn't work - maybe because SCLK is too fast)
    function read(numberOfBytes) {
        cs_l.write(0);
        dc.write(1);    // All reads are data mode
        local output = spi.readblob(numberOfBytes);
        cs_l.write(1);
        return output;
    }
    
    // Write a blob to the screen
    function writeBlob(imageBlob) {
        cs_l.write(0);          // Select the LCD
        spi.write(imageBlob);   // Write the blob
        cs_l.write(1);          // Deselect the LCD
    }
    
    // Pulse the reset line for 50ms and send a software reset command
    function reset() {
        rst.write(0);
        imp.sleep(0.05);
        rst.write(1);
        command(SWRESET);
        imp.sleep(0.120); // Must wait 120ms before sending next command
    }
    
    // Clear the contents of the display RAM
    function clear() {
        scan("\x00\x00");           // Slow, looks neat
//        fillScreen("\x00\x00");   // Fast, takes more memory
    }
    
    // Initialize the display (Reset, exit sleep, turn on display)
    function initialize() {
        server.log("Initializing...");
        reset();                    // HW/SW reset
        clear();                    // Clear screen
        lite.write(1.0);            // Turn on backlight
        command(SLPOUT);            // Wake from sleep
        command(DISPON);            // Display on
        command(COLMOD, "\x05");    // 16-bit color mode
        command(FRMCTR1, "\x00", "\x06", "\x03");   // Refresh rate / "porch" settings
    }
    
    // Fill screen with a color by (slowly) scanning throw each pixel
    function scan(color) {
        command(RAMWR);
        cs_l.write(0);
        local w = spi.write.bindenv(spi);
        for (local i = 0; i < pixelCount; i++) {
            w(color + color);
        }
        cs_l.write(1);
    }
    
    // Fill screen with a solid color (two bytes, RGB 5-6-5) in two chunks
    // RED, GREEN, and BLUE are static and can be used for testing
    function fillScreen(color) {
        server.log("Filling screen.");
        cs_l.write(0);
        command(RAMWR);
        local colorBlob = blob(pixelCount);
        foreach (i, byte in colorBlob) {
            if (i % 2) {
                colorBlob[i] = color[1];
            }
            else
                colorBlob[i] = color[0];
        }
        spi.write(colorBlob);
        spi.write(colorBlob);
        cs_l.write(1);
    }

    
}
// End ST7735_LCD class