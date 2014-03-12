[TMP102 / TMP112 Digital Temperature Sensor](http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf)
==============
Driver for the TI TMP102 and TMP112 Digital Temperature Sensors. Communicates with sensor over I2C.


Usage
===================================

```
// 8-bit (left-justified I2C address. Just an example.)
const TMP112_ADDR = 0x30;

alert <- hardware.pin1;
alert.configure(DIGITAL_IN);
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
tempsensor = TMP112(i2c, TMP112_ADDR, alert);
```