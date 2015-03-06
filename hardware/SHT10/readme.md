Driver for the SHT10 Temperature/Humidity Sensor
===================================

Author: [Juan Albanell](https://github.com/juanderful11/)

Driver class for a [DHT10 temperature/humidity sensor](http://www.adafruit.com/datasheets/Sensirion_Humidity_SHT1x_Datasheet_V5.pdf), available from [Adafruit](http://www.adafruit.com/product/1298).


## Hardware Setup
The SHT1x family uses a proprietary one-wire protocol. The imp emulates this protocol via bit-banging. 

| SHT10 Pin | Wire Color (for Adafruit Sensor in Housing) | Imp Pin |
| --------- | ------------------------------------------- | ------- |
| V<sub>DD</sub> | Red | 3V3 |
| GND | Green | GND |
| CLK | Yellow | Any GPIO |
| DATA | Blue | Any GPIO with state-change callback support |

Contrary to the warning on Adafruit's page for this device, a 10kΩ pull-up resistor is not required on the DATA line; this class sets the imp's internal pull-up instead.

![Connecting a SHT10 to an Electric Imp Card](SHT10_bb.png "Connection Diagram")

## Usage

#### Instantiation
Call the constructor with two arguments: the clock and data pins, respectively. Both pins should be configured as DIGITAL_OUT. Note that the Data pin will be reconfigured to DIGITAL_IN_PULLUP while reading data.

The constructor will issue a soft reset to the device, then read the status register to confirm the resolution setting that the device is using. The class automatically selects the proper temperature and relative humidity calculation constants for the selected measurement resolution.

```Javascript
clk <- hardware.pin5;
dta <- hardware.pin7;
clk.configure(DIGITAL_OUT);
dta.configure(DIGITAL_OUT);
sht10 <- SHT10(clk, dta);
```

####getTemp(*callback*)
Read the current temperature, asynchronously. This method takes a single argument: a callback function. The callback function must take one argument. 

A table will be passed to the callback when the measurement is complete. If the measurement is successful, the table will contain the "temp" key with the temperature data. If an error occurs, the table will contain the "err" key with the error text.

```Javascript
sht10.readTemp( function(result) {
    if ("err" in result) {
        server.error(result.err);
        return;
    }
    server.log(format("Temperature: %0.1f C", result.temp));
});
```

####getTempRh(*callback*, [*temperature*])
Read the current temperature and humidity, asynchronously. No "getRh" method is provided as the temperature is required to determine the relative humidity. This method takes two methods: a callback function to be called when the measurement is complete, and an optional temperature value in degrees Celsius. If no temperature is provided, this method will call getTemp internally to obtain the current temperature. 

The callback function must accept a single parameter (a table). The table passed to the callback will contain the keys "temp" and "rh" upon a successful reading, both containing floats. Temperature is given in degrees Celsius and Relative Humidity as a percentage. 

If an error occurs, the table will contain the "err" key with the error text.

```Javascript
sht10.readTempRh( function(result) {
    if ("err" in result) {
        server.error(result.err);
        return;
    }
    server.log(format("Temperature: %0.1f C & Humidity: %0.1f", result.temp, result.rh) + "%");
});
```

####getStatus() 
Returns the current settings of the sensor in a table. If an error occurs, only the "err" key will be present in the table, with the error text. The following keys are present in the table upon success: 

| key | value | default |
| --- | ----- | ------- |
| lowVoltDet | (bool) supply voltage < 2.47V detected by sensor | not set |
| heater | (bool) true for heater enabled | 0 |
| noReloadFromOTP | (bool) true if the "do not reload calibration data from OTP before each reading" bit is set | 0 |
| rhRes | relative humidity measurement resolution | 12 |
| tempRes | temperature measurement resolution | 14 |


```Javascript
local status = sht10.getStatus();
if ("err" in status) server.error(status.err);
else {
    server.log("SHT10 Status:");
    server.log("Low Voltage Det: "+status.lowVoltDet);
    server.log("Heater: "+status.heater);
    server.log("No Reload From OTP: "+status.noReloadFromOTP);
    server.log("RH resolution: "+status.rhRes+" bits");
    server.log("Temp resolution: "+status.tempRes+" bits");
}
```

####setLowRes()
Sets the resolution setting for temperature and humidity measurements to the lower available setting. In this setting the temperature resolution is 12 bits, and the relative humidity resolution is 8 bits. 

```Javascript
// set low resolution
sht10.setLowRes();
```

####setHighRes()
Sets the resolution setting for the temperature and humidity measurements to the higher available setting. In this setting the temperature resolution is 14 bits, and the relative humidity resolution is 12 bits. This is the default setting.

```Javascript
// set default resolution
sht10.setHighRes();
```

####setHeater(state)
Sets the state of the internal heater. This may increase the temperature reading 5º to 10ºC. The heater consumes 8 mA. The SHT10 is not intended to run the heater continuously. 

```Javascript
// enable heater (I wouldn't)
sht10.setHeater(1);
```

####setOtpReload(state) 
Determines whether to reload calibration constants from OTP memory on each reading. This option is enabled by default. Disabling this option may increase measurement speed by about 10ms. It is not clear what disabling this option will do to measurement accuracy or precision.

```Javascript
// disable OTP reload (I wouldn't)
sht10.setOtpReload(0);
```

####softReset()
Issues a soft reset to the device. This resets the contents of the STATUS register to the default values (high resolution, heater off, reload from OTP). This call blocks for approximately 11 ms. This function is automatically called by the constructor at instantiation.

```Javascript
// reset the SHT10 to default settings
sht10.softReset();
```