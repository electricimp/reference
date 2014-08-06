// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// I2C EEPROM, Microchip 24FC Family
// http://ww1.microchip.com/downloads/en/DeviceDoc/21754M.pdf
const PAGE_LEN = 128; // 128-byte pages
const WRITE_TIME = 0.005; // 5 ms page write limit

class Eeprom24FC {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr=0xA0) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function read(len, offset) {
        // "Random Read": write the offset, then read
        local data = _i2c.read(_addr, format("%c%c", (offset & 0xFF00) >> 8, offset & 0xff), len);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",_addr,offset));
            return -1;
        }
        return data;
    }
    
    function write(data, offset) {
        local dataIndex = 0;
        
        while(dataIndex < data.len()) {
            // chunk of data we will send per I2C write. Can be up to 1 page long.
            local chunk = format("%c%c",(offset & 0xFF00) >> 8, offset & 0xff);
            // check if this is the first page, and if we'll hit the boundary
            local leftOnPage = PAGE_LEN - (offset % PAGE_LEN);
            // set the chunk length equal to the space left on the page
            local chunkLen = leftOnPage;
            // check if this is the last page we need to write, and adjust the chunk size if it is
            if ((data.len() - dataIndex) < leftOnPage) { chunkLen = (data.len() - dataIndex); }
            // now fill the chunk with a slice of data and write it
            for (local chunkIndex = 0; chunkIndex < chunkLen; chunkIndex++) {
                chunk += format("%c",data[dataIndex++]);  
            }
            _i2c.write(_addr, chunk);
            offset += chunkLen;
            // write takes a finite (and rather long) amount of time. Subsequent writes
            // before the write cycle is completed fail silently. You must wait.
            imp.sleep(WRITE_TIME);
        }
    }
}
