// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
// LIS3DH Ultra-low Power 3-axis Accelerometer
// http://www.st.com/web/catalog/sense_power/FM89/SC444/PF250725


class LIS3DH {
    
    static TEMP_CFG_REG  = 0x1F;
    static CTRL_REG1     = 0x20;
    static CTRL_REG2     = 0x21;
    static CTRL_REG3     = 0x22;
    static CTRL_REG4     = 0x23;
    static CTRL_REG5     = 0x24;
    static CTRL_REG6     = 0x25;
    static OUT_X_L       = 0x28;
    static OUT_X_H       = 0x29;
    static OUT_Y_L       = 0x2A;
    static OUT_Y_H       = 0x2B;
    static OUT_Z_L       = 0x2C;
    static OUT_Z_H       = 0x2D;
    static INT1_CFG      = 0x30;
    static INT1_SRC      = 0x31;
    static INT1_THS      = 0x32;
    static INT1_DURATION = 0x33;
    static CLICK_CFG     = 0x38;
    static CLICK_SRC     = 0x39;
    static CLICK_THS     = 0x3A;
    static TIME_LIMIT    = 0x3B;
    static TIME_LATENCY  = 0x3C;
    static TIME_WINDOW   = 0x3D;
    static WHO_AM_I      = 0x0F;
    static FLAG_SEQ_READ = 0x80;
    
    _i2c = null;
    _addr = null;
    
    RANGE_ACCEL = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0x30) {
        _i2c = i2c;
        _addr = addr;

        init();
    }

    // -------------------------------------------------------------------------
    function init() {
        // set the full-scale range values so we can return measurements with units
        getRange(); // sets RANGE_ACCEL. Default +/- 2 G
    }
    
    // -------------------------------------------------------------------------
    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return value & mask;
    }
    
    // -------------------------------------------------------------------------
    function _getReg(reg) {
        local val = _i2c.read(_addr, format("%c", reg), 1);
        if (val != null) {
            return val[0];
        } else {
            return null;
        }
    }
    
    // -------------------------------------------------------------------------
    function _setReg(reg, val) {
        _i2c.write(_addr, format("%c%c", reg, (val & 0xff)));   
    }
    
    // -------------------------------------------------------------------------
    function _setRegBit(reg, bit, state) {
        local val = _getReg(reg);
        if (state == 0) {
            val = val & ~(0x01 << bit);
        } else {
            val = val | (0x01 << bit);
        }
        _setReg(reg, val);
    }
    
    function dumpRegs() {
        server.log(format("CTRL_REG1 0x%02X", _getReg(CTRL_REG1)));
        server.log(format("CTRL_REG2 0x%02X", _getReg(CTRL_REG2)));
        server.log(format("CTRL_REG3 0x%02X", _getReg(CTRL_REG3)));
        server.log(format("CTRL_REG4 0x%02X", _getReg(CTRL_REG4)));
        server.log(format("CTRL_REG5 0x%02X", _getReg(CTRL_REG5)));
        server.log(format("CTRL_REG6 0x%02X", _getReg(CTRL_REG6)));
        server.log(format("INT1_DURATION 0x%02X", _getReg(INT1_DURATION)));
        server.log(format("INT1_CFG 0x%02X", _getReg(INT1_CFG)));
        server.log(format("INT1_SRC 0x%02X", _getReg(INT1_SRC)));
        server.log(format("INT1_THS 0x%02X", _getReg(INT1_THS)));
    }
    
    // -------------------------------------------------------------------------
    function getDeviceId() {
        return _getReg(WHO_AM_I);
    }
    
    // -------------------------------------------------------------------------
    // Set Accelerometer Data Rate in Hz
    function setDatarate(rate) {
        local val = _getReg(CTRL_REG1) & 0x0F;
        if (rate == 0) {
            // 0b0000 -> power-down mode
            // we've already ANDed-out the top 4 bits; just write back
        } else if (rate <= 1) {
            val = val | 0x10; 
            rate = 1;
        } else if (rate <= 10) {
            val = val | 0x20;
            rate = 10;
        } else if (rate <= 25) {
            val = val | 0x30;
            rate = 25;
        } else if (rate <= 50) {
            val = val | 0x40;
            rate = 50;
        } else if (rate <= 100) {
            val = val | 0x50;
            rate = 100;
        } else if (rate <= 200) {
            val = val | 0x60;
            rate = 200;
        } else if (rate <= 400) {
            val = val | 0x70;
            rate = 400;
        } else if (rate <= 1600) {
            val = val | 0x80;
            rate = 1600;
        } else if (rate <= 5000) {
            val = val | 0x90;
            rate = 5000;
        } 
        _setReg(CTRL_REG1, val);
        return rate;
    }    
    // -------------------------------------------------------------------------
    // Enable/disable the accelerometer
    // sets all three axes
    function setEnable(state) {
        // CTRL_REG1 enables/disables accelerometer axes
        // bit 0 = X axis
        // bit 1 = Y axis
        // bit 2 = Z axis
        local val = _getReg(CTRL_REG1);
        if (state) { val = val | 0x07; }
        else { val = val & 0xF8; }
        _setReg(CTRL_REG1, val);
    }

    // -------------------------------------------------------------------------
    function setLowPower(state) {
        _setRegBit(CTRL_REG1, 3, state);
    }
    
    // -------------------------------------------------------------------------
    // set the full-scale range of the accelerometer
    // default full-scale range is +/- 2 G
    function setRange(range_a) {
        local val = _getReg(CTRL_REG2) & 0xC7;
        local range_bits = 0;
        if (range_a <= 2) {
            range_bits = 0x00;
            RANGE_ACCEL = 2;
        } else if (range_a <= 4) {
            range_bits = 0x01;
            RANGE_ACCEL = 4;
        } else if (range_a <= 6) {
            range_bits = 0x02;
            RANGE_ACCEL = 6;
        } else if (range_a <= 8) {
            range_bits = 0x03;
            RANGE_ACCEL = 8;
        } else {
            range_bits = 0x04;
            RANGE_ACCEL = 16;
        }
        _setReg(CTRL_REG2, val | (range_bits << 3));
        return RANGE_ACCEL;
    }

    // -------------------------------------------------------------------------
    // get the currently-set full-scale range of the accelerometer
    function getRange() {
        local range_bits = (_getReg(CTRL_REG2) & 0x38) >> 3;
        if (range_bits == 0x00) {
            RANGE_ACCEL = 2;
        } else if (range_bits = 0x01) {
            RANGE_ACCEL = 4;
        } else if (range_bits = 0x02) {
            RANGE_ACCEL = 6;
        } else if (range_bits = 0x03) {
            RANGE_ACCEL = 8;
        } else {
            RANGE_ACCEL = 16;
        }
        return RANGE_ACCEL;
    }
    
    // -------------------------------------------------------------------------
    // Read data from the Accelerometer
    // Returns a table {x: <data>, y: <data>, z: <data>}
    function getAccel() {
        local x_raw = (_getReg(OUT_X_H) << 8) + _getReg(OUT_X_L);
        local y_raw = (_getReg(OUT_Y_H) << 8) + _getReg(OUT_Y_L);
        local z_raw = (_getReg(OUT_Z_H) << 8) + _getReg(OUT_Z_L);

        //server.log(format("%02X, %02X, %02X",x_raw, y_raw, z_raw));
    
        local result = {};
        if (x_raw & 0x8000) {
            result.x <- (-1.0) * _twosComp(x_raw, 0xffff);
        } else {
            result.x <- x_raw;
        }
        
        if (y_raw & 0x8000) {
            result.y <- (-1.0) * _twosComp(y_raw, 0xffff);
        } else {
            result.y <- y_raw;
        }
        
        if (z_raw & 0x8000) {
            result.z <- (-1.0) * _twosComp(z_raw, 0xffff);
        } else {
            result.z <- z_raw;
        }

        // multiply by full-scale range to return in G
        result.x = (result.x / 32000.0) * RANGE_ACCEL;
        result.y = (result.y / 32000.0) * RANGE_ACCEL;
        result.z = (result.z / 32000.0) * RANGE_ACCEL;
        
        return result;
    }   
    
    // -------------------------------------------------------------------------
    // enable / disable single-click detection
    function setSnglclickIntEn(state) {
        _setRegBit(CTRL_REG3, 6, state);
        // bit 4 = Z axis
        // bit 2 = Y axis
        // bit 0 = X axis
        local val = _getReg(CLICK_CFG);
        if (state) { val = val | 0x15; }
        else { val & 0xEA; }
        _setReg(CLICK_CFG, val);
    }

    // -------------------------------------------------------------------------
    // enable / disable double-click detection
    function setDblclickIntEn(state) {
        _setRegBit(CTRL_REG3, 6, state);
        // bit 5 = Z axis
        // bit 3 = Y axis
        // bit 1 = X axis
        local val = _getReg(CLICK_CFG);
        if (state) { val = val | 0x2A; }
        else { val & 0xD5; }
        _setReg(CLICK_CFG, val)
    }
    
    // -------------------------------------------------------------------------
    // Enable/Disable Inertial Interrupt Generator 1 on Interrupt Pin
    function setInertInt1En(state) {
        _setRegBit(CTRL_REG3, 6, state);
        // enable inertial interrupts on X High, Y High, Z high
        _setReg(INT1_CFG, _getReg(INT1_CFG) | 0x2A);
    }
    
    // -------------------------------------------------------------------------
    // Enable Free Fall Detection on Int1
    // use setInertInt1En(0) to disable
    function setFreeFallDetInt1() {
        _setRegBit(CTRL_REG3, 6, state);
        // enable interrupt on X low, Y low, Z low
        _setReg(INT1_CFG, 0x95);
        // set threshold; this can be overridden
        setInt1Ths(0.35);
    }
    
    // -------------------------------------------------------------------------
    // Enable/Disable Data Ready Interrupt 1 on Interrupt Pin
    function setDrdyInt1En(state) {
        _setRegBit(CTRL_REG3, 4, state);
    }
    
    // -------------------------------------------------------------------------
    // enable/disable global interrupt latching 
    // if set, clear interrupt by reading INT1_SRC
    function setIntLatch(state) {
        _setRegBit(CTRL_REG5, 1, state);
    }
    
    // -------------------------------------------------------------------------
    // read the INT_GEN_1_SRC register to determine what threw an interrupt on generator 1
    function getInt1Src() {
        return _getReg(INT1_SRC);
    }

    // -------------------------------------------------------------------------
    // set the accelerometer threshold value interrupt 1
    // threshold is set in G
    // the provided threshold value is multiplied by the current accelerometer range to 
    // calculate the value for the threshold register
    // set the range before setting the threshold
    function setInt1Ths(ths) {
        if (ths < 0) { ths = ths * -1.0; }
        ths = (((ths * 1.0) / (RANGE_ACCEL * 1.0)) * 127).tointeger();
        if (ths > 0xffff) { ths = 0xffff; }
        _setReg(INT1_THS, (ths & 0x7f));
    }
    
    // -------------------------------------------------------------------------
    // set the event duration over threshold before throwing interrupt
    // duration steps and max values depend on selected ODR
    function setInt1Duration(numsamples) {
        _setReg(INT1_DURATION, numsamples & 0x7f);
    }
    
    // -------------------------------------------------------------------------
    // set the Click Threshold in Gs
    function setClickThs(ths) {
        ths = (((ths * 1.0) / (RANGE_ACCEL * 1.0)) * 127).tointeger();
        _setReg(CLICK_THS, ths);
    }
    
    // -------------------------------------------------------------------------
    // set Click Detect Time Limit (ms?)
    function setClickTimeLimit(time) {
        _setReg(TIME_LIMIT, time);
    }
    
    // -------------------------------------------------------------------------
    // set double-click max latency (ms?)
    function setClickLatency(time) {
        _setReg(TIME_LATENCY, time);
    }
    
    // -------------------------------------------------------------------------
    function clickIntActive() {
        return (0x40 & _getReg(CLICK_SRC)); 
    }
    
    // -------------------------------------------------------------------------
    function dblclickDet() {
        return (0x20 & _getReg(CLICK_SRC)); 
    }
    
    // -------------------------------------------------------------------------
    function snglclickDet() {
        return (0x10 & _getReg(CLICK_SRC)); 
    }         
}