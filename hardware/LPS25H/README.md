Driver for the LPS25H Air Pressure / Temperature Sensor
===================================

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LPS25H](http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf) is a MEMS absolute pressure sensor. This sensor features large functional range (260 to 1260 hPa) and internal averaging for improved precision. 

The LPS25HTR can interface over I2C or SPI. This class addresses only I2C for the time being. 

## Usage
The constructor takes two arguments: I2C bus and an I2C address. Imp pins should be configured before passing them to the constructor.

```
const LPS25H_ADDR     = 0xB8; // 8-bit I2C Student Address for LPS25H

i2c         <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

press <- LPS25H(i2c, LPS25H_ADDR);

server.log(format("LPS25H: Press = %0.2f" Hg, Temp = %0.2fC",press.getPressureInHg(), pressure.getTemp()));
```

