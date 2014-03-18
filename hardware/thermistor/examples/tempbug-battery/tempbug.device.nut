/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* 
 * TempBug Example Device Code
 * Tom Byrne
 * tom@electricimp.com
 * 12/5/2013
 */
 
/* GLOBALS and CONSTANTS -----------------------------------------------------*/

// all calculations are done in Kelvin
// these are constants for this particular thermistor; if using a different one,
// check your datasheet
const b_therm = 3988;
const t0_therm = 298.15;
const r_therm = 10000;
const WAKEINTERVAL_MIN = 15; // interval between wake-and-reads in minutes

/* CLASS AND GLOBAL FUNCTION DEFINITIONS -------------------------------------*/

/*
 * simple NTC thermistor
 *
 * Assumes thermistor is the high side of a resistive divider unless otherwise specified in constructor.
 * Low-side resistor is of the same nominal resistance as the thermistor
 */
class thermistor {

    // thermistor constants are shown on your thermistor datasheet
	// beta value (for the temp range your device will operate in)
	b_therm 		= null;
	t0_therm 		= null;
	// nominal resistance of the thermistor at room temperature
	r0_therm		= null;

	// analog input pin
	p_therm 		= null;
	points_per_read = null;

	high_side_therm = null;

	constructor(pin, b, t0, r, points = 10, _high_side_therm = true) {
		this.p_therm = pin;
		this.p_therm.configure(ANALOG_IN);

		// force all of these values to floats in case they come in as integers
		this.b_therm = b * 1.0;
		this.t0_therm = t0 * 1.0;
		this.r0_therm = r * 1.0;
		this.points_per_read = points * 1.0;

		this.high_side_therm = _high_side_therm;
	}

	// read thermistor in Kelvin
	function read() {
		local vdda_raw = 0;
		local vtherm_raw = 0;
		for (local i = 0; i < points_per_read; i++) {
			vdda_raw += hardware.voltage();
			vtherm_raw += p_therm.read();
		}
		local vdda = (vdda_raw / points_per_read);
		local v_therm = (vtherm_raw / points_per_read) * (vdda / 65535.0);
	
		local r_therm = 0;	
		if (high_side_therm) {
			r_therm = (vdda - v_therm) * (r0_therm / v_therm);
		} else {
			r_therm = r0_therm / ((vdda / v_therm) - 1);
		}

		local ln_therm = math.log(r0_therm / r_therm);
		local t_therm = (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
		return t_therm;
	}

	// read thermistor in Celsius
	function read_c() {
		return this.read() - 273.15;
	}

	// read thermistor in Fahrenheit
	function read_f() {
		local temp = this.read() - 273.15;
		return (temp * 9.0 / 5.0 + 32.0);
	}
}

/* REGISTER AGENT CALLBACKS --------------------------------------------------*/

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// Configure Pins
// pin 8 is driven high to turn off temp monitor (saves power) or low to read
therm_en_l <- hardware.pin8;
therm_en_l.configure(DIGITAL_OUT);
therm_en_l.write(1); 
// pin 9 is the middle of the voltage divider formed by the NTC - read the analog voltage to determine temperature
temp_sns <- hardware.pin9;
// instantiate sensor classes

// instantiate our thermistor class
myThermistor <- thermistor(temp_sns, b_therm, t0_therm, r_therm, 10, false);

therm_en_l.write(0);
imp.sleep(0.001);
local id = hardware.getdeviceid();
local datapoint = {
    "id" : id,
    "temp" : format("%.2f",myThermistor.read_f())
}
agent.send("data",datapoint);
therm_en_l.write(1);

//Sleep for 15 minutes and 1 second, minus the time past the 0:15
//so we wake up near each 15 minute mark (prevents drifting on slow DHCP)
imp.onidle( function() { 
    server.sleepfor(1 + WAKEINTERVAL_MIN*60 - (time() % (WAKEINTERVAL_MIN*60))); 
});

// full firmware is reloaded and run from the top on each wake cycle, so no need to construct a loop