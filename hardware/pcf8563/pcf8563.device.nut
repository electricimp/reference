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

/* PCF8563 Real-Time Clock/Calendar
 * http://www.nxp.com/documents/data_sheet/PCF8563.pdf
 * Tom Byrne
 * tom@electricimp.com
 * 12/19/2013
 */
const CTRL_REG_1        = 0x00;
const CTRL_REG_2        = 0x01;
const VL_SEC_REG        = 0x02;
const MINS_REG          = 0x03;
const HOURS_REG         = 0x04;
const DAYS_REG          = 0x05;
const WKDAY_REG         = 0x06;
const CNTRY_MONTHS_REG  = 0x07;
const YEARS_REG         = 0x08;
const MINS_ALARM_REG    = 0x09;
const HOURS_ALARM_REG   = 0x0A;
const DAY_ALARM_REG     = 0x0B;
const WKDAY_ALARM_REG   = 0x0C;
const CLKOUT_CTRL_REG   = 0x0D;
const TIMER_CTRL_REG    = 0x0E;
const TIMER_REG         = 0x0F;
class pcf8563 {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr = 0xA2) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,register));
            return -1;
        }
        return data[0];
    }
    
    function writeReg(register,data) {
        _i2c.write(_addr, format("%c%c",register,data));
    }
    
    /* The first bit of the VL_SEC_REG is a Voltage Low flag (VL)
     * If this flag is set, the internal voltage detector has detected a 
     * low-voltage event and the clock integrity is not guaranteed. 
     * The flag remains set until it is manually cleared.
     * This is provided because the RTC is often run on a secondary cell 
     * or supercap as a backup.
     */
    function clkGood() {
        if (0x80 & readReg(VL_SEC_REG)) {
            return 0;
        }
        return 1;
    }
    
    /* Clear the Voltage Low flag. */
    function clearVL() {
        local data = 0x7F & readReg(VL_SEC_REG);
        this.writeReg(VL_SEC_REG, data);
    }
    
    function sec() {
        local data = readReg(VL_SEC_REG)
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function min() {
        local data = readReg(MINS_REG);
        return (((data & 0x70) >> 4) * 10 + (data & 0x0F));
    }
    
    function hour() {
        local data = readReg(HOURS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function day() {
        local data = readReg(DAYS_REG);
        return (((data & 0x30) >> 4) * 10 + (data & 0x0F));
    }
    
    function weekday() {
        return (readReg(WKDAY_REG) & 0x07);
    }
    
    function month() {
        local data = readReg(CNTRY_MONTHS_REG);
        return (((data & 0x10) >> 4) * 10 + (data & 0x0F));
    }
    
    function year() {
        local data = readReg(YEARS_REG);
        return (((data & 0xF0) >> 4) * 10 + (data & 0x0F));
    }
    
    /* 
     * Set the RTC to match the imp's RTC. 
     * Note that if the imp's RTC is off, this will not correct the imp. You 
     * will simply be left to two clocks that don't tell the correct time.
     * The imp's RTC is re-synced on server connect, so syncing right after a 
     * server connect is recommended.
     */
    function sync(setTime = null) {
        local now = date();
        if (setTime) { now = setTime; };
        local secStr = format("%02d",now.sec);
        local minStr = format("%02d",now.min);
        local hourStr = format("%02d",now.hour);
        local dayStr = format("%02d",now.day);
        local monStr = format("%02d",now.month+1);
        local yearStr = format("%02d",now.year).slice(2,4);
        local wkdayStr = format("%d",now.wday);
        
        this.writeReg(VL_SEC_REG,       (((secStr[0] & 0x07) << 4) + (secStr[1] & 0x0F)));
        this.writeReg(MINS_REG,         (((minStr[0] & 0x07) << 4) + (minStr[1] & 0x0F)));
        this.writeReg(HOURS_REG,        (((hourStr[0] & 0x03) << 4) + (hourStr[1] & 0x0F)));
        this.writeReg(DAYS_REG,         (((dayStr[0] & 0x03) << 4) + (dayStr[1] & 0x0F)));
        this.writeReg(CNTRY_MONTHS_REG, (((monStr[0] & 0x01) << 4) + (monStr[1] & 0x0F)));
        this.writeReg(YEARS_REG,        (((yearStr[0] & 0x0F) << 4) + (yearStr[1] & 0x0F)));
        this.writeReg(WKDAY_REG,        (secStr[0] & 0x07));
    }
}

/* RUNTIME BEGINS HERE =======================================================*/ 

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

// Configure the RTC
rtc <-  pcf8563(i2c);
//rtc.sync();
    
local now = date();

server.log(format("RTC Clock Integrity: %x",rtc.clkGood()));

server.log(format("Current Time %02d:%02d:%02d, %02d/%02d/%02d",now.hour,
        now.min,now.sec,now.month+1,now.day,now.year));

server.log(format("RTC Set to %02d:%02d:%02d, %02d/%02d/%02d",rtc.hour(),
    rtc.min(),rtc.sec(),rtc.month(),rtc.day(),rtc.year()));