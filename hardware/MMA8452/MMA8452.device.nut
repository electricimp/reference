// MMA8452 Accelerometer
class MMA8452 {

    static DEFAULT_ADDR = 0x3A; // 0x1D << 1

    _i2c    = null;
    _addr   = null;
    _fs     = null;

    constructor(i2c, addr=null) {

        // Set the address or use the default
        if (addr) {
            _addr = addr;
        } else {
            _addr = DEFAULT_ADDR;
        }

        // Configure i2c
        _i2c = i2c;
        _i2c.configure(CLOCK_SPEED_400_KHZ);

        // Assume range is 2g at boot
        _fs = 2;

        _init();

    }

    function _init() {

        enum REGISTERS {
            STATUS          = "\x00",
            OUT_X_MSB       = "\x01",
            OUT_X_LSB       = "\x02",
            OUT_Y_MSB       = "\x03",
            OUT_Y_LSB       = "\x04",
            OUT_Z_MSB       = "\x05",
            OUT_Z_LSB       = "\x06",
            SYSMOD          = "\x0B",
            INT_SOURCE      = "\x0C",
            WHO_AM_I        = "\x0D",
            XYZ_DATA_CFG    = "\x0E",
            HP_FILTER_CUTOFF= "\x0F",
            PL_STATUS       = "\x10",
            PL_CFG          = "\x11",
            PL_COUNT        = "\x12",
            PL_BF_ZCOMP     = "\x13",
            P_L_THS_REG     = "\x14",
            FF_MT_CFG       = "\x15",
            FF_MT_SRC       = "\x16",
            FF_MT_THS       = "\x17",
            FF_MT_COUNT     = "\x18",
            TRANSIENT_CFG   = "\x1D",
            TRANSIENT_SRC   = "\x1E",
            TRANSIENT_THS   = "\x1F",
            TRANSIENT_COUNT = "\x20",
            PULSE_CFG       = "\x21",
            PULSE_SRC       = "\x22",
            PULSE_THSX      = "\x23",
            PULSE_THSY      = "\x24",
            PULSE_THSZ      = "\x25",
            PULSE_TMLT      = "\x26",
            PULSE_LTCY      = "\x27",
            PULSE_WIND      = "\x28",
            ASLP_COUNT      = "\x29",
            CTRL_REG1       = "\x2A",
            CTRL_REG2       = "\x2B",
            CTRL_REG3       = "\x2C",
            CTRL_REG4       = "\x2D",
            CTRL_REG5       = "\x2E",
            OFF_X           = "\x2F",
            OFF_Y           = "\x30",
            OFF_Z           = "\x31"
        }
    }

    function wake() {
        local reg = blob(1);
        reg.writestring(_i2c.read(_addr, REGISTERS.CTRL_REG1, 1));
        _i2c.write(_addr, format("%s%c", REGISTERS.CTRL_REG1, reg[0] | 0x01));
    }

    function sleep() {
        local reg = blob(1);
        reg.writestring(_i2c.read(_addr, REGISTERS.CTRL_REG1, 1));
        _i2c.write(_addr, format("%s%c", REGISTERS.CTRL_REG1, reg[0] & 0xFE));
    }

    function read() {
        // Reads the status register + 3x 2-byte data registers
        local reg = blob(7);
        reg.writestring(_i2c.read(_addr, REGISTERS.STATUS, 7));
        local data = {
            x = (reg[1] << 4) | (reg[2] >> 4),
            y = (reg[3] << 4) | (reg[4] >> 4),
            z = (reg[5] << 4) | (reg[6] >> 4)
        }
        // Convert from two's compliment
        if (data.x & 0x800) { data.x -= 0x1000; }
        if (data.y & 0x800) { data.y -= 0x1000; }
        if (data.z & 0x800) { data.z -= 0x1000; }
        // server.log(format("Status: 0x%02X", reg[0]));
        return data;
    }

    function readG() {
        local data = read();
        data.x = data.x * _fs / 2048.0;
        data.y = data.y * _fs / 2048.0;
        data.z = data.z * _fs / 2048.0;
        return data;
    }
}

// Demo code
function readAccel() {
    local data = accel.read();
    server.log(format("x = %i, y = %i, z = %i", data.x, data.y, data.z));
    imp.wakeup(1, readAccel);
}

function readAccelG() {
    local data = accel.readG();
    server.log(format("x = %.02f, y = %.02f, z = %.02f", data.x, data.y, data.z));
    imp.wakeup(1, readAccelG);
}

accel <- MMA8452(hardware.i2c89);
accel.wake();

readAccelG();
