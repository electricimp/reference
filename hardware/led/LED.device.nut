// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// LED blinker class. 
// Blinks an LED on a given hardware.pin for a given number of repetitions in a given on/off pattern
// Also demonstrates the use of "generators".
class LED {

    _pin = null;
    _gen = null;
    _timer = null;
    _offState = null;

    constructor(pin, offState = 0) {
        _pin      = pin;
        _offState = offState ? 1 : 0;
        _pin.configure(DIGITAL_OUT, _offState);
    }
    
    function on() { 
        _pin.write(1-_offState); 
    }

    function off() {
         _pin.write(_offState);  
    }

    function cancel() {
        off();
        if (_timer) imp.cancelwakeup(_timer);
        _timer = null;
    }

    function blink(cnt, onTime=0.33, offTime=0.66, callback=null) {
        cancel();

        resume ( _gen = function(cnt, onTime, offTime,callback) {
            for(local i = 0; i < cnt; i++) {

                on();
                _timer = imp.wakeup(onTime, function() {
                    _timer = null;
                    resume _gen;
                }.bindenv(this));
                yield;

                off();
                _timer = imp.wakeup(onTime, function() {
                    _timer = null;
                    resume _gen;
                }.bindenv(this));
                yield;
            }

            if (callback) callback();
            _timer = null;
        }(cnt, onTime, offTime, callback));
        
    }
}
