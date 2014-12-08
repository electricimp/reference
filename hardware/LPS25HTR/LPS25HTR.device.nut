class LPS25HTR {

    // Air Pressure Sensor LPS25HTR
    // http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf

	// Copyright 2014 Electric Imp
	// Issued under the MIT license (MIT)

	// Permission is hereby granted, free of charge, to any person obtaining a copy
	// of this software and associated documentation files (the "Software"), to deal
	// in the Software without restriction, including without limitation the rights
	// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	// copies of the Software, and to permit persons to whom the Software is
	// furnished to do so, subject to the following conditions:
	// 	The above copyright notice and this permission notice shall be included in
	// 	all copies or substantial portions of the Software.

	// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	// THE SOFTWARE.

    static REF_P_XL     = 0x08;
    static REF_P_L      = 0x09;
    static REF_P_H      = 0x0A;
    static WHO_AM_I     = 0x0F;
    static CTRL_REG1    = 0x20;
    static CTRL_REG2    = 0x21;
    static CTRL_REG3    = 0x22;
    static CTRL_REG4    = 0x23;
    static INT_CFG      = 0x24;
    static INT_SRC      = 0x25;
    static STATUS_REG   = 0x27;
    static PRESS_POUT_XL = 0x28;
    static PRESS_OUT_L  = 0x29;
    static PRESS_OUT_H  = 0x2A;
    static TEMP_OUT_L   = 0x2B;
    static TEMP_OUT_H   = 0x2C;
    static FIFO_CTRL    = 0x2E;
    static FIFO_STATUS  = 0x2F;
    static THS_P_L     = 0x30;
    static THS_P_H     = 0x31;
    static RPDS_L       = 0x39;
    static RPDS_H       = 0x3A;
    
    _i2c        = null;
    _addr       = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
    }
    
    // -------------------------------------------------------------------------
    function twos_comp(value, mask) {
        value = ~(value & mask) + 1;
        return value & mask;
    }

    // -------------------------------------------------------------------------
    function get_device_id() {
        return _i2c.read(_addr, WHO_AM_I, 1);
    }
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function set_press_npts(npts) {
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
        local val = _i2c.read(_addr, RES_CONF, 1);
        val = ((val & 0xFC) | npts);
        _i2c.write(_addr, format("%c%c",RES_CONF, val & 0xff));
    }    
    
    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function set_temp_npts(npts) {
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
        local val = _i2c.read(_addr, RES_CONF, 1);
        val = (val & 0xF3) | (npts << 2);
        _i2c.write(_addr, format("%c%c",RES_CONF, val & 0xff));
    }    

    // -------------------------------------------------------------------------
    function set_power_state(state) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (state == 0) {
            val = val & 0x7F; 
        } else {
            val = val | 0x80;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG1, val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_enable(state) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (state == 0) {
            val = val & 0xF7; 
        } else {
            val = val | 0x08;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG1, val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_fifo_enable(state) {
        local val = _i2c.read(_addr, CTRL_REG2, 1);
        if (state == 0) {
            val = val & 0xAF; 
        } else {
            val = val | 0x40;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG2, val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function soft_reset(state) {
        _i2c.write(_addr, format("%c%c", CTRL_REG2, 0x04));
    }
    
    // -------------------------------------------------------------------------
    function set_int_activehigh(state) {
        local val = _i2c.read(_addr, CTRL_REG3, 1);
        if (state == 0) {
            val = val | 0x80; 
        } else {
            val = val & 0x7F;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG3, val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_pushpull(state) {
        local val = _i2c.read(_addr, CTRL_REG3, 1);
        if (state == 0) {
            val = val | 0x40; 
        } else {
            val = val & 0xBF;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG3, val & 0xff));
    }
    
    // -------------------------------------------------------------------------
    function set_int_config(latch, diff_press_low, diff_press_high) {
        local val = _i2c.read(_addr, CTRL_REG1, 1);
        if (latch) {
            val = val | 0x04; 
        } 
        if (diff_press_low) {
            val = val & 0x02;
        }
        if (diff_press_high) {
            val = val | 0x01;
        }
        _i2c.write(_addr, format("%c%c", CTRL_REG1, val & 0xff));
    }    
    
    // -------------------------------------------------------------------------
    function set_press_thresh(press_thresh) {
        _i2c.write(_addr, format("%c%c", THS_P_H, (press_thresh & 0xff00) >> 8));
        _i2c.write(_addr, format("%c%c", THS_P_L, (press_thresh & 0xff)));
    }  
    
    // -------------------------------------------------------------------------
    // Returns Pressure in hPa
    function read_pressure_hPa() {
        local press_xl = _i2c.read(_addr, PRESS_OUT_XL, 1);
        local press_l = _i2c.read(_addr, PRESS_OUT_L, 1);
        local press_h = _i2c.read(_addr, PRESS_OUT_H, 1);
        
        return (((press_h << 16) + (press_l << 8) + press_xl) / 4096);
    }
    
    // -------------------------------------------------------------------------
    // Returns Pressure in kPa
    function read_pressure_kPa() {    
        return read_pressure_hPa() / 10.0;
    }

    
    // -------------------------------------------------------------------------
    // Returns Pressure in inches of Hg
    function read_pressure_inHg() {    
        return read_pressure_hPa * 0.0295333727;
    }    
    
    // -------------------------------------------------------------------------
    function read_temp() {
        local temp_l = _i2c.read(_addr, TEMP_OUT_L, 1);
        local temp_h = _i2c.read(_addr, TEMP_OUT_H, 1);
        
        return (42.5 * (((temp_l << 8) + temp_xl) / 480.0));
    }
}
