// Copyright (c) 2014, 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
// 
// Driver Class for TMP1x2 family of temperature sensors
// See http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf
class TMP1x2 {
	// Register addresses
	static TEMP_REG 		= 0x00;
	static CONF_REG 		= 0x01;
	static T_LOW_REG		= 0x02;
	static T_HIGH_REG		= 0x03;

	// ADC resolution in degrees C
	static DEG_PER_COUNT 	= 0.0625;

	static CONVERSION_POLL_INTERVAL = 0; // breakable tight loop for conversion_done
	static CONVERSION_TIMEOUT = 0.5; // seconds

	// i2c address
	_addr 	= null;
	_i2c	= null;

	_conversion_timeout_timer = null;
	_conversion_poll_timer = null;
	_conversion_ready_cb = null;

	// -------------------------------------------------------------------------
	constructor(i2c, addr = 0x90) {
		_addr	= addr;
		_i2c 	= i2c;
	}

	// -------------------------------------------------------------------------
	function _twosComp(value, mask) {
		value = ~(value & mask) + 1;
		return value & mask;
	}

	// -------------------------------------------------------------------------
	function _getReg(reg) {
		local val = _i2c.read(_addr, format("%c", reg), 2);
		if (val != null) {
			return (val[0] << 8) | (val[1]);
		} else {
			return null;
		}
	}
		
	// -------------------------------------------------------------------------
	function _setReg(reg, val) {
		_i2c.write(_addr, format("%c%c%c", reg, (val & 0xff00) >> 8, val & 0xff));   
	}
		
	// -------------------------------------------------------------------------
	function _setRegBit(reg, bit, state) {
		local val = _getReg(reg);
		if (state == 0) {
			val = val & ~(0x01 << bit);
		} else {
			val = val | (0x01 << bit);
		}
		_setReg(reg, val);
	}

	// -------------------------------------------------------------------------
	function _getRegBit(reg, bit) {
		return (0x0001 << bit) & _getReg(reg);
	}

	// -------------------------------------------------------------------------
	function _tempToRaw(temp) {
		local raw = ((temp * 1.0) / DEG_PER_COUNT).tointeger();
	if (_getExtMode()) {
		if (raw < 0) { _twosComp(raw, 0x1FFF); }
		raw = (raw & 0x1FFF) << 3;
	} else {
		if (raw < 0) { _twosComp(raw, 0x0FFF); }
		raw = (raw & 0x0FFF) << 4;
	}
	return raw;
	}

	// -------------------------------------------------------------------------
	function _rawToTemp(raw) {
		if (_getExtMode()) {
		raw = (raw >> 3) & 0x1FFF;
		if (raw & 0x1000) { raw = -1.0 * _twosComp(raw, 0x1FFF); }
	} else {
		raw = (raw >> 4) & 0x0FFF;
		if (raw & 0x0800) { raw = -1.0 * _twosComp(raw, 0x0FFF); }
	}
	return raw.tofloat() * DEG_PER_COUNT;
	}

	// -------------------------------------------------------------------------
	// Device comes out of reset enabled by default
	function setShutdown(state) {
		_setRegBit(CONF_REG, 8, state);
	}

	// -------------------------------------------------------------------------
	function _getShutdown() {
		return _getRegBit(CONF_REG, 8);
	}
	
	// -------------------------------------------------------------------------
	// Device comes out of reset in comparator mode
	function setModeComparator() {
		_setRegBit(CONF_REG, 9, 0);
	}
	
	// -------------------------------------------------------------------------
	function setModeInterrupt() {
		_setRegBit(CONF_REG, 9, 1);
	}
	
	// -------------------------------------------------------------------------
	function setActiveLow() {
		_setRegBit(CONF_REG, 10, 0);
	}
	
	// -------------------------------------------------------------------------
	function setActiveHigh() {
		_setRegBit(CONF_REG, 10, 1);
	}
	
	// -------------------------------------------------------------------------
	// Enable/Disable 13-bit extended mode
	function setExtMode(state) {
		_setRegBit(CONF_REG, 4, state);
	}

	// -------------------------------------------------------------------------
	function _getExtMode() {
		return _getRegBit(CONF_REG, 4);
	}

	// -------------------------------------------------------------------------
	function _getConvReady() {
		if (_getRegBit(CONF_REG, 0)) return false;
		return true;
	}
	// -------------------------------------------------------------------------
	// Set low threshold for Alert mode in degrees Celsius
	function setLowThreshold(ths) {
		server.log(format("setting low threshold to 0x%04X", _tempToRaw(ths)));
		_setReg(T_LOW_REG, _tempToRaw(ths));
	}

	// -------------------------------------------------------------------------
	function getLowThreshold() {
		return _rawToTemp(_getReg(T_LOW_REG));
	}

	// -------------------------------------------------------------------------
	// Set low threshold for Alert mode in degrees Celsius
	function setHighThreshold(ths) {
		server.log(format("setting high threshold to 0x%04X", _tempToRaw(ths)));
		_setReg(T_HIGH_REG, _tempToRaw(ths));
	}

	// -------------------------------------------------------------------------
	function getHighThreshold() {
		return _rawToTemp(_getReg(T_HIGH_REG));
	}

	// -------------------------------------------------------------------------
	function _startConversion() {
		_setRegBit(CONF_REG, 15, 1);
	}

	// -------------------------------------------------------------------------
	function _pollForConversion(cb = null) {
		if (cb) { _conversion_ready_cb = cb; }
		if (_getConvReady()) {
			// success; cancel the timeout timer
			if (_conversion_timeout_timer) { imp.cancelwakeup(_conversion_timeout_timer); }
			local conversion_ready_cb = _conversion_ready_cb;
			_conversion_ready_cb = null;
			conversion_ready_cb();
		} else {
			// no result; schedule again
			_conversion_poll_timer = imp.wakeup(CONVERSION_POLL_INTERVAL, _pollForConversion);
		}
	}

	// -------------------------------------------------------------------------
	// takes an optional callback which must accept one parameter
	// callback param is a table, contains "temp" key
	// on error, cb param will contain "err" key with error description, as well
	// as "temp" key with null data
	// 
	// executes synchronously if callback is not provided
	function getTemp(cb = null) {
		if (_getShutdown()) {
			_startConversion();
			if (cb) { // asynchronous path
				// set a timeout callback
					_conversion_timeout_timer = imp.wakeup(CONVERSION_TIMEOUT, function() {
						// failure; cancel polling for a result and call the callback with error
						imp.cancelwakeup(_conversion_poll_timer);
						_conversion_ready_cb =  null;
						cb({"err": "TMP1x2 conversion timed out", "temp": null});
					});
				_pollForConversion(function() {
					cb({"temp": _rawToTemp(_getReg(TEMP_REG))});
				});
			} else { // synchronous path
				local start = hardware.millis();
				while (!_getConvReady() && (hardware.millis() - start) < (CONVERSION_TIMEOUT * 1000));
				if ((hardware.millis() - start) >= (CONVERSION_TIMEOUT * 1000)) {
					return {"err": "TMP1x2 conversion timed out", "temp": null}
				} 
				return {"temp": _rawToTemp(_getReg(TEMP_REG))};
			}
		} else {
			local temp = _rawToTemp(_getReg(TEMP_REG));
			if (cb) { cb({"temp": temp}); }
			else { return {"temp": temp}; }
		}
	}
}