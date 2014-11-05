// Broadcom Bluetooth LE SOC
// See Broadcom "WICED Smart" Documentation
// http://www.broadcom.com/products/wiced/smart/
// This class encapuslates reprogramming the "WICED Smart" module by holding it in reset
// and re-writing its image on EEPROM or SPI FLASH
class BCM2073x {
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
        rst_l.configure(DIGITAL_OUT, 0);
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
        rst_l.configure(DIGITAL_OUT, 0);
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
        rst_l.configure(DIGITAL_OUT, 0);
        // write the dynamic image to the external memory
        ext_mem.write(ds_img, ds_offset);
        // copy the start address of the dynamic image into the static image and
        // write to the specified static image offset
        writeSS(ss_img, ss_offset, ds_offset);
        // relase BCM to begin running image
        rst_l.configure(DIGITAL_IN);
    }
}