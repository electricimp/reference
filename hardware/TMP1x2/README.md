# Driver for the TMP1x2 Family of Temperature Sensors

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [TMP1x2 family](http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf) are simple, low-cost digital temperature sensors with an interrupt pin. The TMP1x2 interfaces with the imp over I&sup2;C.

## Class Usage

### Constructor

The class’ constructor takes one required parameter (a configured imp I&sup2;C bus) and two optional parameters:

| Parameter     | Type         | Default | Description |
| ------------- | ------------ | ------- | ----------- |
| i2cBus        | hardware.i2c | N/A     | A pre-configured I&sup2;C bus |
| i2cAccellAddr | byte         | 0x90    | The I&sup2;C address of the TMP1x2 |


```Squirrel
i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
tempsensor <- TMP1x2(i2c, 0x92); // using a non-default I2C address (SA0 pulled high)
```

### Enabling and Reading Data

The TMP1x2 comes out of reset in "Shutdown/One-Shot" Mode. In this mode, temperature conversions are performed only as requested in order to save power. Interrupts do not operate in Shutdown Mode. The temperature can be read immediately when the sensor comes out of reset, however.

```Squirrel
server.log(format("Current Temperature is %0.2f degrees C", tempsensor.getTemp()));
```

### Using Interrupts

To use interrupts, place the sensor in continuous-conversion mode by calling *setShutdown(0)*. 

The TMP1x2 has two modes with regard to interrupt: Comparator mode and Interrupt mode. The sensor operates in comparator mode by default.

In Comparator mode, the alert pin is asserted whenever the temperature exceeds the high threshold, and remains asserted until the temperature goes below the low threshold.

In Interrupt mode, the alert pin is asserted whenever the temperature exceeds the high threshold or goes below the low threshold. The alert pin remains asserted until the temperature register is read. 

The TMP1x2's alert pin can be configured as active-low or active-high. The driver supports open-drain only, though; active-low is recommended for any application requiring low-power standby. If low-power standby and an active-high interrupt are required (to wake the imp, for instance), it is recommended that the TMP1x2 be used in active-low mode with an inverter on the alert line. 

#### Example: Comparator Mode

```Squirrel
function interruptCallback() {
	// interrupt is active-low
	if (interrupt.read()) {
		server.log("Temperature dropped below low threshold");
	} else {
		server.log("Temperature exceeded high threshold");
	}
}

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
interrupt <- hardware.pin1;
tempsensor <- TMP1x2(i2c);

// place sensor in continuous-conversion mode
tempsensor.setShutdown(0);
// set thresholds
tempsensor.setHighThreshold(35.0);
tempsensor.setLowTheshold(25.0);
```

#### Example: Interrupt Mode

```Squirrel
function interruptCallback() {
	// interrupt is active-low
	if (interrupt.read()) {
		server.log("Temperature dropped below low threshold");
	} else {
		server.log("Temperature exceeded high threshold");
	}
}

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);
interrupt <- hardware.pin1;
tempsensor <- TMP1x2(i2c);

// place sensor in continuous-conversion mode
tempsensor.setShutdown(0);
// set mode
tempsensor.setModeInterrupt();
// set thresholds
tempsensor.setHighThreshold(35.0);
tempsensor.setLowTheshold(25.0);
```

## All Class Methods

#### getTemp([*callback*])
Read the current temperature. This function takes an optional callback function which takes one parameter. The callback function will be called when the temperature reading is complete or times out, with a table as a parameter. If an error occurs, the table passed into the callback will be of the form:

`{"err": <error description>, "temp": null}`

If no error occurs, the table will contain only the "temp" key with the temperature in degrees Celsius:

`{"temp": 25.2}`

If *getTemp* is called without a callback function, it executes synchronously and will return a table of the forms above.

Asynchronous read:

```Squirrel
tempsensor.getTemp(function(result) {
	if ("err" in result) {
		server.log("Error Reading Temperature: "+result.err);
	} else {
		server.log(format("Current Temperature: %0.2f degrees C", result.temp));
	}
});
```

Synchronous read:

```Squirrel
local result = tempsensor.getTemp(); 
if ("err" in result) {
    server.log("Error Reading Temperature: "+result.err);
} else {
    server.log(format("Current Temperature: %0.2f ºC", result.temp));
}
```

#### setShutdown(*state*)
Enable/Disable continuous conversion mode. The TMP1x2 comes out of reset in shutdown ("one-shot") mode by default. In this mode, conversions are performed only upon request to save power, and interrupts do not function. Pass in FALSE to place the sensor in continuous conversion mode.

#### setModeComparator()
Place the sensor in Comparator mode. In this mode, the alert pin is asserted whenever the temperature exceeds the high threshold, and remains asserted until the temperature goes below the low threshold. 

The TMP1x2 comes out of reset in Comparator mode.

#### setModeInterrupt()
Place the sensor in Interrupt mode. In this mode, the alert pin is asserted whenever the temperature exceeds the high threshold or goes below the low threshold. The alert pin remains asserted until the temperature register is read. 

#### setLowThreshold(*threshold*)
Set the low threshold for interrupts in degrees Celsius. The threshold registers can hold values from -128 degrees to 128 degrees Celsius in normal mode, or -255 to 255 degrees in extended mode. Note that the device only operates from -40 to +125 degrees Celsius.

#### setHighThreshold(*threshold*)
Set the high threshold for interrupts in degrees Celsius.

#### setActiveLow()
Configure the alert pin as an active-low output. This is the default configuration of the alert pin, and recommended for low-power applications.

#### setActiveHigh()
Configure the alert pin as an active-high output. The alert pin driver is open-drain, so a pull-up resistor is required. 

#### setExtMode(*state*)
Place the sensor in extended mode. In extended mode, the sensor can measure temperatures greater than 128 degrees by switching the temperature and threshold registers from the normal 12-bit format to an extended, 13-bit format.

The device operates in normal mode by default.

## License

The LIS3DH class is licensed under [MIT License](./LICENSE).
