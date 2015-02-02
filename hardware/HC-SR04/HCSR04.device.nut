// Ultrasonic Range Sensor HC-SR04
// https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE/edit
class HCSR04 {
    // pins
    _trig   = null;
    _echo   = null;

    // aliased methods
    _tw     = null;
    _er     = null;
    _hm     = null;

    // vars
    _es     = null; // echo start time
    _ee     = null; // echo end time

    constructor(trig, echo) {
        _trig = trig;
        _echo = echo;

        _hm   = hardware.micros.bindenv(hardware);
        _tw   = _trig.write.bindenv(_trig);
        _er   = _trig.read.bindenv(_echo);
    }

    function read_cm() {
        // Quickly pulse the trig pin
        _tw(0); _tw(1); _tw(0);

        // Wait for the rising edge on echo
        while (_er() == 0);
        _es = _hm();

        // Time to the falling edge on echo
        while (_er() == 1);
        _ee = _hm();

        return (_ee - _es)/58.0;
    }
    
    function read_in() {
        return read_cm() * (58.0 / 148.0);
    }
}

// Ex Usage
// trig <- hardware.pin8;
// echo <- hardware.pin9;

// trig.configure(DIGITAL_OUT,0);
// echo.configure(DIGITAL_IN);

// range <- HCSR04(trig, echo);
// server.log(range.read_in()+"\"");
