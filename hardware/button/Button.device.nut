// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Description: Debounced button press with callbacks
class Button {

    static NORMALLY_HIGH = 1;
    static NORMALLY_LOW  = 0;

    _pin             = null;
    _pull            = null;
    _polarity        = null;
    _pressCallback   = null;
    _releaseCallback = null;

    /* Constructor
     * pin              - Unconfigured IO pin, eg hardware.pin2
     * pull             - DIGITAL_IN_PULLDOWN, DIGITAL_IN or DIGITAL_IN_PULLUP
     * polarity         - Button.NORMALLY_HIGH or Button.NORMALLY_LOW
     * pressCallback    - Optional Function to call on a button press (may be null)
     * releaseCallback  - Optional Function to call on a button release (may be null)
     */
    constructor(pin, pull, polarity, pressCallback = null, releaseCallback = null) {
        _pin             = pin;               
        _pull            = pull;              
        _polarity        = polarity;          
        _pressCallback   = pressCallback;     
        _releaseCallback = releaseCallback;   

        _pin.configure(_pull, _debounce.bindenv(this));
    }

    // Used internally to capture the pin state change event
    function _debounce(){
        _pin.configure(_pull);
        imp.wakeup(0.01, getState.bindenv(this));  //Based on googling, bounce times are usually limited to 10ms
    }

    // Used internally at the end of the debounce time
    function _getState(){ 
        if (_polarity == _pin.read()) {
            if (_releaseCallback) _releaseCallback();
        } else {
            if (_pressCallback) _pressCallback();
        }
        _pin.configure(_pull, debounce.bindenv(this)); 
    }
}
