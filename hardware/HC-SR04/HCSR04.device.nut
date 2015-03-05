// Ultrasonic Range Sensor HC-SR04
// https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE/edit
// Ultrasonic Range Sensor HC-SR04
// https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE/edit
class HCSR04 {
    // consts
    static TO = 500; // timeout in ms
    
    // pins
    _trig   = null;
    _echo   = null;

    // aliased methods
    _tw     = null;
    _er     = null;
    _hu     = null;
    _hm     = null;

    // vars
    _es     = null; // echo start time
    _ee     = null; // echo end time

    constructor(trig, echo) {
        _trig = trig;
        _echo = echo;

        _hu   = hardware.micros.bindenv(hardware);
        _hm   = hardware.millis.bindenv(hardware);
        _tw   = _trig.write.bindenv(_trig);
        _er   = _trig.read.bindenv(_echo);
    }

    function read_cm() {
        local st = _hm(); // start time for timeout
        // Quickly pulse the trig pin
        _tw(0); _tw(1); _tw(0);

        // Wait for the rising edge on echo
        while (_er() == 0 && (_hm() - st) < TO);
        _es = _hu();

        // Time to the falling edge on echo
        while (_er() == 1 && (_hm() - st) < TO);
        _ee = _hu();

        //if ((_hm() - st) >= TO) return -1;
        return (_ee - _es)/58.0;
    }
}

// Ex Usage
// trig <- hardware.pin8;
// echo <- hardware.pin9;

// trig.configure(DIGITAL_OUT,0);
// echo.configure(DIGITAL_IN);

// range <- HCSR04(trig, echo);
// server.log(range.read_cm()+" cm"");
