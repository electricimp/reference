// Ambient Light Sensor APDS-9007-020
// http://www.avagotech.com/docs/AV02-0512EN
// Logarithmic Analog Current Output; drive into load resistor and buffer
// Read with Analog Input
class APDS9007 {
    static WAIT_BEFORE_READ = 0; // set to non-zero value if using output filter cap
    RLOAD = null; // value of load resistor on ALS (device has current output)
    
    _als_pin            = null;
    _als_en             = null;
    _points_per_read    = null;
    
    // -------------------------------------------------------------------------
    constructor(als_pin, rload, als_en = null, points_per_read = 10) {
        _als_pin = als_pin;
        _als_en = als_en;
        RLOAD = rload;
        _points_per_read = points_per_read * 1.0; //force to a float
    }
    
    // -------------------------------------------------------------------------
    // read the ALS and return value in lux
    function read() {
        if (_als_en) {
            _als_en.write(1);
            imp.sleep(WAIT_BEFORE_READ);
        }
        local Vpin = 0;
        local Vcc = 0;
        // average several readings for improved precision
        for (local i = 0; i < _points_per_read; i++) {
            Vpin += _als_pin.read();
            Vcc += hardware.voltage();
        }
        Vpin = (Vpin * 1.0) / _points_per_read;
        Vcc = (Vcc * 1.0) / _points_per_read;
        Vpin = (Vpin / 65535.0) * Vcc;
        local Iout = (Vpin / RLOAD) * 1000000.0; // current in µA
        if (_als_en) _als_en.write(0);
        return (math.pow(10.0,(Iout/10.0)));
    }
}