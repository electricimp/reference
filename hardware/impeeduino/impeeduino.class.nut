class Impeeduino {
	
	static version = [0, 0, 3]
	
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
	static OP_CALL = 0xE0;

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
    
	// -------------------- PRIVATE PROPERTIES -------------------- //
	
	_serial  = null; // UART bus to communicate with AVR
    _reset   = null; // AVR reset pin
    
    _rxBuf   = null; // Buffer for incoming data
    _funcBuf = null; // Buffer for function return values
    
    _functioncb = null; // Table of function return callbacks
    _digitalReadcb = null; // Table of digital read return callbacks
    _analogReadcb = null; // Table of analog read return callbacks
    
    // -------------------- CONSTRUCTOR -------------------- //
    /* 
     * The constructor takes two arguments to instantiate the class: a 
     * non-configured UART bus and a GPIO pin connected to the Arduino's reset 
     * line. These default to the configuration used on the Impeeduino rev2, 
     * using `uart57` for serial communications and `pin1` for the reset line.
     */
    constructor(serial = hardware.uart57, reset = hardware.pin1) {
    	_serial = serial;
    	_serial.configure(BAUD_RATE, 8, PARITY_NONE, 1, NO_CTSRTS, _uartEvent.bindenv(this));
    	
    	_reset = reset;
	    _reset.configure(DIGITAL_OUT);
	    
	    _funcBuf = blob();
	    _rxBuf = blob();
	    
	    _functioncb = {};
	    _functioncb[0] <- _versionCheck;
	    _digitalReadcb = {};
	    _analogReadcb = {};
	    
	    this.reset();
	}
	
	// -------------------- PUBLIC METHODS -------------------- //
	/* Resets the ATMega processor. */
	function reset() {
        server.log("Resetting Duino...")
        _reset.write(1);
        imp.sleep(0.2);
        _reset.write(0);
    }
    
    /* Configures the specified GPIO pin to behave either as an input or an output. */
    function pinMode(pin, mode) {
    	assert (typeof pin == "integer");
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
    	assert (typeof pin == "integer");
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
    	assert (typeof pin == "integer");
    	if (PWM_PINMAP[pin] == -1) throw "Pin " + pin + " does not have PWM capability";
    	
    	local writeVal = 0;
    	if (typeof value == "integer") {
			if (value < 0 || value > 255) throw "Integer analogWrite values must be between 0 and 255";
			writeVal = value;
		} else if (typeof value == "float") {
			if (value < 0.0 || value > 1.0) throw "Float analogWrite values must be between 0.0 and 1.0";
			writeVal = (value * 255).tointeger();
		}
    	
		_serial.write(OP_ANALOG | MASK_ANALOG_W | PWM_PINMAP[pin]);
		// Lowest order bits (3-0)
		_serial.write(OP_ARB | (writeVal & 0x0000000F));
		// Higest order bits (7-4)
		_serial.write(OP_ARB | ((writeVal & 0x000000F0) >> 4));
		_serial.flush();
    }
    
    // Reads the value from a specified digital pin
    function digitalRead(pin, cb = null) {
    	assert (typeof pin == "integer");
    	_serial.write(OP_DIGITAL_READ | pin);
    	_serial.flush();
    	
    	if (cb) {
			_digitalReadcb[pin] <- cb;
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
			    if (timeout_count > 200) {
			        //server.log("Read Timeout, retrying")
			        timeout_count = 0;
			        _serial.write(OP_DIGITAL_READ | pin);
    	            _serial.flush();
			    }
				readByte = _serial.read();
			}
			server.log(format("0x%02X", readByte));
			imp.wakeup(0, _parseRXBuffer.bindenv(this));
			
			return readByte & MASK_DIGITAL_WRITE ? 1 : 0;
		}
    }
    
    // Reads the value from the specified analog pin. The Arduino board contains a 6 channel , 10-bit analog to digital converter.
    function analogRead(pin, cb = null) {
    	assert (typeof pin == "integer");
    	if (pin < 0 || pin > 5) throw "Invalid analog input number: " + pin;
    	_serial.write(OP_ANALOG | pin);
    	_serial.flush();
    	imp.sleep(0.000015);
    	if (cb) {
			_analogReadcb[pin] <- cb;
		} else {
			local target  = OP_ANALOG | pin;
			local readByte = 0;
			local timeout_count = 0;
			local value = blob(2);
			// Wait for Arduino to send back result
			do {
				readByte = _serial.read();
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			    timeout_count++;
			    if (timeout_count > 500) {
			        //server.log("Read Timeout, retrying")
			        timeout_count = 0;
			        _serial.write(OP_ANALOG | pin);
    	            _serial.flush();
    	        }
			} while (readByte != target)
			
			// Wait for 1st word (bits 3:0)
			do {
				readByte = _serial.read();
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			} while ((readByte & MASK_OP) != OP_ARB)
			value[0] = readByte & 0x0F;
			
			// Wait for 2nd word (bits 7:4)
			do {
				readByte = _serial.read();
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			} while ((readByte & MASK_OP) != OP_ARB)
			value[0] = value[0] | ((readByte & 0x0F) << 4);
			
			// Wait for 3rd word (bits 9:8)
			do {
				readByte = _serial.read();
			 	 // Save other data to buffer
			    if (readByte != -1) {
    			 	_rxBuf.seek(0, 'e');
    				_rxBuf.writen(readByte, 'b');
			    }
			} while ((readByte & MASK_OP) != OP_ARB)
			value[1] = readByte & 0x0F;
			
			//server.log(format("0x%04X", value.readn('w'))); value.seek(0, 'b');
			imp.wakeup(0, _parseRXBuffer.bindenv(this));
			
			return value.readn('w');
		}
    }
    /* Calls function */
    function functionCall(id, arg = "", cb = null) {
    	assert (typeof id == "integer");
    	if (typeof arg != "string") throw "Function call argument must be type string";
    	if (id < 1 || id > 30) throw "Invalid function id: " + id;
    	
    	// Clear Arduino function buffer
    	_serial.write(OP_CALL);
    	_serial.flush();
    	// Send function argument
    	_serial.write(arg);
    	// Initiate function call
    	_serial.write(OP_CALL | id);
    	// Register callback
    	if (cb != null) {
    		_functioncb[id] <- cb;
    	}
    	_serial.flush();
    }
    
    // -------------------- PRIVATE METHODS -------------------- //
    
    function _parseRXBuffer() {
		local buf = _rxBuf;
		_rxBuf = blob();
		buf.seek(0, 'b');
		local readByte = 0;
		
		while (!buf.eos()) {
			readByte = buf.readn('b');
			if (readByte & 0x80) {
				// Interpret as Opcode
				server.log(format("Opcode: 0x%02X", readByte));
				switch (readByte & MASK_OP) {
				case OP_DIGITAL_WRITE_0:
					local addr = readByte & MASK_DIGITAL_ADDR;
					if (addr in _digitalReadcb) {
						imp.wakeup(0, function() {
							(delete _digitalReadcb[addr])(0);
						}.bindenv(this));
					}
					break;
				case OP_DIGITAL_WRITE_1:
					local addr = readByte & MASK_DIGITAL_ADDR;
					if (addr in _digitalReadcb) {
						imp.wakeup(0, function() {
							(delete _digitalReadcb[addr])(1);
						}.bindenv(this));
					}
					break;
				case OP_ANALOG:
					local addr = readByte & MASK_ANALOG_ADDR;
					local value = blob(2);
					value[0] = (buf.readn('b') & 0x0F) | ((buf.readn('b') & 0x0F) << 4);
					value[1] = buf.readn('b') & 0x0F;
					if (addr in _analogReadcb) {
						imp.wakeup(0, function() {
							(delete _analogReadcb[addr])(value.readn('w'));
						}.bindenv(this));
					}
					break;
				case OP_CALL:
					local addr = readByte & MASK_CALL;
					local buf = _funcBuf;
					_funcBuf = blob();
					buf.seek(0, 'b');
					if (addr in _functioncb) {
						imp.wakeup(0, function() {
							(delete _functioncb[addr])(buf);
						}.bindenv(this));
					}
					break;
				}
				
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
		}
	}
	
	function _uartEvent() {
	    server.log("Uart event")
		_rxBuf.seek(0, 'e');
		_rxBuf.writeblob(_serial.readblob());
		imp.wakeup(0, _parseRXBuffer.bindenv(this));
	}
	
	function _versionCheck(data) {
		local versionString = format("%s", data.tostring());
		server.log(versionString);
		if (!versionString.find(version[0] + "." + version[1] + "." + version[2])) {
		    server.log("Library version " + version[0] + "." + version[1] + "." + version[2])
			server.error("Impeeduino version mismatch!");
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
    if (data.async) {
    	impeeduino.digitalRead(data.pin, function(value) {
			server.log("Async: Pin " + data.pin + " = " + value);
		});
    } else {
    	server.log("Pin " + data.pin + " = " + impeeduino.digitalRead(data.pin));
    }
    activityLED.write(0);
});
agent.on("analogRead", function(data) {
    activityLED.write(1);
    if (data.async) {
		impeeduino.analogRead(data.pin, function(value) {
			server.log("Async: Pin A" + data.pin + " = " + value);
		});
    } else {
    	server.log("Pin A" + data.pin + " = " + impeeduino.analogRead(data.pin));
    }
    activityLED.write(0);
});
agent.on("call", function(data) {
    activityLED.write(1);
    server.log("Calling function " + data.id);
    impeeduino.functionCall(data.id, data.arg, function(value) {
		server.log("Function " + data.id + " returned with value: " + value);
    });
    activityLED.write(0);
});