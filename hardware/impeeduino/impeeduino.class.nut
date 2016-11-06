class Impeeduino {
	
	static version = [0, 0, 2]
	
	static BAUD_RATE = 115200;
	
	// PWM enabled pins. -1: No PWM, otherwise 
	static PWM_PINMAP = [-1, -1, -1, 0, -1, 1, 2, -1, -1, 3, 4, 5, -1, -1];
	
	static MASK_OP = 0xF0;
	static OP_CONFIGURE  = 0x80;
	static OP_DIGITAL_READ  = 0x90;
	static OP_DIGITAL_WRITE_0  = 0xA0;
	static OP_DIGITAL_WRITE_1 = 0xB0;
	static OP_ANALOG = 0xC0;        
	static OP_ARB = 0xD0;
	static OP_CALL0 = 0xE0;
	static OP_CALL1 = 0xF0;

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
    
    constructor(serial = hardware.uart57, reset = hardware.pin1) {
    	_serial = serial;
    	_serial.configure(BAUD_RATE, 8, PARITY_NONE, 1, NO_CTSRTS, uartEvent.bindenv(this));
    	
    	_reset = reset;
	    _reset.configure(DIGITAL_OUT);
	    
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
				server.log(format("Opcode: 0x%02X", readByte));
			} else {
				// Save ASCII data to function return buffer
				_funcBuf.seek(0, 'e');
				if (readByte == 0)
				    readByte = ' ';
				_funcBuf.writen(readByte, 'b');
			}
		}
		if (_funcBuf.len() > 0) {
		    server.log(format("%s", _funcBuf.tostring()));
		    //server.log(_funcBuf.tostring());
		    // TESTING ONLY
		    _funcBuf = blob();
		}
	}
	
	function uartEvent() {
	    server.log("Uart event")
		_rxBuf.seek(0, 'e');
		_rxBuf.writeblob(_serial.readblob());
		imp.wakeup(0, parseRXBuffer.bindenv(this));
	}
	
	function reset() {
        server.log("Resetting Duino...")
        _reset.write(1);
        imp.sleep(0.2);
        _reset.write(0);
    }
    
    // Configures the specified GPIO pin to behave either as an input or an output.
    function pinMode(pin, mode) {
        assert (pin != 0 && pin != 1); // Do not reconfigure UART bus pins
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
    		assert (PWM_PINMAP[pin] != -1);
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
    	if (value) {
			_serial.write(OP_DIGITAL_WRITE_1 | pin);
		} else {
			_serial.write(OP_DIGITAL_WRITE_0 | pin);
		}
		_serial.flush();
    }
    
    // Writes an analog value (PWM wave) to a pin. value represents the duty cycle and ranges between 0 (off) and 255 (always on).
    function analogWrite(pin, value) {
    	assert (typeof value == "integer");
    	assert (value <= 255);
    	assert (value >= 0);
    	assert (PWM_PINMAP[pin] != -1);
    	
		_serial.write(OP_ANALOG | MASK_ANALOG_W | PWM_PINMAP[pin]);
		// Lowest order bits (3-0)
		_serial.write(OP_ARB | (value & 0x0000000F));
		// Higest order bits (7-4)
		_serial.write(OP_ARB | ((value & 0x000000F0) >> 4));
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
			local target_low  = OP_DIGITAL_WRITE_0 | pin; // Search for ops with a digital write pattern and addr = pin
			local target_high = OP_DIGITAL_WRITE_1 | pin;
			local readByte = _serial.read();
			local timeout_count = 0;
			while (readByte != target_low && readByte != target_high) {
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			    timeout_count++;
			    if (timeout_count > 100) {
			        //server.log("Read Timeout, retrying")
			        timeout_count = 0;
			        _serial.write(OP_DIGITAL_READ | pin);
    	            _serial.flush();
			    }
				readByte = _serial.read();
			}
			server.log(format("0x%02X", readByte));
			imp.wakeup(0, parseRXBuffer.bindenv(this));
			
			return readByte & MASK_DIGITAL_WRITE ? 1 : 0;
		}
    }
    
    // Reads the value from the specified analog pin. The Arduino board contains a 6 channel , 10-bit analog to digital converter.
    function analogRead(pin) {
    	_serial.write(OP_ANALOG | _pinsPWM[pin]);
    	_serial.flush();
    	if (cb) {
			imp.wakeup(DIGITAL_READ_TIME, function() {
				cb({ "value": _pinState[pin]});
			}.bindenv(this));
		} else {
			local target_low  = OP_DIGITAL_WRITE_0 | pin; // Search for ops with a digital write pattern and addr = pin
			local target_high = OP_DIGITAL_WRITE_1 | pin;
			local readByte = _serial.read();
			local timeout_count = 0;
			while (readByte != target_low && readByte != target_high) {
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			    timeout_count++;
			    if (timeout_count > 100) {
			        //server.log("Read Timeout, retrying")
			        timeout_count = 0;
			        _serial.write(OP_DIGITAL_READ | pin);
    	            _serial.flush();
			    }
				readByte = _serial.read();
			}
			server.log(format("0x%02X", readByte));
			imp.wakeup(0, parseRXBuffer.bindenv(this));
			
			return readByte & MASK_DIGITAL_WRITE ? 1 : 0;
		}
    }
}

activityLED <- hardware.pin2;
linkLED <- hardware.pin8;

server.log("Starting... ");
impeeduino <- Impeeduino();

agent.on("config", function(data) {
    activityLED.write(1);
    server.log("Configuring pin " + data.pin);
    impeeduino.pinMode(data.pin, data.val);
    activityLED.write(0);
});
agent.on("digitalWrite", function(data) {
    activityLED.write(1);
    server.log("Writing " + data.val + " to pin " + data.pin);
    impeeduino.digitalWrite(data.pin, data.val);
    activityLED.write(0);
});
agent.on("analogWrite", function(data) {
    activityLED.write(1);
    server.log("PWM " + data.val + " to pin " + data.pin);
    impeeduino.analogWrite(data.pin, data.val);
    activityLED.write(0);
});
agent.on("digitalRead", function(data) {
    activityLED.write(1);
    server.log("Pin " + data.pin + " = " + impeeduino.digitalRead(data.pin));
    activityLED.write(0);
});
agent.on("analogRead", function(data) {
    activityLED.write(1);
    server.log("Pin A" + data.pin + " = " + impeeduino.analogRead(data.pin));
    activityLED.write(0);
});