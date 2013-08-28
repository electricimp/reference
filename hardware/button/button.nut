// ----------------------------------------------------------------------------  
// Name: Button
// Purpose: Show the right way to debounce a button press
// ---------------------------------------------------------------------------- 
 
class button{
    static NORMALLY_HIGH = 1;
    static NORMALLY_LOW  = 0;
    _pin             = null;
	_pull            = null;
    _polarity        = null;
    _pressCallback   = null;
    _releaseCallback = null;

	constructor(pin, pull, polarity, pressCallback, releaseCallback){
		_pin             = pin;               //Unconfigured IO pin, eg hardware.pin2
        _pull            = pull;              //DIGITAL_IN_PULLDOWN, DIGITAL_IN or DIGITAL_IN_PULLUP
		_polarity        = polarity;          //Normal button state, ie 1 if button is pulled up and the button shorts to GND
		_pressCallback   = pressCallback;     //Function to call on a button press (may be null)
		_releaseCallback = releaseCallback;   //Function to call on a button release (may be null)

		_pin.configure(_pull, debounce.bindenv(this));
	}

	function debounce(){
		_pin.configure(_pull);
        imp.wakeup(0.010, getState.bindenv(this));  //Based on googling, bounce times are usually limited to 10ms
	}

	function getState(){ 
		if( _polarity == _pin.read() ){
			if(_releaseCallback != null){
				_releaseCallback();
			}
		}else{
			if(_pressCallback != null){
				_pressCallback();
			}
		}
		_pin.configure(_pull, debounce.bindenv(this)); 
	}
}

//Example Instantiation
b1 <- button(hardware.pin1, DIGITAL_IN_PULLUP, button.NORMALLY_HIGH,
            function(){server.log("Button 1 Pressed")},
            function(){server.log("Button 1 released")}
            );

