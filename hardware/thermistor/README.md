#Thermistor Class
This class makes it simple for an imp to read an NTC ("Negative Temperature Coefficient") Thermistor and determine the temperature. Thermistors are essentially temperature-dependent resistors. To use as a thermometer, a thermistor is used as half of a resistive divider, where the voltage across the full divider is known. The Imp then reads the voltage at the center of the divider to determine the resistance of the thermistor, [from which the temperature can be derived.](http://en.wikipedia.org/wiki/Thermistor) 


#How To Use
## Hardware
A resistive divider can be formed with the thermistor on the top or the bottom; this class allows for either configuration. The top of the divider should be connected to the same rail as the Imp's VDDA pin (or VDD pin, in the case of the Imp card, as VDD and VDDA are internally connected). The bottom of the divider should be connected to ground. 

The center of the divider must be connected to a pin capable of analog input. On the Imp card, any pin can be used as an analog input. On the Imp module, only some pins can be configured this way, so check the [Imp Pin Mux Chart](http://electricimp.com/docs/hardware/imp/pinmux/).

##Software
The thermistor class takes four to six parameters (4 required, 2 optional):
temp_sns, b_therm, t0_therm, r_therm, 10, false);

| Parameter Name | Description | Optional/Required |
|----------------|-------------|-------------------|
| temp_sns | Imp Pin, capable of ANALOG_IN | Required |
| b_therm | Thermistor ß parameter, from datasheet | Required |
| t0_therm | Thermistor T0 parameter, from datasheet | Required |
| r_therm | Thermistor nominal resistance, from datasheet | Required |
| points | number of readings to average when reading the thermistor | Optional, defaults to 10 |
| high_side_therm | Set FALSE to place thermistor on low side of divider | Optional, defaults to TRUE |

The ß, T0, and R parameters are all available on the thermistor datasheet:

| Parameter | Meaning |
|-----------|---------|
| ß | Characteristic of the thermistor. Most thermistors have many ß values listed, for various temperature ranges. Choose the value for the temperature range you will be operating in. |
| T0 | Temperature at which the nominal resistance (R) of the thermistor is measured. Typically room temperature (~25ºC) |
| R | Nominal resistance of the thermistor. 10kΩ NTC thermistors are common and used in examples here. |

Instantiating and reading the thermistor object:

	const b_therm = 3988;
	const t0_therm = 298.15;
	const r_therm = 10000;
	
	temp_sns <- hardware.pin9;
	
	// thermistor on bottom of divider
	myThermistor <- thermistor(temp_sns, b_therm, t0_therm, r_therm, 10, false);
	
	local temp_f = myThermistor.read_f();

