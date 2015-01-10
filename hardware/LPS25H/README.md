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

## Methods

#### softReset()
Reset the LPS25H from software. Device will come up disabled.

```
press.softReset();
```

#### enable(bool state)
Enable/disable the LPS25H. The device must be enabled before attempting to read the pressure or temperature.

```
press.enable(1);
```

#### getReferencePressure() 
Get the internal offset pressure set in the factory. Returns a raw value in the same units as the raw pressure registers (hPa * 4096).

```
server.log("Internal Reference Pressure Offset = "+press.getReferencePressure());
```

#### setPressNpts(int npts)
Set the number of readings taken and internally averaged to produce a pressure result. The value provided will be rounded up to the nearest valid npts value. Valid values are 8, 32, and 128.

```
// fastest readings, lowest precision
press.setPressNpts(8);

// slowest readings, highest precision
press.setPressNpts(128);
```

#### setTempNpts(int npts) 
Set the number of readings taken and internally averaged to produce a temperature result. The value provided will be rounded up to the nearest valid npts value. Valid values are 8, 16, 32, and 64.

```
// fastest readings, lowest precision
press.setTempNpts(8);

// slowest readings, highest precision
press.setTempNpts(64);
```

#### setIntEnable(bool state) 

```
// Enable interrupts on the LPS25H's interrupt pin
press.setIntEnable(1);
```

#### setFifoEnable(bool state) 
Enable or disable the internal FIFO for continuous pressure and temperature readings. Disabled by default.

```
// Enable internal FIFO for continuous pressure readings
press.setFifoEnable(1);
```

#### setIntActivehigh(bool state)
Set the interrupt polarity for the LPS25H. True configures the interrupt pin to be active-high; false configures the pin for active-low.

```
// Set interrupt pin to active-high
press.setIntActivehigh(1);

// Set interrupt pin to active-low
press.setIntActivehigh(0);
```

#### setIntPushpull(bool state) 
Select between push-pull and open-drain states for the interrupt pin. True sets the interrupt pin to push-pull; false sets the interrupt pin to open-drain.

```
// Set interrupt pin to push-pull
press.setIntPushpull(1);

// Set interrupt pin to open-drain
press.setIntPushpull(0);
```

#### setIntConfig(bool latch, bool diff_press_low, bool diff_press_high)
Configure interrupt sources for the interrupt pin:

* latch: set true to require that the interrupt source be read before the interrupt pin is de-asserted
* diff_press_low: set true to throw interrupts on differential pressure below the set threshold
* diff_press_high: set true to throw interrupts on differential pressure above the set threshold

```
// Configure interrupt pin to assert on pressure above threshold and latch until cleared
press.setIntConfig(1, 0, 1);
```
Interrupt source is stored in the INT_SOURCE register (0x25). To clear a latched interrupt or find out why the interrupt pin was asserted, read this register and check bits [2:0]:

| bit | meaning |
| --- | ------- |
| 2 | interrupt is currently active |
| 1 | differential pressure low |
| 0 | differential pressure high | 

``` 
// Read interrupt source register to see why interrupt was triggered
local val = press._read(LPS25H_REG.INT_SOURCE,1)[0];

if (val & 0x02) {
	server.log("Differential Pressure Low Event Occurred");
} 
if (val & 0x01) {
	server.log("Differential Pressure High Event Occurred");
}
```

#### setPressThresh(int threshold) 
Set the threshold value for pressure interrupts. Units are hPa * 4096.

```
// Set threshold pressure to 1000 mBar
local thresh = 1000 * 4096;
press.setPressThresh(thresh);
```

#### getRawPressure() 
Returns the raw value of PRESS_OUT_H, PRESS_OUT_L, and PRESS_OUT_XL. Units are hPa * 4096.

#### getPressureHPa()
Returns pressure in hectopascals (hundreds of Pascals). Also known as mBar.

#### getPressureKPa()
Returns pressure in kilopascals. 

#### getPressureInHg()
Returns pressure in Inches of Mercury.

#### getTemp()
Returns temperature in degrees Celsius.

