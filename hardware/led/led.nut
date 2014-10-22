class LED{
    _pin = null;
    _gen = null;
    _timer = null;
    _offState = null;

    constructor(pin, offState = 0){
        _pin      = pin;
        _offState = offState? 1 : 0;
        _pin.configure(DIGITAL_OUT, _offState);
    }
    
    function on(){ _pin.write(1-_offState); }

    function off(){ _pin.write(_offState);  }

    function cancel(){
        off();
        if (_timer != null) imp.cancelwakeup(_timer);
        _timer = null;
    }

    function blink(cnt, onTime=0.33, offTime=0.66, callback=null){
        cancel();

        resume ( _gen =     function(cnt, onTime, offTime,callback){
            for(local i = 0; i < cnt; i++){
                on();
                _timer = imp.wakeup(onTime, function(){resume _gen}.bindenv(this));
                yield;
                off();
                _timer = imp.wakeup(onTime, function(){resume _gen}.bindenv(this));
                yield;
            }
            if (typeof callback == "function") callback();
            _timer = null;
        }(cnt, onTime, offTime, callback));
        
    }
}


//Example Instantiation
red <- LED(hardware.pin2);

//3 fast blinks followed by 3 slow blinks
red.blink(3, 0.2, 0.4, function(){ red.blink(3, 0.6, 1.2, function(){server.log("Done blinking")})});