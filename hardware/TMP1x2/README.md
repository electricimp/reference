[TMP102 / TMP112 Digital Temperature Sensor](http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf)
==============
Driver for the TI TMP102 and TMP112 Digital Temperature Sensors. Communicates with sensor over I2C.


Usage
===================================

```
// 8-bit left-justified I2C address (Just an example.)
const TMP1x2_ADDR = 0x30;

// i2c bus
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

tempsensor <- TMP1x2(TMP1x2_ADDR, hardware.i2c89, hardware.pin1);

```