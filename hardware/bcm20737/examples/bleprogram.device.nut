// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

/* GLOBALS AND CONSTS --------------------------------------------------------*/
const BLOCKSIZE = 8192;
const EEPROMSIZE = 65536; // 64K (512kbit) EEPROM

/* CLASS DEFINITIONS ---------------------------------------------------------*/

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

// Broadcom Bluetooth LE SOC
// See Broadcom "WICED Smart" Documentation
// http://www.broadcom.com/products/wiced/smart/
// This class encapuslates reprogramming the "WICED Smart" module by holding it in reset
// and re-writing its image on EEPROM or SPI FLASH
class BCM20737 {
    // external memory for device contains at minimum a static section and a dynamic section
    // may contain two static sections
    // if provided image does not include a static section (e.g. over-the-air upgrade images), 
    // fall back on this known static section image
    static SS_IMG = "\x01\x08\x00\xF0\x00\x00\x62\x08\xC0\x5D\x89\xFD\x04\x00\xFF\xFF\xFF\xFF\x40\x06\x00\xA2\x19\x17\x7A\x73\x20\x02\x0A\x00\x80\x05\x00\x00\x40\x01\x00\x00\x00\x04";
    static DS1_OFFSET = 0x0580;
    static DS2_OFFSET = 0x8000;
    static SS1_OFFSET = 0x0000;
    static SS2_OFFSET = 0x0100;
    static SS_LEN = 40; // bytes
    
    eeprom = null;
    spi_flash = null;
    rst_l = null;
    mem_size = null;
    block_size = null;
    ext_mem = null;
    
    // pass in pre-constructed objects:
    // EEPROM *or* SPI_FLASH: use NULL for whichever is *not* used
    // rst_l: imp pin object
    // mem_size: size of EEPROM or SPI Flash in bytes
    // block_size: size of memory blocks to relay with agent, in bytes
    constructor(_eeprom, _spi_flash, _rst_l, _mem_size, _block_size) {
        if (eeprom != null && spi_flash != null) { throw "BCM20737: pass in EEPROM *or* SPI FLASH, use null for the storage medium not present"; }

        eeprom = _eeprom;
        spi_flash = _spi_flash;
        rst_l = _rst_l;
        mem_size = _mem_size;
        block_size = _block_size;
        
        if (eeprom != null) {
            ext_mem = eeprom;
        } else if (spi_flash != null) {
            ext_mem = spi_flash;
        } else {
            throw "Must provide valid EEPROM or SPI FLASH object for BCM23037 external memory";
        }
    }
    
    function reset() {
        rst_l.configure(DIGITAL_OUT);
        rst_l.write(0);
        imp.sleep(0.001);
        rst_l.configure(DIGITAL_IN);
    }
    
    // Dump the full external memory
    // Input: callback function, takes one argument (table, two fields:
    //      idx: buffer index
    //      buffer: data buffer)
    // Return: None
    function dumpExtMemory(newDataCallback) {
        local numchunks = mem_size / block_size;
        // Hold BLE chip in reset
        rst_l.configure(DIGITAL_OUT);
        rst_l.write(0);
        for (local i = 0; i < numchunks; i++) {
            local buffer = blob(block_size);
            buffer.writestring(ext_mem.read(block_size, i * block_size));
            newDataCallback({idx = i, buffer = buffer});
        } 
        // Release
        rst_l.configure(DIGITAL_IN);
    }
    
    // Helper: holds BCM in reset and wraps chip erase methods for whatever external storage is present
    function clearExtMemory() {
        rst_l.configure(DIGITAL_OUT);
        rst_l.write(0);
        ext_mem.chipErase();
        rst_l.configure(DIGITAL_IN);
    }
    
    // Helper: copy the start address of the dynamic image into the correct bytes of the static image
    // write the static image to the specified offset in external memory and return
    function writeSS(ss_img, ss_offset, ds_offset) {
        if (ss_img == null) {
            ss_img = blob(SS_LEN);
            ss_img.writestring(SS_IMG);
        }
        ss_img[30] = ds_offset & 0xff;
        ss_img[31] = (ds_offset & 0xff00) >> 8;
        ss_img[32] = (ds_offset & 0xff0000) >> 16;
        ss_img[33] = (ds_offset & 0xff000000) >> 24;
        ss_img.seek(0,'b');
        
        ext_mem.write(ss_img, ss_offset);    
    }

    // Reprogram the BCM20737 by holding it in reset and reporgramming its external memory
    // Input: 
    //      ds_img: (blob) binary image to program
    //          This is the "dynamic sector" image; over-the-air-firmware-upgrade (OTAFU) files contain only this
    //      ds_sel: (integer, 0-based) index: which DS offset to store the image in
    //      ss_img: (blob) static section binary image
    //          This 40-byte section is included only in the base image (not OTA image)
    //          If null, the class will fall back on a known SS image
    //      ss_sel: (integer, 0-based) index: which SS offset to store the SS image in (2 available)
    // Return: None
    function program(ds_img, ds_sel, ss_img = null, ss_sel = null) {
        clearExtMemory();
        // calculate actual memory offsets from slot number
        local ds_offset = DS1_OFFSET;
        if (ds_sel >= 1) {
            ds_offset = DS2_OFFSET;
        }
        local ss_offset = SS1_OFFSET;
        if (ss_sel != null) {
            if (ss_sel >= 1) {
                ss_offset = SS2_OFFSET;
            }
        }
        // Hold BCM in reset
        rst_l.configure(DIGITAL_OUT);
        rst_l.write(0);
        // write the dynamic image to the external memory
        ext_mem.write(ds_img, ds_offset);
        // copy the start address of the dynamic image into the static image and
        // write to the specified static image offset
        writeSS(ss_img, ss_offset, ds_offset);
        // relase BCM to begin running image
        rst_l.configure(DIGITAL_IN);
    }
}

/* GENERAL FUNCTIONS ---------------------------------------------------------*/

function memdump(dummy=null) {
    server.log("Dumping BCM20737 external memory to agent");
    agent.send("start",0);
    imp.wakeup(0.25, function() {
        ble.dumpExtMemory(function(data) {
            agent.send("chunk",data);
        });
    });
    server.log("Done");
}

/* REGISTER AGENT CALLBACKS --------------------------------------------------*/

agent.on("dump", memdump);
agent.on("zero", function(dummy) {
    ble.clearExtMemory();
});
agent.on("program", function(imgdata) {
    ble.program(imgdata.ds_img, imgdata.ds_sel, imgdata.ss_img, imgdata.ss_sel);
})

/* RUNTIME START -------------------------------------------------------------*/

imp.enableblinkup(true);
server.log("Initializing");

rst_l <- hardware.pin7;
i2c <- hardware.i2c89;
wp <- hardware.pin5;

i2c.configure(CLOCK_SPEED_400_KHZ);
rst_l.configure(DIGITAL_IN);
wp.configure(DIGITAL_IN);

// instantiate EEPROM
eeprom <- Eeprom24FC(i2c, wp, EEPROMSIZE);
// instantiate BLE module
// (eeprom, spi flash, rst_l, ext mem size, transaction block size)
ble <- BCM20737(eeprom, null, rst_l, EEPROMSIZE, BLOCKSIZE);

server.log("Ready. Free memory: "+imp.getmemoryfree());

