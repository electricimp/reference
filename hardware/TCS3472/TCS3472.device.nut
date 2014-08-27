// Color sensor
class TCS3472 {

    _i2c  = null;
    _addr = null;
    _enableValue = null;

    constructor(i2c, address) {
        _i2c  = i2c;
        _addr = address;
        _enableValue = 0x00;
        _init();
    }

    function _init() {

        // Each datasheet address is ORed with 0x80 to select the command register,
        enum REGISTERS {
            ENABLE  = 0x80, // Enables states and interrupts
            ATIME   = 0x81, // RGBC time
            WTIME   = 0x83, // Wait time
            AILTL   = 0x84, // 'Clear' interrupt: low threshold, low byte
            AILTH   = 0x85, // 'Clear' interrupt: low threshold, high byte
            AIHTL   = 0x86, // 'Clear' interrupt: high threshold, low byte
            AIHTH   = 0x87, // 'Clear' interrupt: high threshold, high byte
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
            AUTO_INCREMENT  = 0x20, // This mode increments the target register every read to save time
            CLEAR_INTERRUPT = 0xE6  // Clear the interrupt flag (not supported)
        }

        enum REG_ENABLE {
            AIEN    = 0x10, // RGBC interrupt enable. When asserted, permits RGBC interrupts to be generated. (not supported)
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
            AINT    = 0x10  // RGBC clear channel interrupt (not supported)
        }

        sleep();
    }

    // If sensor is asleep, wake it up/read values/put it to sleep. If already awake, just read values.
    // Returns: table with entries 'clr', 'red', 'green', 'blue' that contain 16-bit integers
    function read() {
        // Table to hold measured values
        local colorLevels = {}
        local wasAsleep = !(_enableValue & REG_ENABLE.PON);
        if (wasAsleep) {
            wake();
        }

        // Prepare to read the status register to find out when the measurement completes
        _i2c.write(_addr, format("%c", REGISTERS.STATUS));  

        // Block until measurement completes
        while ((_i2c.read(_addr, "", 1)[0] & REG_STATUS.AVALID) == 0) {}

        // Read Clear, Red, Green, and Blue values
        _i2c.write(_addr, format("%c", TRANSACTION_TYPE.AUTO_INCREMENT | REGISTERS.CDATAL));
        local val = _i2c.read(_addr, "", 8);
        colorLevels.clr     <- (val[1].tointeger() << 8) | val[0].tointeger();
        colorLevels.red     <- (val[3].tointeger() << 8) | val[2].tointeger();
        colorLevels.green   <- (val[5].tointeger() << 8) | val[4].tointeger();
        colorLevels.blue    <- (val[7].tointeger() << 8) | val[6].tointeger();

        if (wasAsleep) {
            sleep();
        }

        return colorLevels;
    }

    function wake() {
        _enableValue = _enableValue | REG_ENABLE.PON;
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, _enableValue));
        imp.sleep(0.0024);
        _enableValue = _enableValue | REG_ENABLE.AEN;
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, _enableValue));
    }

    function sleep() {
        _enableValue = _enableValue & ~REG_ENABLE.PON & ~REG_ENABLE.AEN;
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, _enableValue));
    }

    // Set number of integration timeslots (0x00 - 0xFF = 2.4ms - 700ms)
    // Higher is more accurate, lower is faster
    function setIntegrationTime(numslots) {
        if (numslots >= 0x00 && numslots <= 0xFF) {
            _i2c.write(_addr, format("%c%c", REGISTERS.ATIME, numslots));
        } else {
            server.error("Invalid parameter to setIntegrationTime");
        }
    }

    // Sets wait time WTIME (1 - 256 steps, 2.4ms/step)
    function setWaitTime(waitTime) {
        if (waitTime >= 0x00 && waitTime <= 0xFF) {
            _i2c.write(_addr, format("%c%c", REGISTERS.WTIME, waitTime));
        }
    }

    // Interrupt persistence
    // function setPersistence(ptime) {
    //     if (ptime >= 0x00 && ptime <= 0xFF) {
    //         _i2c.write(_addr, format("%c%c", REGISTERS.PERS, ptime));
    //     }
    // }

    // Enable interrupt generation and sensor reading when awake (not supported)
    // function enableInterrupt() {
    //     clearInterrupt();
    //     _enableValue = _enableValue | REG_ENABLE.AIEN | REG_ENABLE.AEN;
    //     _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, _enableValue));
    // }

    // Disable interrupt generation (not supported)
    // function disableInterrupt() {
    //     _enableValue = _enableValue & ~REG_ENABLE.AIEN & ~REG_ENABLE.AEN;
    //     _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, _enableValue));
    // }

    // function clearInterrupt() {
    //     _i2c.write(_addr, format("%c", TRANSACTION_TYPE.CLEAR_INTERRUPT));
    // }

    // Set low threshold for clear channel to generate an interrupt (not supported)
    // function setIntLowThreshold(threshold) {
    //     if (threshold >= 0x00 && threshold <= 0xFFFF) {
    //         _i2c.write(_addr, format("%c%c", REGISTERS.AILTL, threshold & 0xFF));
    //         _i2c.write(_addr, format("%c%c", REGISTERS.AILTH, (threshold>>8) & 0xFF));
    //     } else {
    //         server.error("Invalid parameter to setIntLowThreshold");
    //     }
    // }

    // Set high threshold for clear channel to generate an interrupt (not supported)
    // function setIntHighThreshold(threshold) {
    //     if (threshold >= 0x00 && threshold <= 0xFFFF) {
    //         _i2c.write(_addr, format("%c%c", REGISTERS.AIHTL, threshold & 0xFF));
    //         _i2c.write(_addr, format("%c%c", REGISTERS.AIHTH, (threshold>>8) & 0xFF));
    //     } else {
    //         server.error("Invalid parameter to setIntHighThreshold");
    //     }
    // }

    // Read sensor and return light level in Lux
    function getLux() {
        // Get new values
        local colorLevels = read();
        // Calculate illuminance (from TAOS (now AMS) Designer's Notebook #25)
        return (-0.32466 * colorLevels.red) + (1.57837 * colorLevels.green) + (-0.73191 * colorLevels.blue);
    }

    function readRegister(reg) {
        _i2c.write(_addr, format("%c", reg));
        server.log(format("reg 0x%02X: 0x%02X", reg, _i2c.read(_addr, "", 1)[0]));
    }

}