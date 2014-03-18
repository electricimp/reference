// Copyright (C) 2014 electric imp, inc.
// TempBug Simple Example Device Code
 
/* GLOBALS and CONSTANTS -----------------------------------------------------*/

// all calculations are done in Kelvin
// these are constants for this particular thermistor; if using a different one,
// check your datasheet
const b_therm = 3988;
const t0_therm = 298.15;
const r_therm = 10000;
const INTERVAL = 900; // interval between wake-and-reads in seconds (15 minutes)

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

function getTemp() {
	// schedule the next temperature reading
	imp.wakeup(INTERVAL, getTemp);

	// hardware id is used to separate feeds on Xively, so provide it with the data
	local id = hardware.getdeviceid();
	// tempreature can also be returned in Kelvin or Celsius
	local datapoint = {
	    "id" : id,
	    "temp" : format("%.2f",myThermistor.read_f())
	}
	agent.send("data",datapoint);
}

/* REGISTER AGENT CALLBACKS --------------------------------------------------*/

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

// Configure Pins
// pin 9 is the middle of the voltage divider formed by the NTC - read the analog voltage to determine temperature
temp_sns <- hardware.pin7;
// instantiate sensor classes

// instantiate our thermistor class
// this shows the thermistor on the bottom of the divider
myThermistor <- thermistor(temp_sns, b_therm, t0_therm, r_therm, 10, false);

// this function will schedule itself to re-run after it is first called
// just call it once to start the loop.
getTemp();

