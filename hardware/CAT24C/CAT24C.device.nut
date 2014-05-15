//Copyright (C) 2014 electric imp, inc.
//
//I2C EEPROM, CAT24C Family
// http://www.onsemi.com/pub_link/Collateral/CAT24C02-D.PDF
const PAGE_LEN = 16;        // page length in bytes
const WRITE_TIME = 0.005;   // max write cycle time in seconds
class CAT24C {
    _i2c = null;
    _addr = null;
    
    constructor(i2c, addr=0xA0) {
        _i2c = i2c;
        _addr = addr;
    }
    
    function read(len, offset) {
        // "Selective Read" by preceding the read with a "dummy write" of just the offset (no data)
        _i2c.write(_addr, format("%c",offset));
    
        local data = _i2c.read(_addr, "", len);
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
            local chunk = format("%c",offset);
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

/* RUNTIME BEGINS HERE =======================================================*/ 

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
// Configure the EEPROM
eeprom <- CAT24C(i2c);
// write some test data
local testStr = "Electric Imp!";
// write the string to the eepromm, starting at offset 0
eeprom.write(testStr,0);
server.log("Read Back: "+eeprom.read(testStr.len(),0));
