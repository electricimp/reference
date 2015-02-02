// Air Pressure Sensor LPS25H
// http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf
class LPS25H {
    static MEAS_TIME = 0.5; // seconds; time to complete pressure conversion
    _i2c        = null;
    _addr       = null;

    _referencePressure = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
        
        init();
    }

    // -------------------------------------------------------------------------    
    function init() {
        enum LPS25H_REG {
            REF_P_XL        = 0x08,
            REF_P_L         = 0X09,
            REF_P_H         = 0x0A,
            WHO_AM_I        = 0x0F,
            RES_CONF        = 0x10,
            CTRL_REG1       = 0x20,
            CTRL_REG2       = 0x21,
            CTRL_REG3       = 0x22,
            CTRL_REG4       = 0x23,
            INT_CFG         = 0x24,
            INT_SOURCE      = 0x25,
            STATUS_REG      = 0x27,
            PRESS_OUT_XL    = 0x28,
            PRESS_OUT_L     = 0x29,
            PRESS_OUT_H     = 0x2A,
            TEMP_OUT_L      = 0x2B,
            TEMP_OUT_H      = 0x2C,
            FIFO_CTRL       = 0x2E,
            FIFO_STATUS     = 0x2F,
            THS_P_L         = 0x30,
            THS_P_H         = 0x31,
            RPDS_L          = 0x39,
            RPDS_H          = 0x3A
        }

        enable(1);
        _referencePressure = getReferencePressure();
        enable(0);
    }
    
    // -------------------------------------------------------------------------
    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return -1 * (value & mask);
    }

    // -------------------------------------------------------------------------    
    function _readI2C(reg, numBytes) {
        local result = _i2c.read(_addr, reg.tochar(), numBytes);
        if (result == null) {
            server.error("I2C read error: " + _i2c.readerror());
        }
        return result;
    }

    // -------------------------------------------------------------------------    
    function _writeI2C(reg, ...) {
        local s = reg.tochar();
        foreach (b in vargv) {
            s += b.tochar();
        }
        local result = _i2c.write(_addr, s);
        if (result) {
            server.error("I2C write error: " + result);
        }
        return result;
    }

    // -------------------------------------------------------------------------    
    function getDeviceID() {
        return _readI2C(LPS25H_REG.WHO_AM_I, 1);
    }

    // -------------------------------------------------------------------------        
    function enable(state) {
        local val = _readI2C(LPS25H_REG.CTRL_REG1, 1)[0];
        if (state) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        _writeI2C(LPS25H_REG.CTRL_REG1, val);
    }
  
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function setPressNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            npts = 0x02;
        } else {
            // Average 512 readings
            npts = 0x03;
        }
        local val = _readI2C(LPS25H_REG.RES_CONF, 1)[0];
        local res = _writeI2C(LPS25H_REG.RES_CONF, (val & 0xFC) | npts);
    }    
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function setTempNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x02;
        } else {
            // Average 64 readings
            npts = 0x03;
        }
        local val = _readI2C(LPS25H_REG.RES_CONF, 1);
        local res = _writeI2C(LPS25H_REG.RES_CONF, (val & 0xF3) | (npts << 2));
    }    

    // -------------------------------------------------------------------------
    function setIntEnable(state) {
        local val = _readI2C(LPS25H_REG.CTRL_REG1, 1)[0];
        if (state) {
            val = val | 0x08;
        } else {
            val = val & 0xF7; 
        }
        local res = _writeI2C(LPS25H_REG.CTRL_REG1, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setFifoEnable(state) {
        local val = _readI2C(LPS25H_REG.CTRL_REG2, 1)[0];
        if (state) {
            val = val | 0x40; 
        } else {
            val = val & 0xAF;
        }
        local res = _writeI2C(LPS25H_REG.CTRL_REG2, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function softReset(state) {
        local res = _writeI2C(LPS25H_REG.CTRL_REG2, 0x04);
    }
    
    // -------------------------------------------------------------------------
    function setIntActivehigh(state) {
        local val = _readI2C(LPS25H_REG.CTRL_REG3, 1)[0];
        if (state) {
            val = val & 0x7F;
        } else {
            val = val | 0x80;
        }
        local res = _writeI2C(LPS25H_REG.CTRL_REG3, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setIntPushpull(state) {
        local val = _readI2C(LPS25H_REG.CTRL_REG3, 1)[0];
        if (state) {
            val = val & 0xBF;
        } else {
            val = val | 0x40;
        }
        local res = _writeI2C(LPS25H_REG.CTRL_REG3, val & 0xFF);
    }
    
    // -------------------------------------------------------------------------
    function setIntConfig(latch, diff_press_low, diff_press_high) {
        local val = _readI2C(LPS25H_REG.CTRL_REG1, 1)[0];
        if (latch) {
            val = val | 0x04; 
        } 
        if (diff_press_low) {
            val = val & 0x02;
        }
        if (diff_press_high) {
            val = val | 0x01;
        }
        local res = _writeI2C(LPS25H_REG.CTRL_REG1, val & 0xFF);
    }    
    
    // -------------------------------------------------------------------------
    function setPressThresh(press_thresh) {
        _writeI2C(LPS25H.THS_P_H, (press_thresh & 0xff00) >> 8);
        _writeI2C(LPS25H.THS_P_L, press_thresh & 0xff);
    }  
    
    // -------------------------------------------------------------------------        
    function getReferencePressure() {
        local low   = _readI2C(LPS25H_REG.REF_P_XL, 1);
        local mid   = _readI2C(LPS25H_REG.REF_P_L, 1);
        local high  = _readI2C(LPS25H_REG.REF_P_H, 1);
        return ((high[0] << 16) | (mid[0] << 8) | low[0]);
    }

    // -------------------------------------------------------------------------
    // Returns raw pressure register values
    function getRawPressure() {
        local low   = _readI2C(LPS25H_REG.PRESS_OUT_XL, 1);
        local mid   = _readI2C(LPS25H_REG.PRESS_OUT_L, 1);
        local high  = _readI2C(LPS25H_REG.PRESS_OUT_H, 1);
        return ((high[0] << 16) | (mid[0] << 8) | low[0]);
    }
    
    // -------------------------------------------------------------------------
    function read(cb = null) {
        if (!cb) {
            server.error("LPS25H read requires a callback function.")
            return null;
        }
        // Start a one-shot measurement
        _writeI2C(LPS25H_REG.CTRL_REG2, 0x01);
        // Read the reference pressure
        local referencePressure = getReferencePressure();
        // Get pressure in HPa
        imp.wakeup(MEAS_TIME, function() {
            local pressure = (getRawPressure() - referencePressure) / 4096.0;
            cb(pressure);
        }.bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    function getTemp() {
        enable(1);
        local temp_l = _readI2C(LPS25H_REG.TEMP_OUT_L, 1)[0];
        local temp_h = _readI2C(LPS25H_REG.TEMP_OUT_H, 1)[0];
        enable(0);
        
        local temp_raw = (temp_h << 8) | temp_l;
        if (temp_raw & 0x8000) {
            temp_raw = _twosComp(temp_raw, 0xFFFF);
        }
        return (42.5 + (temp_raw / 480.0));
    }
}