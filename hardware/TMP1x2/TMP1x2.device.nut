// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class TMP1x2 {
	// Register addresses
	static TEMP_REG 		= 0x00;
	static CONF_REG 		= 0x01;
	static T_LOW_REG		= 0x02;
	static T_HIGH_REG		= 0x03;
	// Send this value on general-call address (0x00) to reset device
	static RESET_VAL 		= 0x06;
	// ADC resolution in degrees C
	static DEG_PER_COUNT 	= 0.0625;

	// i2c address
	_addr 	= null;
	// i2c bus (passed into constructor)
	_i2c	= null;
	// interrupt pin (configurable)
	_intPin = null;
	// configuration register value
	_conf 	= null;

	// Default temp thresholds
	_lowThreshold 	= 75; // Celsius
	_highThreshold 	= 80; 

	// Default mode
	_extendedMode 	= false;
	_shutdown 		= false;

	// conversion ready flag
	_convReady 		= false;

	// interrupt state - some pins require us to poll the interrupt pin
	_lastIntState 		= null;
	_pollInterval 		= null;
	_interruptCallback 	= null;

	// generic temp interrupt
	function _defaultInterrupt(state) {
		server.log("Device: TMP1x2 Interrupt Occurred. State = "+state);
	}

	/*
	 * Class Constructor. Takes 3 to 5 arguments:
	 * 		i2c: 					Pre-configured I2C Bus
	 *		addr:  					I2C Slave Address for device. 8-bit address.
	 * 		intPin: 				Pin to which ALERT line is connected
	 * 		alertPollInterval: 		Interval (in seconds) at which to poll the ALERT pin (optional)
	 *		alertCallback:	 		Callback to call on ALERT pin state changes (optional)
	 */
	constructor(i2c, addr, intPin, alertPollInterval = 1, alertCallback = null) {
		_addr	= addr;
		_i2c 	= i2c;
		_intPin	= intPin;

		/* 
		 * Top-level program should pass in Pre-configured I2C bus.
		 * This is done to allow multiple devices to be constructed on the bus
		 * without reconfiguring the bus with each instantiation and causing conflict.
		 */
		_intPin.configure(DIGITAL_IN);
		_lastIntState = _intPin.read();
		_pollInterval = alertPollInterval;
		if (alertCallback) {
			_interruptCallback = alertCallback;
		} else {
			_interruptCallback = _defaultInterrupt;
		}
		readConf();
	}

	/* 
	 * Check for state changes on the ALERT pin.
	 *
	 * Not all imp pins allow state-change callbacks, so ALERT pin interrupts are implemented with polling
	 *
	 */ 
	function pollInterrupt() {
		imp.wakeup(_pollInterval, pollInterrupt);
		local intState = _intPin.read();
		if (intState != _lastIntState) {
			_lastIntState = intState;
			_interruptCallback(state);
		}
	}

	/* 
	 * Take the 2's complement of a value
	 * 
	 * Required for Temp Registers
	 *
	 * Input:
	 * 		value: number to take the 2's complement of 
	 * 		mask:  mask to select which bits should be complemented
	 *
	 * Return:
	 * 		The 2's complement of the original value masked with the mask
	 */
	function twosComp(value, mask) {
		value = ~(value & mask) + 1;
		return value & mask;
	}

	/* 
	 * General-call Reset.
	 * Note that this may reset other devices on an i2c bus. 
	 *
	 * Logging is included to prevent this from silently affecting other devices
	 */
	function reset() {
		server.log("TMP1x2 Class issuing General-Call Reset on I2C Bus.");
		_i2c.write(0x00,format("%c",RESET_VAL));
		// update the configuration register
		readConf();
		// reset the thresholds
		_lowThreshold = 75;
		_highThreshold = 80;
	}

	/* 
	 * Read the TMP1x2 Configuration Register
	 * This updates several class variables:
	 *  - _extendedMode (determines if the device is in 13-bit extended mode)
	 *  - _shutdown		(determines if the device is in low power shutdown mode / one-shot mode)
	 * 	- _convReady	(determines if the device is done with last conversion, if in one-shot mode)
	 */
	function readConf() {
		_conf = _i2c.read(_addr,format("%c",CONF_REG), 2);
		// Extended Mode
		if (_conf[1] & 0x10) {
			_extendedMode = true;
		} else {
			_extendedMode = false;
		}
		if (_conf[0] & 0x01) {
			_shutdown = true;
		} else {
			_shutdown = false;	
		}
		if (_conf[1] & 0x80) {
			_convReady = true;
		} else {
			_convReady = false;
		}
	}

	/*
	 * Read, parse and log the current state of each field in the configuration register
	 *
	 */
	function printConf() {
		_conf = _i2c.read(_addr,format("%c",CONF_REG), 2);
		server.log(format("TMP1x2 Conf Reg at 0x%02x: %02x%02x",_addr,_conf[0],_conf[1]));
		
		// Extended Mode
		if (_conf[1] & 0x10) {
			server.log("TMP1x2 Extended Mode Enabled.");
		} else {
			server.log("TMP1x2 Extended Mode Disabled.");
		}

		// Shutdown Mode
		if (_conf[0] & 0x01) {
			server.log("TMP1x2 Shutdown Enabled.");
		} 
		else {
			server.log("TMP1x2 Shutdown Disabled.");
		}

		// One-shot Bit (Only care in shutdown mode)
		if (_conf[0] & 0x80) {
			server.log("TMP1x2 One-shot Bit Set.");
		} else {
			server.log("TMP1x2 One-shot Bit Not Set.");
		}

		// Thermostat or Comparator Mode
		if (_conf[0] & 0x02) {
			server.log("TMP1x2 in Interrupt Mode.");
		} else {
			server.log("TMP1x2 in Comparator Mode.");
		}

		// Alert Polarity
		if (_conf[0] & 0x04) {
			server.log("TMP1x2 Alert Pin Polarity Active-High.");
		} else {
			server.log("TMP1x2 Alert Pin Polarity Active-Low.");
		}

		// Alert Pin
		if (_intPin.read()) {
			if (_conf[0] & 0x04) {
				server.log("TMP1x2 Alert Pin Asserted.");
			} else {
				server.log("TMP1x2 Alert Pin Not Asserted.");
			}
		} else {
			if (_conf[0] & 0x04) {
				server.log("TMP1x2 Alert Pin Not Asserted.");
			} else {
				server.log("TMP1x2 Alert Pin Asserted.");
			}
		}

		// Alert Bit
		if (_conf[1] & 0x20) {
			server.log("TMP1x2 Alert Bit  1");
		} else {
			server.log("TMP1x2 Alert Bit: 0");
		}

		// Conversion Rate
		local convRate = (_conf[1] & 0xC0) >> 6;
		switch (convRate) {
			case 0:
				server.log("TMP1x2 Conversion Rate Set to 0.25 Hz.");
				break;
			case 1:
				server.log("TMP1x2 Conversion Rate Set to 1 Hz.");
				break;
			case 2:
				server.log("TMP1x2 Conversion Rate Set to 4 Hz.");
				break;
			case 3:
				server.log("TMP1x2 Conversion Rate Set to 8 Hz.");
				break;
			default:
				server.error("TMP1x2 Conversion Rate Invalid: "+format("0x%02x",convRate));
		}

		// Fault Queue
		local faultQueue = (_conf[0] & 0x18) >> 3;
		server.log(format("TMP1x2 Fault Queue shows %d Consecutive Fault(s).", faultQueue));
	}

	/* 
	 * Enter or exit low-power shutdown mode
	 * In shutdown mode, device does one-shot conversions
	 * 
	 * Device comes up with shutdown disabled by default (in continuous-conversion/thermostat mode)
	 * 
	 * Input: 
	 * 		State (bool): true to enable shutdown/one-shot mode.
	 */
	function shutdown(state) {
		readConf();
		local newConf = 0;
		if (state) {
			newConf = ((_conf[0] | 0x01) << 8) + _conf[1];
		} else {
			newConf = ((_conf[0] & 0xFE) << 8) + _conf[1];
		}
		_i2c.write(_addr, format("%c%c%c",CONF_REG,(newConf & 0xFF00) >> 8,(newConf & 0xFF)));
		// readConf() updates the variables for shutdown and extended modes
		readConf();
	}

	/* 
	 * Enter or exit 13-bit extended mode
	 *
	 * Input:
	 * 		State (bool): true to enable 13-bit extended mode
	 */
	function setExtendedMode(state) {
		readConf();
		local newConf = 0;
		if (state) {
			newConf = ((_conf[0] << 8) + (_conf[1] | 0x10));
		} else {
			newConf = ((_conf[0] << 8) + (_conf[1] & 0xEF));
		}
		_i2c.write(_addr, format("%c%c%c",CONF_REG,(newConf & 0xFF00) >> 8,(newConf & 0xFF)));
		readConf();
	}

	/*
	 * Set the T_low threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input: 
	 * 		newLow: new threshold register value in degrees Celsius
	 *
	 */
	function setLowThreshold(newLow) {
		newLow = (newLow / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (_extendedMode) {
			mask = 0x1FFF;
			if (newLow < 0) {
				twosComp(newLow, mask);
			}
			newLow = (newLow & mask) << 3;
		} else {
			if (newLow < 0) {
				twosComp(newLow, mask);
			}
			newLow = (newLow & mask) << 4;
		}
		server.log(format("setLowThreshold setting register to 0x%04x (%d)",newLow,newLow));
		_i2c.write(_addr, format("%c%c%c",T_LOW_REG,(newLow & 0xFF00) >> 8, (newLow & 0xFF)));
		_lowThreshold = newLow;
	}

	/*
	 * Set the T_high threshold register
	 * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
	 * 
	 * Input:
	 *		newHigh: new threshold register value in degrees Celsius
	 *
	 */
	function setHighThreshold(newHigh) {
		newHigh = (newHigh / DEG_PER_COUNT).tointeger();
		local mask = 0x0FFF;
		if (_extendedMode) {
			mask = 0x1FFF;
			if (newHigh < 0) {
				twosComp(newHigh, mask);
			}
			newHigh = (newHigh & mask) << 3;
		} else {
			if (newHigh < 0) {
				twosComp(newHigh, mask);
			}
			newHigh = (newHigh & mask) << 4;
		}
		server.log(format("setHighThreshold setting register to 0x%04x (%d)",newHigh,newHigh));
		_i2c.write(_addr, format("%c%c%c",T_HIGH_REG,(newHigh & 0xFF00) >> 8, (newHigh & 0xFF)));
		_highThreshold = newHigh;
	}

	/* 
	 * Read the current value of the T_low threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function getLowThreshold() {
		local result = _i2c.read(_addr, format("%c",T_LOW_REG), 2);
		local t_low = (result[0] << 8) + result[1];
		//server.log(format("getLowThreshold got: 0x%04x (%d)",t_low,t_low));
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (_extendedMode) {
			//server.log("getLowThreshold: TMP1x2 in extended mode.")
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		t_low = (t_low >> offset) & mask;
		if (t_low & sign_mask) {
			//server.log("getLowThreshold: Tlow is negative.");
			t_low = -1.0 * (twosComp(t_low,mask));
		}
		//server.log(format("getLowThreshold: raw value is 0x%04x (%d)",t_low,t_low));
		_lowThreshold = (t_low.tofloat() * DEG_PER_COUNT);
		return _lowThreshold;
	}

	/*
	 * Read the current value of the T_high threshold register
	 *
	 * Return: value of register in degrees Celsius
	 */
	function getHighThreshold() {
		local result = _i2c.read(_addr, format("%c",T_HIGH_REG), 2);
		local tHigh = (result[0] << 8) + result[1];
		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (_extendedMode) {
			sign_mask = 0x1000;
			mask = 0x1FFF;
			offset = 3;
		}
		tHigh = (tHigh >> offset) & mask;
		if (tHigh & sign_mask) {
			tHigh = -1.0 * (twosComp(tHigh,mask));
		}
		_highThreshold = (tHigh.tofloat() * DEG_PER_COUNT);
		return _highThreshold;
	}

	/* 
	 * If the TMP1x2 is in shutdown mode, write the one-shot bit in the configuration register
	 * This starts a conversion. 
	 * Conversions are done in 26 ms (typ.)
	 *
	 */
	function startConversion() {
		readConf();
		local newConf = 0;
		newConf = ((_conf[0] | 0x80) << 8) + _conf[1];
		_i2c.write(_addr, format("%c%c%c",CONF_REG,(newConf & 0xFF00) >> 8,(newConf & 0xFF)));
	}

	/*
	 * Read the temperature from the TMP1x2 Sensor
	 * 
	 * Returns: current temperature in degrees Celsius
	 */
	function readTempC() {
		if (_shutdown) {
			startConversion();
			_convReady = false;
			local timeout = 30; // timeout in milliseconds
			local start = hardware.millis();
			while (!_convReady) {
				readConf();
				if ((hardware.millis() - start) > timeout) {
					server.error("Device: TMP1x2 Timed Out waiting for conversion.");
					return -999;
				}
			}
		}
		local result = _i2c.read(_addr, format("%c", TEMP_REG), 2);
		local temp = (result[0] << 8) + result[1];

		local mask = 0x0FFF;
		local sign_mask = 0x0800;
		local offset = 4;
		if (_extendedMode) {
			mask = 0x1FFF;
			sign_mask = 0x1000;
			offset = 3;
		}

		temp = (temp >> offset) & mask;
		if (temp & sign_mask) {
			temp = -1.0 * (twosComp(temp, mask));
		}

		return temp * DEG_PER_COUNT;
	}

	/* 
	 * Read the temperature from the TMP1x2 Sensor and convert
	 * 
	 * Returns: current temperature in degrees Fahrenheit
	 */
	function readTempF() {
		local tempC = readTempC();
		if (tempC == -999) {
			return -999;
		} else {
			return (tempC * 9.0 / 5.0 + 32.0);
		}
	}
}

// 8-bit left-justified I2C address (Just an example.)
const TMP1x2_ADDR = 0x30;

// Alert pin
hardware.pin1.configure(DIGITAL_IN);
// i2c bus
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempsensor = TMP1x2(hardware.i2c89, TMP1x2_ADDR, hardware.pin1);
