Thermistor Class
==============
This class makes it easy to work with NTC thermistors, which can be used as low-cost analog tempreature sensors. For an example application, see the [TempBug Instructable.](http://www.instructables.com/id/TempBug-internet-connected-thermometer/)


Contributors
===================================
Tom Byrne

Usage
===================================

Thermistors are used by forming a resistive divider with the thermistor and a fixed resistor of equal nominal value. The middle of the divider is measured with an analog input. Knowing the voltage at the top and the center of the divider, the resistance of the thermistor can be calculated. The thermistor's temperature can then be derived, given several characteristic parameters about the thermistor. The following parameters are required and can be found in the thermistor data sheet:

| Parameter | Meaning |
|-----------|---------|
| ß | Describes the relationship between resistance and temperature according to the ß-parameter equation. Typically, several ß values are provided with various temperature ranges. Select the one for the temperature range in which your device will be operating |
| T0 | Temperature at which the nominal resistance of the thermistor is measured. Typically room temperature, approximately 25ºC |
| R | Nominal resistance of the thermistor. This is the value which should be used for the other resistor in the divider, as well. 10kΩ and 100kΩ NTC thermistors are very common. |

The class takes three to five parameters. The first three are the characteristics of the thermistor and are required. The fourth is the number of points to record per reading. The points are averaged to improve accuracy. The parameter defaults to ten.

This class also takes a fifth optional parameter, "high_side_therm", which is true by default. This assumes that the thermistor is in the top of the resistive divider. If the thermistor forms the bottom half of the divider, this parameter must be set false. 

```
// check your datasheet
const b_therm = 3988;
const t0_therm = 298.15;
const r_therm = 10000;

local therm_pin <- hardware.pin1;
therm_pin.configure(ANALOG_IN);
local myThermistor = thermistor(therm_pin, b_therm, t0_therm, r_therm);
```