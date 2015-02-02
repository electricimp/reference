class Thermistor {
    // Copyright (c) 2014 Electric Imp
    // This file is licensed under the MIT License
    // http://opensource.org/licenses/MIT

    // thermistor constants are shown on your thermistor datasheet
    // beta value (for the temp range your device will operate in)
    _b_therm = null;
    _t0_therm = null;

    // analog input pin
    _p_therm = null;

    _points = null;   // points_per_read
    _highside = null; // high_side_therm

    constructor(pin, b, t0, points = 10, highside = true) {
        _p_therm = pin;
        _p_therm.configure(ANALOG_IN);

        // force all of these values to floats in case they come in as integers
        _b_therm = b * 1.0;
        _t0_therm = t0 * 1.0;

        _points = points * 1.0;   
        _highside = highside;   
    }

    // read thermistor in Kelvin
    function read() {
        local vrat_raw = 0;
        for (local i = 0; i < _points; i++) {
            vrat_raw += _p_therm.read();
            imp.sleep(0.001); // sleep to allow thermistor pin to recharge
        }
        local v_rat = vrat_raw / (_points * 65535.0);

        local ln_therm = 0;	
        if (_highside) {
            ln_therm = math.log(v_rat / (1.0 - v_rat));
        } else {
            ln_therm = math.log((1.0 - v_rat) / v_rat);
        }

        return (_t0_therm * _b_therm) / (_b_therm - _t0_therm * ln_therm);
    }

    // read thermistor in Celsius
    function readC() {
        return read() - 273.15;
    }

    // read thermistor in Fahrenheit
    function readF() {
        return ((read() - 273.15) * 9.0 / 5.0 + 32.0);
    }
}
