# Driver for the LIS3DH 3-Axis Accelerometer

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LIS3DH](http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00274221.pdf) is a 3-Axis MEMS accelerometer. This sensor has extensive functionality and this class has not yet implemented all of it.

The LIS3DH can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

## Class Usage

### Constructor

The class’ constructor takes one required parameter (a configured imp I&sup2;C bus) and two optional parameters:

| Parameter     | Type         | Default | Description |
| ------------- | ------------ | ------- | ----------- |
| i2cBus        | hardware.i2c | N/A     | A pre-configured I&sup2;C bus |
| i2cAccellAddr | byte         | 0x30    | The I&sup2;C address of the accelerometer |


```Squirrel
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
accel <- LIS3DH(i2c, 0x32); // using a non-default I2C address (SA0 pulled high)
```

### Enabling and Reading Data

The LIS3DH comes out of reset disabled. To read accelerometer data, the sensor must first be enabled and the datarate set to a nonzero value. 

```Squirrel
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz

// Now read data
local val = accel.getAccel();
server.log(format("Accel: (%0.2f, %0.2f, %0.2f) (g)", val.x, val.y, val.z));
```

### Using Interrupts

The LSM9DS0 has two configurable interrupt lines. Most interrupts are available only on the Int1 pin; only methods dealing with the Int1 pin are implemented here.

Interrupt pins are active-high and push-pull by default.

#### Interrupt on Acceleration greater than 1G

```Squirrel
interrupt 	<- hardware.pin1;
i2c 		<- hardware.i2c89;

interrupt.configure(DIGITAL_IN, interruptCb);
i2c.configure(CLOCK_SPEED_400_KHZ);

accel <- LIS3DH(hardware.i2c89, LIS3DH_ADDR);

accel.setEnable(1);
accel.setDatarate(100); // 100 Hz
accel.setInertInt1En(1); // enable inertial interrupt 
accel.setInt1Ths(1.0); // trigger interrupt on 1G accel in any direction
accel.setInt1Duration(5); // require 5 samples over 1G before triggering
```

#### Interrupt on Single-Click Detection

```Squirrel
interrupt 	<- hardware.pin1;
i2c 		<- hardware.i2c89;

interrupt.configure(DIGITAL_IN, interruptCb);
i2c.configure(CLOCK_SPEED_400_KHZ);

accel <- LIS3DH(hardware.i2c89, LIS3DH_ADDR);

accel.setEnable(1);
accel.setDatarate(100); // 100 Hz
accel.setSnglclickIntEn(1); // enable single-click detection interrupt
accel.setClickTimeLimit(10); // 10 ms window for click detection
accel.setClickThs(1.2); // threshold 1.2 G for click detection
```

#### Interrupt on Free-Fall Detection

```Squirrel
interrupt 	<- hardware.pin1;
i2c 		<- hardware.i2c89;

interrupt.configure(DIGITAL_IN, interruptCb);
i2c.configure(CLOCK_SPEED_400_KHZ);

accel <- LIS3DH(hardware.i2c89, LIS3DH_ADDR);

accel.setEnable(1);
accel.setDatarate(100); // 100 Hz
accel.setFreeFallDetInt1(); 
```

## All Class Methods

#### getDeviceId()
Returns the 1-byte device ID of the sensor (from the WHO_AM_Iregister).

```Squirrel
server.log(format("Device ID: 0x%02X", accel.getDeviceId()));
```

#### setDatarate(*rate_hz*)
Set the Output Data Rate (ODR) of the accelerometer in Hz. The nearest supported data rate less than or equal to the requested rate will be used. Returns the selected ODR. Supported datarates are 0 (Shutdown), 1, 10, 25, 50, 100, 200, 400, 1600, and 5000 Hz. 

```Squirrel
local rate = accel.setDatarate(100);
server.log(format("Accelerometer running at %d Hz",rate));
```

#### setEnable(*state*)
Enable or Disable the Accelerometer. Pass in TRUE to enable the accelerometer. The accelerometer comes out of reset in shutdown mode with datarate set to 0.

#### setLowPower(*state*) 
Enable or Disable low-power mode. Pass in TRUE to enable low-power mode. Note that this will change the Datarate. 

```Squirrel
// enable low-power mode
accel.setLowPower(1);
```

#### setRange(*range_g*)
Set the measurement range of the sensor in *G*s. The default measurement range is +/- 2G. The nearest supported range less than or equal to the requested range will be used. Returns the selected range. Supported ranges are (+/-) 2, 4, 6, 8, and 16 G. 

```Squirrel
// set sensor range to +/- 6 G
local range = accel.setRange(6);
server.log(format("Range set to +/- %d G", range));
``

#### getRange()
Returns the currently-set measurement range of the sensor in G. 

```Squirrel
server.log(format("Current Sensor Range is +/- %d G", accel.getRange()));
```

#### getAccel()
Reads and returns the latest measurement from the accelerometer as a table: 

`{ x: <xData>, y: <yData>, z: <zData> }`

Units are *g*s

```Squirrel
// Enable sensor
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz

local val = accel.getAccel()
server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", val.x, val.y, val.z));
```

#### setInertInt1En(*state*)
Enable/disable inertial interrupt generator 1 on INT1 Pin. The inertial interrupt generator is used to generate interrupts on accleration over / under thresholds in any axis. Each axis can be individually configured. Different combinations of enabled axes and thresholds can detect different states. 

This method enables all three axes and configures the interrupt generator to throw an interrupt if any axis' acceleration is greater than the threshold set with *setInt1Ths(ths)*. To configure the inertial interrupt generator to detect a different condition, extend this class. 

Note that *setFreeFallDetInt1(state)* is a special case of *setInertInt1En(state)*; free fall detection configures the inertial interrupt generator to throw an interrupt when all three axes acceleration values are below the threshold value set by *setInt1Ths(ths)*. Acceleration in all three axes goes to nearly zero during a free-fall. 

```Squirrel
// Enable sensor
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz

// configure interrupt to throw on acceleration greater than 2G
accel.setInertInt1En(1); // enable inertial interrupt 
accel.setInt1Ths(2.0); // trigger interrupt on 2G accel in any direction
accel.setInt1Duration(5); // require 5 samples over 1G before triggering
```

#### setFreeFallDetInt1(*state*)
Enable/disable interrupt generation on INT1 Pin on free-fall detection. This requires that the interrupt threshold be set, as well; free fall will be detected when the acceleration in all three axes is less than the specified threshold value. 

Note that *setFreeFallDetInt1(state)* is a special case of *setInertInt1En(state)*; free fall detection configures the inertial interrupt generator to throw an interrupt when all three axes acceleration values are below the threshold value set by *setInt1Ths(ths)*. Acceleration in all three axes goes to nearly zero during a free-fall. 

```Squirrel
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz
accel.setFreeFallDetInt1(); 
```

#### setDrdyInt1En(*state*)
Enable/disable interrupt generation on INT1 Pin on Data Ready condition. 

```Squirrel
accel.setEnable(1);
accel.setDatarate(1); // 1 Hz
accel.setDrdyInt1En(1);
```

#### setIntLatch(*state*)
Enable/disable interrupt latching. If interrupt latching is enabled, the interrupt signal will remain asserted until the interrupt source register is read by calling *getInt1Src()*. If latching is disabled, the interrupt signal will remain asserted as long as the interrupt-generating condition persists.

Interrupt latching is disabled by default. 

See sample code in *getInt1Src()*.
		
#### getInt1Src()
Read the interrupt 1 source register to determine the source of an interrupt. Reading this register also clears any latched interrupts. 

Interrupt Source Register Bit Descriptions:

| Bit | Name | Description |
| --- | ---- | ----------- |
| 7 | - | Not Used |
| 6 | IA | Interrupt Active. 1 if one or more interrupts have been generated. |
| 5 | ZH | Z high |
| 4 | ZL | Z low |
| 3 | YH | Y high |
| 2 | YL | Y Low |
| 1 | XH | X high | 
| 0 | XL | X low |
 
```Squirrel
function interruptCallback() {
	if (interrupt.read()) {
		local intsrc = accel.getInt1Src();
		server.log(format("Interrupt Thrown, Int Source Register: 0x02X", intsrc));
	} else {
		server.log("Interrupt Cleared");
	}
}

// configure hardware
interrupt <- hardware.pin1;
i2c <- hardware.i2c89;

interrupt.configure(DIGITAL_IN, interruptCallback);
i2c.configure(CLOCK_SPEED_400_KHZ);

// instantiate class
accel <- LIS3DH(i2c);

// configure interrupt to throw on acceleration greater than 2G
accel.setInertInt1En(1); // enable inertial interrupt 
accel.setInt1Ths(2.0); // trigger interrupt on 2G accel in any direction
accel.setInt1Duration(5); // require 5 samples over 1G before triggering
```

#### setInt1Ths(*ths*)
Set the threshold for inertial interrupts. If used with *setInertInt1En(state)*, interrupts will be generated when the acceleration in any axis exceeds the threshold set with this method. If used with *setFreeFallDetInt1(state)*, interrupts will be generated when the acceleration in all three axes is less than the threshold set with this method. 

Thresholds are set in *g*s.

Click detection thresholds are set separately, with *setClickThs(ths)*.

#### setInt1Duration(*numsamples*)
Set the number of consecutive samples satisfying an interrupt condition to collect before generating an interrupt. This can be used to reduce spurious interrupt generation. The default setting is 0; interrupts will be generated on the first sample satisfying the interrupt condition. 

#### setSnglclickIntEn(*state*)
Enable/disable interrupt generation on single-click detection. Enables/disables detection on all three axes simultaneously. The LIS3DH allows each axis to be individually enabled or disabled; this can be acheived by extending this class. Pass in TRUE to enable single-click interrupts. Note that the click window and click threshold must both also be set in order to generate interrupts.

```Squirrel
// Enable sensor
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz

accel.setSnglclickIntEn(1); // enable single-click detection interrupt
accel.setClickTimeLimit(10); // 10 ms window for click detection
accel.setClickThs(1.2); // threshold 1.2 G for click detection
```

#### setDblclickIntEn(*state*)
Enable/disable interrupt generation on double-click detection. Enables/disables detection on all three axes simultaneously. The LIS3DH allows each axis to be individually enabled or disabled; this can be acheived by extending this class. Pass in TRUE to enable double-click interrupts. Note that the click window and click threshold must both also be set in order to generate interrupts.

```Squirrel
// Enable sensor
accel.setEnable(1);
accel.setDatarate(100); // 100 Hz

accel.setDblclickIntEn(1); // enable single-click detection interrupt
accel.setClickTimeLimit(10); // 10 ms window for click detection
accel.setClickThs(1.2); // threshold 1.2 G for click detection
```

#### setClickThs(*ths*)
Set the acceleration threshold for click detection. Thresholds are set in *g*s.

#### setClickTimeLimit(*time*)
Set the maximum time that a click condition must occur within in order to generate a click interrupt. Time is specified in milliseconds. 

#### setClickLatency(*time*) 
Set the minimum time between click events to generate a double-click interrupt. Time is specified in milliseconds. Default setting is 0. 

#### clickIntActive()
Determine if a click event is active. Returns true if a click event is currently active. 

#### dblclickDet()
Determine if a double-click event is active. Returns true if a double-click event is currently active.

#### snglclickDet()
Determine if a single-click event is active. Returns true if a single-click event is currently active.

## License

The LIS3DH class is licensed under [MIT License](./LICENSE).
