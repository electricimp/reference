class Impeeduino {
	
	static version = [0, 0, 0]
	
	static BAUD_RATE = 115200;
	static DIGITAL_READ_TIME = 0.01;
	
	static MASK_OP = 0xF0;
	static OP_CONFIGURE  = 0x80;
	static OP_DIGITAL_READ  = 0x90;
	static OP_DIGITAL_WRITE_0  = 0xA0;
	static OP_DIGITAL_WRITE_1 = 0xB0;
	static OP_ANALOG = 0xE0;
	static OP_ARB = 0xF0;

	static MASK_CONFIG = 0x0F;
	static CONFIG_INPUT = 0x00;
	static CONFIG_INPUT_PULLUP = 0x01;
	static CONFIG_OUTPUT = 0x02;
	static CONFIG_OUTPUT_PWM = 0x03;
	
	static MASK_DIGITAL_ADDR = 0x0F;
	static MASK_DIGITAL_WRITE = 0x10;
	static MASK_ANALOG_W = 0x08;
	static MASK_ANALOG_ADDR = 0x07;
	static MASK_CALL = 0x1F;
    
    _rxBuf   = null; // Buffer for incoming data
    _funcBuf = null; // Buffer for function return values
	_serial  = null; // UART bus to communicate with AVR
    _reset   = null; // AVR reset pin
    _pinsPWM = null; // PWM enabled pins
    
    constructor(serial = hardware.uart57, reset = hardware.pin1) {
    	_serial = serial;
    	_serial.configure(BAUD_RATE, 8, PARITY_NONE, 1, NO_CTSRTS, uartEvent.bindenv(this));
    	
    	_reset = reset;
	    _reset.configure(DIGITAL_OUT);
	    
	    // Define PWM enabled pins
	    _pinsPWM = {};
	    _pinsPWM[3]  <- 0;
	    _pinsPWM[5]  <- 1;
	    _pinsPWM[6]  <- 2;
	    _pinsPWM[9]  <- 3;
	    _pinsPWM[10] <- 4;
	    _pinsPWM[11] <- 5;
	    
	    _funcBuf = blob();
	    _rxBuf = blob();
	    
	    this.reset();
	}
	
	function parseRXBuffer() {
		local buf = _rxBuf;
		_rxBuf = blob();
		buf.seek(0, 'b');
		local readByte = 0;
		while (!buf.eos()) {
			readByte = buf.readn('b');
			if (readByte & 0x80) {
				// Interpret as Opcode
			} else {
				// Save ASCII data to function return buffer
				_funcBuf.seek(0, 'e');
				_funcBuf.writen(readByte, 'b');
			}
		}
	}
	
	function uartEvent() {
		_rxBuf.seek(0, 'e');
		_rxBuf.writeblob(_serial.readblob());
		parseRXBuffer();
		if (_funcBuf[0] == 0)
		    _funcBuf[0] = 0x20
		server.log(format("%s", _funcBuf.tostring()));
	}
	
	function reset() {
        server.log("Resetting Duino...")
        _reset.write(1);
        imp.sleep(0.2);
        _reset.write(0);
    }
    
    // Configures the specified GPIO pin to behave either as an input or an output.
    function pinMode(pin, mode) {
    	_serial.write(OP_CONFIGURE | pin);
    	server.log("Configuring " + pin);
    	switch (mode) {
    	case DIGITAL_IN:
    		_serial.write(OP_ARB | CONFIG_INPUT);
    		break;
    	case DIGITAL_IN_PULLUP:
    		_serial.write(OP_ARB | CONFIG_INPUT_PULLUP);
    		break;
    	case DIGITAL_OUT:
    		server.log("to Output");
    		_serial.write(OP_ARB | CONFIG_OUTPUT);
    		break;
    	case PWM_OUT:
    		assert (pin in _pinsPWM);
    		_serial.write(OP_ARB | CONFIG_OUTPUT_PWM);
    		break;
    	default:
    		server.error("Invalid pin mode: " + mode);
    		_serial.write(OP_ARB | CONFIG_INPUT);
    		break;
    	}
    }
    
    // Writes a value to a digital pin
    function digitalWrite(pin, value) {
    	assert (typeof value == "integer" || typeof value == "bool");
    	server.log("Writing " + value + " to " + pin);
    	if (value) {
			_serial.write(OP_DIGITAL_WRITE_1 | pin);
		} else {
			_serial.write(OP_DIGITAL_WRITE_0 | pin);
		}
		_serial.flush();
    }
    
    // Reads the value from a specified digital pin
    function digitalRead(pin, cb = null) {
    	_serial.write(OP_DIGITAL_READ | pin);
    	_serial.flush();
    	
    	if (cb) {
			imp.wakeup(DIGITAL_READ_TIME, function() {
				cb({ "value": _pinState[pin]});
			}.bindenv(this));
		} else {
			local target = OP_DIGITAL_WRITE_0 | pin; // Search for ops with a digital write pattern and addr = pin
			local readByte = _serial.read();
			while (readByte & target != target) {
			 	 // Save other data to buffer
			 	_rxBuf.seek(0, 'e');
				_rxBuf.writen(readByte, 'b');
				readByte = _serial.read();
			}
			imp.wakeup(0, parseRXBuffer);
			return readByte & MASK_DIGITAL_WRITE ? 1 : 0;
		}
    }
    
    // Reads the value from the specified analog pin. The Arduino board contains a 6 channel , 10-bit analog to digital converter.
    function analogRead(pin) {
    	_serial.write(OP_ANALOG | _pinsPWM[pin]);
    	_serial.flush();
    	
    }
    
    // Writes an analog value (PWM wave) to a pin. value represents the duty cycle and ranges between 0 (off) and 255 (always on).
    function analogWrite(pin, value) {
    	assert (typeof value == "integer");
    	assert (value <= 255);
    	assert (value >= 0);
    	assert (pin in _pinsPWM);
    	
		_serial.write(OP_ANALOG | MASK_ANALOG_W | _pinsPWM[pin]);
		_serial.flush();
    }
}

impeeduino <- Impeeduino();
impeeduino.pinMode(7, DIGITAL_OUT);

isOn <- false;

function loop() {
	impeeduino.digitalWrite(7, isOn);
	isOn = !isOn;
	imp.wakeup(1, loop);
}
loop();