// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class thermistor {

    // thermistor constants are shown on your thermistor datasheet
    // beta value (for the temp range your device will operate in)
    b_therm = null;
    t0_therm = null;
    // analog input pin
    p_therm = null;
    points_per_read = null;

    high_side_therm = null;

    constructor(pin, b, t0, points = 10, _high_side_therm = true) {
        this.p_therm = pin;
        this.p_therm.configure(ANALOG_IN);

        // force all of these values to floats in case they come in as integers
        this.b_therm = b * 1.0;
        this.t0_therm = t0 * 1.0;
        this.points_per_read = points * 1.0;
        this.high_side_therm = _high_side_therm;
    }

    // read thermistor in Kelvin
    function read() {
        local vrat_raw = 0;
        for (local i = 0; i < points_per_read; i++) {
            vrat_raw += p_therm.read();
            imp.sleep(0.001); // sleep to allow thermistor pin to recharge
        }
        local v_rat = vrat_raw / (points_per_read * 65535.0);

        local ln_therm = 0;	
        if (high_side_therm) {
            ln_therm = math.log(v_rat / (1.0 - v_rat));
        } else {
            ln_therm = math.log((1.0 - v_rat) / v_rat);
        }

        return (t0_therm * b_therm) / (b_therm - t0_therm * ln_therm);
    }

    // read thermistor in Celsius
    function read_c() {
        return this.read() - 273.15;
    }

    // read thermistor in Fahrenheit
    function read_f() {
        return ((this.read() - 273.15) * 9.0 / 5.0 + 32.0);
    }
}
