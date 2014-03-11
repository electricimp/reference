// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Semi-generic SPI Flash Driver
// This class was developed to be used in an Electric Imp intercom application
class SpiFlash {
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN     = "\x06"; // write enable
    static WRDI     = "\x04"; // write disable
    static RDID     = "\x9F"; // read identification
    static RDSR     = "\x05"; // read status register
    static READ     = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP   = "\x5A"; // read SFDP
    static RES      = "\xAB"; // read electronic ID
    static REMS     = "\x90"; // read electronic mfg & device ID
    static DREAD    = "\x3B"; // double output mode, which we don't use
    static SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE       = "\x60"; // chip erase (full device set to 0xff)
    static PP       = "\x02"; // page program 
    static RDSCUR   = "\x2B"; // read security register
    static WRSCUR   = "\x2F"; // write security register
    static ENSO     = "\xB1"; // enter secured OTP
    static EXSO     = "\xC1"; // exit secured OTP
    static DP       = "\xB9"; // deep power down
    static RDP      = "\xAB"; // release from deep power down
 
    // offsets for the record and playback sectors in memory
    // 64 blocks
    // first 48 blocks: playback memory
    // blocks 49 - 64: recording memory
    static totalBlocks = 64;
    static playbackBlocks = 48;
    static recordOffset = 0x2FFFD0;
 
    // manufacturer and device ID codes
    mfgID = null;
    devID = null;
 
    // spi interface
    spi = null;
    cs_l = null;
 
    // constructor takes in pre-configured spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        this.spi = spiBus;
        this.cs_l = csPin;
 
        // read the manufacturer and device ID
        cs_l.write(0);
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        cs_l.write(1);
    }
 
    function wrenable() {
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
 
    function wrdisable() {
        cs_l.write(0);
        spi.write(WRDI);
        cs_l.write(1);
    }
 
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
 
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
 
        cs_l.write(0);
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        cs_l.write(1);
 
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
 
        return 0;
    }
 
    // allow data chunks greater than one flash page to be written in a single op
    function writeChunk(addr, data) {
        // separate the chunk into pages
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - data.tell();
            if (leftInBuffer < 256) {
                flash.write((addr+i),data.readblob(leftInBuffer));
            } else {
                flash.write((addr+i),data.readblob(256));
            }
        }
    }
 
    function read(addr, bytes) {
        cs_l.write(0);
        // to read, send the read command and a 24-bit address
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
 
    function getStatus() {
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }
 
    function sleep() {
        cs_l.write(0);
        spi.write(DP);
        cs_l.write(1);     
   }
 
    function wake() {
        cs_l.write(0);
        spi.write(RDP);
        cs_l.write(1);
    }
 
    // erase any 4kbyte sector of flash
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        this.wrenable();
        cs_l.write(0);
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
 
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        //server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
 
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        cs_l.write(0);
        spi.write(CE);
        cs_l.write(1);
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
 
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    function erasePlayBlocks() {
        server.log("Device: clearing playback flash sectors");
        for(local i = 0; i < this.playbackBlocks; i++) {
            if(this.blockErase(i*65535)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*65535));
                return 1;
            }
        }
        return 0;
    }
 
    // erase the record buffer portion of the SPI flash
    // this is a 960000-byte sector, beginning at block 46 and going to block 60
    function eraseRecBlocks() {
        server.log("Device: clearing recording flash sectors");
        for (local i = this.playbackBlocks; i < this.totalBlocks; i++) {
            if(this.blockErase(i*65535)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*65535));
                return 1;
            }
        }
        return 0;
    }
}

// configure hardware before passing to constructor
spi     <- hardware.spi257;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);
cs_l    <- hardware.pin8;
cs_l.configure(DIGITAL_OUT);
cs_l.write(1);

// instantiate class
flash <- SpiFlash(spi, cs_l)

// clear memory
flash.chipErase();