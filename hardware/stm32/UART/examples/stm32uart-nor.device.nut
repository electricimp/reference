// STM32 microprocessor firmware updater
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------

const BLOCKSIZE = 4096; // bytes per buffer of data sent from agent
const STM32_SECTORSIZE = 0x4000;
const BAUD = 115200; // any standard baud between 9600 and 115200 is allowed
const SPICLK = 3750; // kHz, rate to run the SPI
                    
BYTE_TIME <- 8.0 / (BAUD * 1.0);

// CLASS AND FUNCTION DEFS -----------------------------------------------------

function hexdump(data) {
    local i = 0;
    while (i < data.tell()) {
        local line = " ";
        for (local j = 0; j < 8 && i < data.tell(); j++) {
            line += format("%02x ", data[i++]);
        }
        server.log(line);
    }
}

// This class implements the UART bootloader command set
// https://github.com/electricimp/reference/tree/master/hardware/stm32/UART
class Stm32 {    
    static INIT_TIME        = 0.5; // seconds
    static UART_CONN_TIME   = 0.010; // ms, initial UART configuration time
    static TIMEOUT_CMD      = 100; // ms
    static TIMEOUT_ERASE    = 30000; // ms; erases take a long time!
    static TIMEOUT_WRITE    = 1000; // ms
    static TIMEOUT_PROTECT  = 5000; // ms; used when enabling or disabling read or write protect

    static CMD_INIT         = 0x7F;
    static ACK              = 0x79;
    static NACK             = 0x1F;
    static CMD_GET          = 0x00;
    static CMD_GET_VERSION_PROT_STATUS = 0x01;
    static CMD_getId       = 0x02;
    static CMD_rdMemORY    = 0x11;
    static CMD_GO           = 0x21;
    static CMD_wrMemORY    = 0x31;
    static CMD_ERASE        = 0x43; // ERASE and EXT_ERASE are exclusive; only one is supported
    static CMD_EXT_ERASE    = 0x44;
    static CMD_wrProt      = 0x63;
    static CMD_wrUnprot    = 0x73;
    static CMD_RDOUT_PROT   = 0x82;
    static CMD_RDOUT_UNPROT = 0x92;
    
    static FLASH_BASE_ADDR  = 0x08000000;
    static SECTORSIZE = 0x4000; // size of one flash "page"

    bootloader_version = null;
    bootloader_active = false;
    supported_cmds = [];
    pid = null;
    mem_ptr = 0;
    
    uart = null;
    nrst = null;
    boot0 = null;
    boot1 = null;
    
    constructor(_uart, _nrst, _boot0, _boot1 = null) {
        uart = _uart;
        nrst = _nrst;
        boot0 = _boot0;
        if (_boot1) { boot1 = _boot1; }
        mem_ptr = FLASH_BASE_ADDR;
    }
    
    // Helper function: clear the UART RX FIFO by reading out any remaining data
    // Input: None
    // Return: None
    function clearUart() {
        local byte = uart.read();
        while (byte != -1) {
            byte = uart.read();
        }
    }
    
    // Helper function: block and read a set number of bytes from the UART
    // Times out if the UART doesn't receive the required number of bytes in 2 * BYTE TIME
    // Helpful primarily when reading more than the UART RX FIFO can hold (80 bytes)
    // Input: num_bytes (integer)
    // Return: RX'd data (blob)
    function readUart(num_bytes) {
        local result = blob(num_bytes);
        local start = hardware.millis();
        local pos = result.tell();
        local timeout = 10 * BYTE_TIME * num_bytes * 1000;
        while (result.tell() < num_bytes) {
            if (hardware.millis() - start > timeout) {
                throw format("Timed out waiting for data, got %d / %d bytes",pos,num_bytes);
            }
            local byte = uart.read();
            if (byte != -1) {
                result.writen(byte,'b');
                pos++;
            }
        }
        return result;
    }
    
    // Helper function: compute the checksum for a blob and write the checksum to the end of the blob
    // Note that STM32 checksum is really just a parity byte
    // Input: data (blob)
    //      Blob pointer should be at the end of the data to checksum
    // Return: data (blob), with checksum written to end
    function wrChecksum(data) {
        local checksum = 0;
        for (local i = 0; i < data.tell(); i++) {
            //server.log(format("%02x",data[i]));
            checksum = (checksum ^ data[i]) & 0xff;
        }
        data.writen(checksum, 'b');
    }
    
    // Helper function: send a UART bootloader command
    // Not all commands can use this helper, as some require multiple steps
    // Sends command, gets ACK, and receives number of bytes indicated by STM32
    // Input: cmd - USART bootloader command (defined above)
    // Return: response (blob) - results of sending command
    function sendCmd(cmd) {
        clearUart();
        local checksum = (~cmd) & 0xff;
        uart.write(format("%c%c",cmd,checksum));
        getAck(TIMEOUT_CMD);
        imp.sleep(BYTE_TIME * 2);
        local num_bytes = uart.read() + 0;
        if (cmd == CMD_getId) {num_bytes++;} // getId command responds w/ number of bytes in ID - 1.
        imp.sleep(BYTE_TIME * (num_bytes + 4));
        
        local result = blob(num_bytes);
        for (local i = 0; i < num_bytes; i++) {
            result.writen(uart.read(),'b');
        }
        
        result.seek(0,'b');
        return result;
    }
    
    // Helper function: wait for an ACK from STM32 when sending a command
    // Implements a timeout and blocks until ACK is received or timeout is reached
    // Input: [optional] timeout in µs
    // Return: bool. True for ACK, False for NACK.
    function getAck(timeout) {
        local byte = uart.read();
        local start = hardware.millis();
        while ((hardware.millis() - start) < timeout) {
            // server.log(format("Looking for ACK: %02x",byte));
            if (byte == ACK) { return true; }
            if (byte == NACK) { return false; }
            if (byte != -1) { server.log(format("%02x",byte)); }
            byte = uart.read();
        }
        throw "Timed out waiting for ACK after "+timeout+" ms";
    }
    
    // set the class's internal pointer for the current address in flash
    // this allows functions outside the class to start at 0 and ignore the flash base address
    // Input: relative position of flash memory pointer (integer)
    // Return: None
    function setMemPtr(addr) {
        mem_ptr = addr + FLASH_BASE_ADDR;
    }
    
    // get the relative position of the current address in flash
    // Input: None
    // Return: relative position of flash memory pointer (integer)
    function getMemPtr() {
        return mem_ptr - FLASH_BASE_ADDR;
    }
    
    // get the base address of flash memory
    // Input: None
    // Return: flash base address (integer)
    function getFlashBaseAddr() {
        return FLASH_BASE_ADDR;
    }
    
    // Reset the STM32 to bring it out of USART bootloader
    // Releases the boot0 pin, then toggles reset
    // Input: None
    // Return: None
    function reset() {
        bootloader_active = false;
        nrst.write(0);
        // release boot0 so we don't come back up in USART bootloader mode
        boot0.write(0);
        imp.sleep(0.010);
        nrst.write(1);
    }
    
    // Reset the STM32 and bring it up in USART bootloader mode
    // Applies "pattern1" from "STM32 system memory boot mode” application note (AN2606)
    // Note that the USARTs available for bootloader vary between STM32 parts
    // Input: None
    // Return: None
    function enterBootloader() {
        // hold boot0 high, boot1 low, and toggle reset
        nrst.write(0);
        boot0.write(1);
        if (boot1) { boot1.write(0); }
        nrst.write(1);
        // bootloader will take a little time to come up
        imp.sleep(INIT_TIME);
        // release boot0 so we don't wind up back in the bootloader on our next reset
        boot0.write(0);
        // send a command to initialize the bootloader on this UART
        clearUart();
        uart.write(CMD_INIT);
        imp.sleep(UART_CONN_TIME);
        local response = uart.read() + 0;
        if (response == ACK) {
            // USART bootloader successfully configured
            bootloader_active = true;
            return;
        } else {
            throw "Failed to configure USART Bootloader, got "+response;
        }
    }
    
    // Send the GET command to the STM32
    // Gets the bootloader version and a list of supported commands
    // The imp will store the results of this command to save time if asked again later
    // Input: None
    // Return: Result (table)
    //      bootloader_version (byte)
    //      supported_cmds (array)
    function get() {
        // only request info from the device if we don't already have it
        if (bootloader_version == null || supported_cmds.len() == 0) {
            // make sure the bootloader is active; allows us to call this method directly from outside the class
            if (!bootloader_active) { enterBootloader(); }
            local result = sendCmd(CMD_GET);
            bootloader_version = result.readn('b');
            bootloader_version = format("%d.%d",((bootloader_version & 0xf0) >> 4),(bootloader_version & 0x0f)).tofloat();
            while (!result.eos()) {
                local byte  = result.readn('b');
                supported_cmds.push(byte);
            }
        } 
        return {bootloader_version = bootloader_version, supported_cmds = supported_cmds};
    }
    
    // Send the GET ID command to the STM32
    // Gets the chip ID from the device
    // The imp will store the results of this command to save time if asked again later
    // Input: None
    // Return: pid (2 bytes)
    function getId() {
        // just return the value if we already know it
        if (pid == null) {
            // make sure bootloader is active before sending command
            if (!bootloader_active) { enterBootloader(); }
            local result = sendCmd(CMD_getId);
            pid = result.readn('w');
        }
        return format("%04x",pid);
    }
    
    // Read a section of device memory
    // Input: 
    //      addr: 4-byte address. Refer to “STM32 microcontroller system memory boot mode” application note (AN2606) for valid addresses
    //      len: number of bytes to read. 0-255.
    // Return: 
    //      memory contents from addr to addr+len (blob)
    function rdMem(addr, len) {
        if (!bootloader_active) { enterBootloader(); }
        clearUart();
        uart.write(format("%c%c",CMD_rdMemORY, (~CMD_rdMemORY) & 0xff));
        getAck(TIMEOUT_CMD);
        // read mem command ACKs, then waits for starting memory address
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wrChecksum(addrblob);
        uart.write(addrblob);
        if (!getAck(TIMEOUT_CMD)) {
            throw format("Read Failed for addr %08x (invalid address)",addr);
        };
        // STM32 ACKs the address, then waits for the number of bytes to read
        len = len & 0xff;
        uart.write(format("%c%c",len, (~len) & 0xff));
        if (!getAck(TIMEOUT_CMD)) {
            throw format("Read Failed for %d bytes starting at %08x (read protected)",len,addr);
        }
        // blocking read the memory contents
        local result = readUart(len);
        return result;
    }
    
    // Execute downloaded or other code by branching to a specified address
    // When the address is valid and the command is executed: 
    // - registers of all peripherals used by bootloader are reset to default values
    // - user application's main stack pointer is initialized
    // - STM32 jumps to memory location specified + 4
    // Host should send base address where the application to jump to is programmed
    // Jump to application only works if the user application sets the vector table correctly to point to application addr
    // Input: 
    //      addr: 4-byte address
    // Return: None
    function go(addr = null) {
        if (!bootloader_active) { enterBootloader(); }
        clearUart()
        uart.write(format("%c%c",CMD_GO, (~CMD_GO) & 0xff));
        getAck(TIMEOUT_CMD);
        // GO command ACKs, then waits for starting address
        // if no address was given, assume image starts at the beginning of the flash
        if (addr == null) { addr = FLASH_BASE_ADDR; }
        local addrblob = blob(5);
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wrChecksum(addrblob);
        uart.write(addrblob);        
        if (!getAck(TIMEOUT_CMD)) {
            throw format("Write Failed for addr %08x (invalid address)",addr);
        };
        // system will now exit bootloader and jump into application code
        bootloader_active = false;
        setMemPtr(0);
    }
    
    // Write data to any valid memory address (RAM, Flash, Option Byte Area, etc.)
    // Note: to write to option byte area, address must be base address of this area
    // Maximum length of block to be written is 256 bytes
    // Input: 
    //      addr: 4-byte starting address
    //      data: data to write (0 to 256 bytes, blob)
    // Return: None
    function wrMem(data, addr = null) {
        if (!bootloader_active) { enterBootloader(); }
        local len = data.len();
        clearUart();
        uart.write(format("%c%c",CMD_wrMemORY, (~CMD_wrMemORY) & 0xff));
        getAck(TIMEOUT_CMD);

        // read mem command ACKs, then waits for starting memory address
        local addrblob = blob(5);
        if (addr == null) { addr = mem_ptr; }
        addrblob.writen(addr,'i');
        addrblob.swap4(); // STM32 wants MSB-first. Imp is LSB-first.
        wrChecksum(addrblob);
        uart.write(addrblob);
        if (!getAck(TIMEOUT_CMD)) {
            throw format("Got NACK on wrMemORY for addr %08x (invalid address)",addr);
        };
        
        // STM32 ACKs the address, then waits for the number of bytes to be written
        local wrblob = blob(data.len() + 2);
        wrblob.writen(len - 1,'b');
        wrblob.writeblob(data);
        wrChecksum(wrblob);
        uart.write(wrblob);
        
        if(!getAck(TIMEOUT_WRITE)) {
            throw "Write Failed (NACK)";
        }
        mem_ptr += len;
    }
    
    // Erase flash memory pages
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input:
    //      num_pages (1-byte integer) number of pages to erase
    //      page_codes (array)
    // Return: None
    function eraseMem(num_pages, page_codes) {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0);
        clearUart();
        uart.write(format("%c%c",CMD_ERASE, (~CMD_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        local erblob = blob(page_codes.len() + 2);
        erblob.writen(num_pages & 0xff, 'b');
        foreach (page in page_codes) {
            erblob.writen(page & 0xff, 'b');
        }
        wrChecksum(erblob);
        uart.write(wrblob);
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Erase Failed (NACK)";
        }
    }
    
    // Erase all flash memory
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input: None
    // Return: None
    function eraseGlobalMem() {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0);
        clearUart();
        uart.write(format("%c%c",CMD_ERASE, (~CMD_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        uart.write("\xff\x00");
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Global Erase Failed (NACK)";
        }
    }
    
    // Erase flash memory pages using two byte addressing
    // Note that either ERASE or EXT_ERASE are supported, but not both
    // The STM32F407VG does not support ERASE
    // Input: 
    //      page codes (array of 2-byte integers). List of "sector codes"; leading bytes of memory address to erase.
    // Return: None
    function extEraseMem(page_codes) {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0)
        clearUart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        // 2 bytes for num_pages, 2 bytes per page code, 1 byte for checksum
        local num_pages = page_codes.len() - 1; // device erases N + 1 pages (grumble)
        local erblob = blob((2 * num_pages) + 3);
        erblob.writen((num_pages & 0xff00) >> 8, 'b');
        erblob.writen(num_pages & 0xff, 'b');
        foreach (page in page_codes) {
            erblob.writen((page & 0xff00) >> 8, 'b');
            erblob.writen(page & 0xff, 'b');
        }
        wrChecksum(erblob);
        uart.write(erblob);
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Extended Erase Failed (NACK)";
        }
    }
    
    // Erase all flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None
    function massErase() {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0);
        clearUart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        uart.write("\xff\xff\x00");
        local byte = uart.read();
        local start = hardware.millis();
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Mass Erase Failed (NACK)";
        }
    }
    
    // Erase bank 1 flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None
    function bank1Erase() {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0);
        clearUart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        uart.write("\xff\xfe\x01");
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Bank 1 Erase Failed (NACK)";
        }
    }
    
    // Erase bank 2 flash memory for devices that support EXT_ERASE
    // Input: None
    // Return: None    
    function bank2Erase() {
        if (!bootloader_active) { enterBootloader(); }
        setMemPtr(0);
        clearUart();
        uart.write(format("%c%c",CMD_EXT_ERASE, (~CMD_EXT_ERASE) & 0xff));
        getAck(TIMEOUT_CMD);
        uart.write("\xff\xfd\x02");
        if (!getAck(TIMEOUT_ERASE)) {
            throw "Flash Bank 2 Erase Failed (NACK)";
        }
    }
    
    // Enable write protection for some or all flash memory sectors
    // System reset is generated at end of command to apply the new configuration
    // Input: 
    //      num_sectors: (1-byte integer) number of sectors to protect
    //      sector_codes: (1-byte integer array) sector codes of sectors to protect
    // Return: None
    function wrProt(num_sectors, sector_codes) {
        if (!bootloader_active) { enterBootloader(); }
        clearUart();
        uart.write(format("%c%c",CMD_wrProt, (~CMD_wrProt) & 0xff));
        getAck(TIMEOUT_CMD);
        local protblob = blob(sector_codes.len() + 2);
        protblob.writen(num_sectors & 0xff, 'b');
        foreach (sector in sector_codes) {
            protblob.writen(sector & 0xff, 'b');
        }
        wrChecksum(protblob);
        uart.write(protblob);
        if (!getAck(TIMEOUT_PROTECT)) {
            throw "Write Protect Unprotect Failed (NACK)";
        }
        // system will now reset
        bootloader_active = false;
        imp.sleep(INIT_TIME);
        enterBootloader();
    }
    
    // Disable write protection of all flash memory sectors
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function wrUnprot() {
        if (!bootloader_active) { enterBootloader(); }
        clearUart();
        uart.write(format("%c%c",CMD_wrUnprot, (~CMD_wrUnprot) & 0xff));
        // first ACK acknowledges command
        getAck(TIMEOUT_CMD);
        // second ACK acknowledges completion of write protect enable
        if (!getAck(TIMEOUT_PROTECT)) {
            throw "Write Unprotect Failed (NACK)"
        }
        // system will now reset
        bootloader_active = false;
        imp.sleep(INIT_TIME);
        enterBootloader();
    }
    
    // Enable flash memory read protection
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function rdProt() {
        if (!bootloader_active) { enterBootloader(); }
        clearUart();
        uart.write(format("%c%c",CMD_RDOUT_PROT, (~CMD_RDOUT_PROT) & 0xff));
        // first ACK acknowledges command
        getAck(TIMEOUT_CMD);
        // second ACK acknowledges completion of write protect enable
        if (!getAck(TIMEOUT_PROTECT)) {
            throw "Read Protect Failed (NACK)"
        }        
        // system will now reset
        bootloader_active = false;
        imp.sleep(SYS_RESET_WAIT);
        enterBootloader();
    }
    
    // Disable flash memory read protection
    // System reset is generated at end of command to apply the new configuration
    // Input: None
    // Return: None
    function rdUnprot() {
        if (!bootloader_active) { enterBootloader(); }
        clearUart();
        uart.write(format("%c%c",CMD_RDOUT_UNPROT, (~CMD_RDOUT_UNPROT) & 0xff));
        // first ACK acknowledges command
        getAck(TIMEOUT_CMD);
        // second ACK acknowledges completion of write protect enable
        if (!getAck(TIMEOUT_PROTECT)) {
            throw "Read Unprotect Failed (NACK)";
        }
        // system will now reset
        bootloader_active = false;
        imp.sleep(INIT_TIME);
        enterBootloader();
    }
    
}

// Semi-generic SPI Flash Driver
// This class was developed to be used in an Electric Imp intercom application
// https://github.com/electricimp/reference/tree/master/hardware/SpiFlash
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
    
    function getMfgId() {
        return this.mfgID;
    }
    
    function getDevId() {
        return this.devID;
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
            if ((addr+i % 256) + leftInBuffer >= 256) {
                // Realign to the end of the page
                local align = 256 - ((addr+i) % 256);
                write((addr+i),data.readblob(align));
                leftInBuffer -= align;
                i += align;
                if (leftInBuffer <= 0) break;
            }
            if (leftInBuffer < 256) {
                write((addr+i),data.readblob(leftInBuffer));
            } else {
                write((addr+i),data.readblob(256));
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
        return 0;
    }
}

// Generic squirrel object serializer
// https://github.com/electricimp/reference/tree/master/hardware/serializer
class serializer {
 
    // Serialize a variable of any type into a blob
    function serialize (obj) {
        // Take a guess at the initial size
        local b = blob(2000);
        // Write dummy data for len and crc late
        b.writen(0, 'b');
        b.writen(0, 'b');
        b.writen(0, 'b');
        // Serialise the object
        _serialize(b, obj);
        // Shrink it down to size
        b.resize(b.tell());
        // Go back and add the len and CRC
        local len = b.len()-3;
        b[0] = len >> 8 & 0xFF;
        b[1] = len & 0xFF;
        b[2] = CRC(b, 3);
        return b;
    }
 
    function _serialize (b, obj) {
 
        switch (typeof obj) {
            case "integer":
                return _write(b, 'i', format("%d", obj));
            case "float":
                local f = format("%0.7f", obj).slice(0,9);
                while (f[f.len()-1] == '0') f = f.slice(0, -1);
                return _write(b, 'f', f);
            case "null":
            case "function": // Silently setting this to null
                return _write(b, 'n');
            case "bool":
                return _write(b, 'b', obj ? "\x01" : "\x00");
            case "blob":
                return _write(b, 'B', obj);
            case "string":
                return _write(b, 's', obj);
            case "table":
            case "array":
                local t = (typeof obj == "table") ? 't' : 'a';
                _write(b, t, obj.len());
                foreach ( k,v in obj ) {
                    _serialize(b, k);
                    _serialize(b, v);
                }
                return;
            default:
                throw ("Can't serialize " + typeof obj);
                // server.log("Can't serialize " + typeof obj);
        }
    }
 
 
    function _write(b, type, payload = null) {
 
        // Calculate the lengths
        local payloadlen = 0;
        switch (type) {
            case 'n':
            case 'b':
                payloadlen = 0;
                break;
            case 'a':
            case 't':
                payloadlen = payload;
                break;
            default:
                payloadlen = payload.len();
        }
        
        // Update the blob
        b.writen(type, 'b');
        if (payloadlen > 0) {
            b.writen(payloadlen >> 8 & 0xFF, 'b');
            b.writen(payloadlen & 0xFF, 'b');
        }
        if (typeof payload == "string" || typeof payload == "blob") {
            foreach (ch in payload) {
                b.writen(ch, 'b');
            }
        }
    }
 
 
    // Deserialize a string into a variable 
    function deserialize (s) {
        // Read and check the header
        s.seek(0);
        local len = s.readn('b') << 8 | s.readn('b');
        local crc = s.readn('b');
        if (s.len() != len+3) throw "Expected exactly " + len + " bytes in this blob";
        // Check the CRC
        local _crc = CRC(s, 3);
        if (crc != _crc) throw format("CRC mismatch: 0x%02x != 0x%02x", crc, _crc);
        // Deserialise the rest
        return _deserialize(s, 3).val;
    }
    
    function _deserialize (s, p = 0) {
        for (local i = p; i < s.len(); i++) {
            local t = s[i];
            switch (t) {
                case 'n': // Null
                    return { val = null, len = 1 };
                case 'i': // Integer
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).tostring().tointeger();
                    return { val = val, len = 3+len };
                case 'f': // Float
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).tostring().tofloat();
                    return { val = val, len = 3+len };
                case 'b': // Bool
                    local val = s[i+1];
                    return { val = (val == 1), len = 2 };
                case 'B': // Blob 
                    local len = s[i+1] << 8 | s[i+2];
                    local val = blob(len);
                    for (local j = 0; j < len; j++) {
                        val[j] = s[i+3+j];
                    }
                    return { val = val, len = 3+len };
                case 's': // String
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).tostring();
                    return { val = val, len = 3+len };
                case 't': // Table
                case 'a': // Array
                    local len = 0;
                    local nodes = s[i+1] << 8 | s[i+2];
                    i += 3;
                    local tab = null;
 
                    if (t == 'a') {
                        // server.log("Array with " + nodes + " nodes");
                        tab = [];
                    }
                    if (t == 't') {
                        // server.log("Table with " + nodes + " nodes");
                        tab = {};
                    }
 
                    for (; nodes > 0; nodes--) {
 
                        local k = _deserialize(s, i);
                        // server.log("Key = '" + k.val + "' (" + k.len + ")");
                        i += k.len;
                        len += k.len;
 
                        local v = _deserialize(s, i);
                        // server.log("Val = '" + v.val + "' [" + (typeof v.val) + "] (" + v.len + ")");
                        i += v.len;
                        len += v.len;
 
                        if (t == 'a') tab.push(v.val);
                        else          tab[k.val] <- v.val;
                    }
                    return { val = tab, len = len+3 };
                default:
                    throw format("Unknown type: 0x%02x at %d", t, i);
            }
        }
    }
 
 
    function CRC (data, offset = 0) {
        local LRC = 0x00;
        for (local i = offset; i < data.len(); i++) {
            LRC = (LRC + data[i]) & 0xFF;
        }
        return ((LRC ^ 0xFF) + 1) & 0xFF;
    }
 
}

// AGENT CALLBACKS -------------------------------------------------------------

// Allow the agent to request that the device send its bootloader version and supported commands
agent.on("get_version", function(dummy) {
    agent.send("set_version",stm32.get());
    if (stm32.bootloader_active) { stm32.reset(); }
});

// Allow the agent to request the device's PID
agent.on("get_id", function(dummy) {
    agent.send("set_id", stm32.getId());
    if (stm32.bootloader_active) { stm32.reset(); }
});

// Allow the agent to reset the stm32 to normal operation
agent.on("reset", function(dummy) {
    stm32.reset();
});

// Allow the agent to remove readback protection from the flash
// (give this a go if flash writes and erases mysteriously give you "invalid address")
agent.on("rd_unprot", function(dummy) {
    stm32.rdUnprot();
});

// Allow the agent to remove write protection from the flash
// (try this if you're unable to write new images; removed from the write routine for speed and clarity)
agent.on("wr_unprot", function(dummy) {
    stm32.wrUnprot();
});

// Allow the agent to erase the full STM32 flash 
// Useful for device recovery if something goes wrong during testing
agent.on("erase_target", function(dummy) {
    server.log("Enabling Flash Erase");
    stm32.wrUnprot();
    server.log("Erasing All STM32 Flash");
    stm32.massErase();
    server.log("Resetting STM32");
    stm32.reset();
    server.log("Done");
});

// Allow the agent to erase the full NOR flash 
agent.on("erase_nor", function(dummy) {
    server.log("Erasing All NOR Flash");
    flash.chipErase();
    server.log("Done");
});

// Initiate an application firmware update from NOR
agent.on("load_fw", function(dummy) {
    server.log("FW Update: Loading Image from NOR Flash");
    // The length of the file attribute table is the first four bytes in NOR
    local attrlenblob = flash.read(0, 4);
    local attrlen = attrlenblob.readn('i');
    server.log(format("File attribute table is %d bytes in NOR, serialized",attrlen));
    fw_attr = serializer.deserialize(flash.read(4,attrlen));
    server.log(format("File attribute table loaded, loading %d byte image from NOR",fw_attr.len));
    
    // Now begin transfering data from NOR to target flash
    stm32.enterBootloader();
    local page_codes = [];
    local erase_through_sector = math.ceil((len * 1.0) / STM32_SECTORSIZE);
    for (local i = 0; i <= erase_through_sector; i++) {
        page_codes.push(i);
    }
    server.log(format("FW Update: Erasing %d page(s) in Target Flash (%d bytes each)", erase_through_sector, STM32_SECTORSIZE));
    stm32.extEraseMem(page_codes);
    
    server.log("FW Update: Target Flash Erased, Transfering Image to Target");
    fw_ptr = 0;
    while (fw_ptr < fw_attr.len) {
        local bytes_left = fw_attr.len - fw_ptr;
        local read_bytes = bytes_left > BLOCKSIZE ? BLOCKSIZE : bytes_left;
        stm32.wrMem(flash.readChunk(fw_ptr + BLOCKSIZE, read_bytes));
        fw_ptr += read_bytes;
    }
    
    server.log("FW Update: Finished Transferring Image to Target, Starting")
    stm32.go();
    server.log("Running")
});

// Initiate of target image download NOR
// Agent supplies a table of attributes about the image to be downloaded
// Currently contains just the image len in bytes
// The agent will supply a 32-bit checksum with each block of data sent with "push"
fw_attr <- {}
fw_ptr <- BLOCKSIZE;
agent.on("store_fw", function(attr) {
    server.log(format("FW Update: %d bytes",attr.len));
    fw_attr.len <- attr.len;
    fw_attr.checksums <- [];
    // set the download pointer to the beginning of the 2nd sector
    // the first sector will hold the attribute table
    fw_ptr = BLOCKSIZE;
    
    // clear the required number of sectors + 1 in the NOR flash
    // the first sector will be used to store a serialized version of the attribute table,
    // which will also contain all of the checksums for each block, so that they can be verified on read
    local erase_through_sector = attr.len / BLOCKSIZE;
    server.log(format("FW Update: Erasing %d sector(s) in NOR (%d bytes each)", erase_through_sector, attr.blocksize));
    for (local i = 0; i <= erase_through_sector; i++) {
        flash.sectorErase((i * BLOCKSIZE) & 0x00ffffff);
    }
    
    server.log("FW Update: Starting Download");
    // send pull request with a dummy value
    agent.send("pull", 0);
});

// Agent will send blocks of data here to be saved to NOR
// Each block of data comes with a 32-bit checksum, which is stored in a table.
// When the download is finished, the attribute table (containing checksums) is serialized
// and saved to the first sector in flash. 
agent.on("push", function(data) {
    // add the checksum to the array of checksums in the attribute table
    fw_attr.checksums.push(data.checksum);

    // store the actual buffer of data in NOR
    flash.writeChunk(fw_ptr, data.buffer);
    fw_ptr += data.buffer.len;
    
    // request more data from the agent
    agent.send("pull", 0);
});

// agent sends this event when the device has downloaded the entire new firmware image
agent.on("dl_complete", function(dummy) {
    server.log("FW Update: Image Download Complete, Storing Image Attributes");
    
    // first, serialize the attribute table
    local attrblob = blob(BLOCKSIZE);
    local tempblob = serializer.serialze(fw_attr);
    server.log(format("File attribute table is %d bytes serialized",tempblob.len()));
    // first 4 bytes in flash is the length of the attribute table
    attrblob.writen(tempblob.len(), 'i');
    attrblob.writeblob(tempblob);
    
    // write attribute table to first sector in flash
    flash.writeChunk(0,attrblob);
    
    // reset
    fw_attr = {};
    fw_ptr = BLOCKSIZE;
    server.log("FW Update: Image Saved to NOR");
});

// MAIN ------------------------------------------------------------------------

nrst  <- hardware.pin8;
boot0 <- hardware.pin9;
uart  <- hardware.uart6E;
spi   <- hardware.spi257;
cs_l  <- hardware.pinD;

nrst.configure(DIGITAL_OUT);
nrst.write(1);
boot0.configure(DIGITAL_OUT);
boot0.write(0);
cs_l.configure(DIGITAL_OUT);
cs_l.write(1);

uart.configure(BAUD, 8, PARITY_EVEN, 1, NO_CTSRTS);
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPICLK);

stm32 <- Stm32(uart, nrst, boot0);
flash <- SpiFlash(spi, cs_l);

server.log(format("NOR Flash Ready, MFG ID: %02x, Dev ID: %02x",flash.getMfgId(),flash.getDevId()));
server.log("Ready");