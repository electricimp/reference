SX150x GPIO Expander
==============
Driver for Semtech SX1505 and SX1506 I2C GPIO expanders.


Contributors
============
Brandon Harris, Tom Byrne, Aron Steg

Usage
=====
Strongly recommend using the ExpGPIO class which wraps much of the complexity of this class and allows you to use the IO expander pins similar to native Imp pins.

```
//Initialize the I2C bus
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_100_KHZ);

// Initialize an 8-channel I2C I/O Expander (SX1505)
ioexp <- SX1505(i2c,0x40);    // instantiate I/O Expander
ioexp.setPin(2, 1);           // Set IO-2 high
ioexp.setDir(2, 1);           // Set IO-2 to output
```

