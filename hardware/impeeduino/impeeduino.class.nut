class Impeeduino {
	
	static version = [1, 0, 0]
	
	static BAUD_RATE = 115200;
	
	// PWM enabled pins. -1: No PWM, otherwise gives address mapping
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
	    //_functioncb[0] <- _versionCheck;
	    _digitalReadcb = {};
	    _analogReadcb = {};
	    
	    this.reset();
	}
	
	// -------------------- PUBLIC METHODS -------------------- //
	/* 
	 * Resets the ATMega processor by bouncing the reset pin. Note that reseting
	 * will block the imp for about 0.2 seconds.  
	 */
	function reset() {
        server.log("Resetting Duino...")
        _reset.write(1);
        imp.sleep(0.2);
        _reset.write(0);
    }
    
    /* 
     * Configures the specified GPIO pin to the specified mode. Possible 
     * configurations are DIGITAL_IN, DIGITAL_IN_PULLUP, DIGITAL_OUT, and PWM_OUT
     */
    function pinMode(pin, mode) {
    	assert (typeof pin == "integer");
        assert (pin != 0 && pin != 1); // Do not reconfigure UART bus pins
    	_serial.write(OP_CONFIGURE | pin);
    	switch (mode) {
    	case DIGITAL_IN:
    		_serial.write(OP_ARB | CONFIG_INPUT);
    		break;
    	case DIGITAL_IN_PULLUP:
    		_serial.write(OP_ARB | CONFIG_INPUT_PULLUP);
    		break;
    	case DIGITAL_OUT:
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
    
    /*
     * Writes a value to the specified digital pin. Value can be either a 
     * boolean or an integer value. For boolean values, true corresponding to 
     * high and false to low. For integers, non-zero values correspond to high 
     * and zero corresponds to false.
     */
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
    
    /*
     * Writes an analog value (PWM wave) to a pin. *value* is an integer value 
     * representing the duty cycle and ranges between 0 (off) and 255 
     * (always on). For compatibility with imp code, value may also be a 
     * floating point duty ratio from 0.0 to 1.0. This is then rounded to the 
     * nearest available value.
     */
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
    
    /* 
     * Reads the logical value of the specified digital pin and returns it as 
     * an integer. A value of 0 corresponds to digital low, a value of 1 
     * corresponds to digital high.
     */
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
			//server.log(format("0x%02X", readByte));
			imp.wakeup(0, _parseRXBuffer.bindenv(this));
			
			return readByte & MASK_DIGITAL_WRITE ? 1 : 0;
		}
    }
    
    /*
     * Reads the value of the specified analog pin and returns it as an integer.
     * The Arduino has a 10-bit ADC, so returned values will range from 0 to 1023.
     */
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
    /* 
     * Performs a function call on the Arduino. This is intended as a way to 
     * trigger additional functionality on the Arduino. There are 30 
     * user-modifiable custom functions available in the Arduino code, with id 
     * numbers 1-30. 
     */
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
    /*
     * Processes the buffer of pending received data. ASCII data is transcribed
     * to the function return value buffer, while opcodes are executed.
     */
    function _parseRXBuffer() {
		local buf = _rxBuf;
		_rxBuf = blob();
		buf.seek(0, 'b');
		local readByte = 0;
		
		while (!buf.eos()) {
			readByte = buf.readn('b');
			if (readByte & 0x80) {
				// Interpret as Opcode
				//server.log(format("Opcode: 0x%02X", readByte));
				switch (readByte & MASK_OP) {
				case OP_DIGITAL_WRITE_0:
					local addr = readByte & MASK_DIGITAL_ADDR;
					// Call callback if one has been assigned
					if (addr in _digitalReadcb) {
						imp.wakeup(0, function() {
							(delete _digitalReadcb[addr])(0);
						}.bindenv(this));
					}
					break;
				case OP_DIGITAL_WRITE_1:
					local addr = readByte & MASK_DIGITAL_ADDR;
					// Call callback if one has been assigned
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
					// Call callback if one has been assigned
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
					// Call callback if one has been assigned
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
	}
	/*
	 * UART data available event handler. Copies any available data to rxBuf,
	 * then calls _parseRXBuffer to interpret it.
	 */
	function _uartEvent() {
		_rxBuf.seek(0, 'e');
		_rxBuf.writeblob(_serial.readblob());
		imp.wakeup(0, _parseRXBuffer.bindenv(this));
	}
	
	/*
	 * Compares the version string sent from the Arduino to a target version.
	 * By default, the Arduino sketch transmits its version on startup and then
	 * calls function 0 (0xE0). Assigning _versionCheck as the callback for
	 * functioncb[0] will perform a check on that version string.
	 */
	function _versionCheck(data) {
		local versionString = format("%s", data.tostring());
		server.log(versionString);
		if (!versionString.find(version[0] + "." + version[1] + "." + version[2])) {
		    server.log("Library version " + version[0] + "." + version[1] + "." + version[2])
			server.error("Impeeduino version mismatch!");
		}
	}
}