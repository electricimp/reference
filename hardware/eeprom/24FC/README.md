I2C EEPROM, [24FC Family](http://ww1.microchip.com/downloads/en/DeviceDoc/21754M.pdf)
==============
Driver for an I2C EEPROM. Basic Read and Write commands are included.

Contributors
===================================
Tom Byrne

Usage
===================================

```
const EEPROMSIZE = 65536; // 64K (512kbit) EEPROM

//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

//Initialize Write Protect Pin
wp <- hardware.pin5;
wp.configure(DIGITAL_IN);

// instantiate EEPROM
eeprom <- Eeprom24FC(i2c, wp, EEPROMSIZE);
```
