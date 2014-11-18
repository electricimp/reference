I2C EEPROM, [CAT24C32 Family](http://www.onsemi.com/pub_link/Collateral/CAT24C32-D.PDF)
==============
Driver for an I2C EEPROM (CAT24C32). Basic Read and Write commands accommodating 2-byte offsets are included.

Contributors
===================================
Tom Byrne  
Nick Garner (Adolene/Pignology)

Usage
===================================

```
//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);
// Configure the EEPROM
eeprom <- CAT24C32(i2c);
// write some test data
local testStr = "Electric Imp CAT24C32!";
// write the string to the eepromm, starting at offset 0x0123
eeprom.write(testStr,0x0123);
server.log("Read Back: " + eeprom.read(testStr.len(),0x0123));

```
