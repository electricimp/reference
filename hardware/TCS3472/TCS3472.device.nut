// Color sensor
class TCS3472 {

    _i2c  = null;
    _addr = null;
    _atime = null;

    constructor(i2c, address) {
        _i2c  = i2c;
        _addr = address;

        _init();
    }

    function _init() {

        const DEFAULT_ATIME = 0x80;

        // Each datasheet address is ORed with 0x80 to select the command register,
        enum REGISTERS {
            ENABLE  = 0x80, // Enables states and interrupts
            ATIME   = 0x81, // RGBC time
            WTIME   = 0x83, // Wait time
            AILTL   = 0x84, // Clear interrupt: low threshold, low byte
            AILTH   = 0x85, // Clear interrupt: low threshold, high byte
            AIHTL   = 0x86, // Clear interrupt: high threshold, low byte
            AIHTH   = 0x87, // Clear interrupt: high threshold, high byte
            PERS    = 0x8C, // Interrupt persistence filter
            CONFIG  = 0x8D, // Configuration (used to set WLONG, which increases WTIME by a factor of 12x)
            CONTROL = 0x8F, // Control
            ID      = 0x92, // Device ID
            STATUS  = 0x93, // Device status
            CDATAL  = 0x94, // 'Clear' data (low byte)
            CDATAH  = 0x95, // 'Clear' data (high byte)
            RDATAL  = 0x96, // Red data (low byte)
            RDATAH  = 0x97, // Red data (high byte)
            GDATAL  = 0x98, // Green data (low byte)
            GDATAH  = 0x99, // Green data (high byte)
            BDATAL  = 0x9A, // Blue data (low byte)
            BDATAH  = 0x9B  // Blue data (high byte)
        }

        enum TRANSACTION_TYPE {
            REPEATED_BYTE   = 0x00, // This is the default and can be omitted normally
            AUTO_INCREMENT  = 0x01, // This mode increments the target register every read to save time
            CLEAR_INTERRUPT = 0x11
        }

        enum REG_ENABLE {
            AIEN    = 0x10, // RGBC interrupt enable. When asserted, permits RGBC interrupts to be generated.
            WEN     = 0x08, // Wait enable. Activates the wait timer.
            AEN     = 0x02, // RGBC enable. Activates the RGBC color sensor.
            PON     = 0x01  // Power ON. Enables internal oscillator. (must wait 2.4ms for warm-up)
        }

        // RGBC Gain Control
        enum REG_CONTROL {
            AGAIN_1X    = 0x00, // 1X gain
            AGAIN_4X    = 0x01, // 4X gain
            AGAIN_16X   = 0x10, // 16X gain
            AGAIN_60X   = 0x11  // 60X gain
        }

        enum REG_STATUS {
            AVALID  = 0x01, // RGBC Valid. Indicates that the RGBC channels have completed an integration cycle.
            AINT    = 0x10  // RGBC clear channel interrupt
        }
    }

    // Set number of integration timeslots (0x00 - 0xFF = 2.4ms - 700ms)
    // Higher is more accurate, lower is faster
    function _setIntegrationTime(numslots) {
        if (numslots >= 0x00 && numslots <= 0xFF) {
            _i2c.write(_addr, format("%c%c", REGISTERS.ATIME, numslots));
        } else {
            server.error("Invalid parameter to _setIntegrationTime");
        }
    }

    function _read() {
        // Table to hold measured values
        local colorLevels = {}
        // Power on, then wait at least 2.4ms for warm-up
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.PON));
        imp.sleep(0.01);

        // Set integration time (determines accuracy vs. duration)
        _setIntegrationTime(DEFAULT_ATIME);

        // Start the measurement
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.AEN | REG_ENABLE.PON));

        // Prepare to read the status register to find out when the measurement completes
        _i2c.write(_addr, format("%c", REGISTERS.STATUS));

        // Block until measurement completes
        while ((_i2c.read(_addr, "", 1)[0] & REG_STATUS.AVALID) == 0) {}

        // Stop measurement
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.PON));

        // Read Clear, Red, Green, and Blue values
        _i2c.write(_addr, format("%c", TRANSACTION_TYPE.AUTO_INCREMENT << 5 | REGISTERS.CDATAL));
        local val = _i2c.read(_addr, "", 8);
        colorLevels.clear   <- (val[1].tointeger() << 8) | val[0].tointeger();
        colorLevels.red     <- (val[3].tointeger() << 8) | val[2].tointeger();
        colorLevels.green   <- (val[5].tointeger() << 8) | val[4].tointeger();
        colorLevels.blue    <- (val[7].tointeger() << 8) | val[6].tointeger();

        // Put sensor to sleep
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, 0x00));

        return colorLevels;
    }

    function getLux() {
        // Get new values
        local colorLevels = _read();
        // Calculate illuminance (from TAOS (now AMS) Designer's Notebook #25)
        return (-0.32466 * colorLevels.red) + (1.57837 * colorLevels.green) + (-0.73191 * colorLevels.blue);
    }
}