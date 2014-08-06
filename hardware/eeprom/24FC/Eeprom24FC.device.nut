// I2C EEPROM, Microchip 24FC Family
// http://ww1.microchip.com/downloads/en/DeviceDoc/21754M.pdf
const PAGE_LEN = 128; // 128-byte pages
const WRITE_TIME = 0.005; // 5 ms page write limit
class Eeprom24FC {
    i2c = null;
    addr = null;
    SIZE = null;
    CHUNKSIZE = 8192;
    
    constructor(_i2c, _wp = null, _size = null, _addr = 0xA0) {
        i2c = _i2c;
        addr = _addr;
        wp = _wp;
        SIZE = _size;
    }
    
    function read(len, offset) {
        // "Random Read": write the offset, then read
        local data = i2c.read(addr, format("%c%c", (offset & 0xFF00) >> 8, offset & 0xff), len);
        if (data == null) {
            server.error(format("I2C Read Failure. Device: 0x%02x Register: 0x%02x",addr,offset));
            return -1;
        }
        return data;
    }
    
    function write(data, offset) {
        local dataIndex = 0;
        if (wp) { wp.write(0); }
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
            i2c.write(addr, chunk);
            offset += chunkLen;
            // write takes a finite (and rather long) amount of time. Subsequent writes
            // before the write cycle is completed fail silently. You must wait.
            imp.sleep(WRITE_TIME);
        }
        if (wp) { wp.write(1) };
    }
    
    // write entire EEPROM to 0x00
    // Input: None
    // Return: None
    function chipErase() {
        local zerobuffer = blob(CHUNKSIZE);
        local numchunks = SIZE / CHUNKSIZE;
        while (!zerobuffer.eos()) {
            zerobuffer.writen(0x00000000,'i');
        }
        wp.configure(DIGITAL_OUT);
        wp.write(0);
        for (local i = 0; i < numchunks; i++) {
            write(zerobuffer, i * CHUNKSIZE);
            server.log(((i + 1) * CHUNKSIZE)+"/"+(numchunks * CHUNKSIZE)+" bytes erased");
        }
        wp.configure(DIGITAL_IN);
    }
}