class PulseSensor {
	_pulsePin = null;
	
	// polling
	_onChange = null;
	_pollTimer = null;
	_pollWakeup = null;
	_threshold = null;
	_lastValue = null;
		
	constructor(pin, onChange = null, pollTimer = 0.1, threshold = 35000) {
		_pulsePin = pin;
		_pulsePin.configure(ANALOG_IN);
		
		_threshold = threshold;
		_onChange = onChange;
		_pollTimer = pollTimer;
		
		start();
	}
	
	function read() {
		return _pulsePin.read();
	}
	
	function readState() {
		return (read() >= _threshold);
	}
	
	function start() {
		if (_pollTimer != null) {
			_lastValue = readState();
			_poll();
		}
	}
	
	function stop() {
		if (_pollWakeup != null) {
			imp.cancelwakeup(_pollWakeup);
			_pollWakeup = null;
		}
	}

	/******************** PRIVATE FUNCTIONS ********************/
	function _poll() {
		_pollTimer = imp.wakeup(0.1, _poll.bindenv(this));
		local val = readState();
		if (val != _lastValue) {
			_lastValue = val;
			_onChange(val);
		}
	}
}

led <- hardware.pin7;
led.configure(DIGITAL_OUT);

pulse <- PulseSensor(hardware.pin2, function(state) {
	led.write(state);
	local pinValues = {
		pin2 = hardware.pin2.read(),
		voltage = hardware.voltage()
	}	
	
	agent.send("impValues", pinValues);	
});
