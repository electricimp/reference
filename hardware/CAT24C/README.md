I2C EEPROM, [CAT24C Family](http://www.onsemi.com/pub_link/Collateral/CAT24C02-D.PDF)
==============
Driver for an I2C EEPROM. Basic Read and Write commands are included.

Contributors
===================================
Tom Byrne

Usage
===================================

```
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
```
