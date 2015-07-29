class NECreceiver {
    
    static START_TIME_HIGH_US 	= 4500.0;
	static START_TIME_LOW_US	= 4500.0;
	static PULSE_TIME_US		= 600.0;
	static LOW_TIME_US_1		= 1800.0;
	static LOW_TIME_US_0	    = 600.0;
	static RX_TIMEOUT_US        = 5000.0;
	
	_rxPin = null;
	_rxCallback = null;
	_idle_state = null;
	
	_rd = null;
	_us = null;
	
	constructor(rxPin, rxCb, idle_state = 1) {
	    _idle_state = idle_state;
	    _rxPin = rxPin;
	    _rxCallback = rxCb;
	    
	    _rd = _rxPin.read.bindenv(_rxPin);
	    _us = hardware.micros.bindenv(hardware);
	    
	    enable();
	}
	
	function receive() {
	    local bit_idx = 0;
	    local byte = 0;
	    local packet = blob(64);
	    local state = 0;
	    local last_state = _rd();
	    local duration = 0;
	    
	    local start = _us();
	    local last_change_time = start;
	    local now = start;
	    
	    while (1) {
	        // watch for pin state changes
	        state = _rd();
	        now = _us();
	        
	        // end receive loop if it's been more than the max packet time
	        if (state == last_state) {
	            if ((now - last_change_time) > RX_TIMEOUT_US) {
	                break;
	            } else {
	                continue;
	            }
	        }
	        
	        // state change detected
	        if (state != _idle_state) {
	            // rising edge; measure length of low time to determine symbol
	            duration = now - last_change_time;
	            if (duration < LOW_TIME_US_0) {
	                byte = byte & ~(0x80 >> bit_idx++);
	            } else if (duration < LOW_TIME_US_1) {
	                byte = byte + (0x80 >> bit_idx++);
	            } else {
	                // too long to be a "0" or "1"; this is the start symbol, ignore
	            }
	            if (bit_idx == 8) {
	                packet.writen(byte, 'b');
	                byte = 0;
	                bit_idx = 0;
	            }
	        }
	        
	        // finished dealing with state change, reset
	        last_state = state;
			last_change_time = now;
	    }
	    
	    packet.seek(0);
	    _rxCallback(packet);
	}
	
	function decode(packet) {
	    local raw = packet.readn('i');
	    local decoded = {};
	    decoded.vendorId    <- ((raw & 0xFFE00000) >> 21) & 0x7FF;
	    decoded.cmdPg       <- ((raw & 0x001F0000) >> 16) & 0x1F;
	    decoded.deviceId    <- ((raw & 0x0000FF00) >> 8) & 0xFF;
	    decoded.cmd         <- ((raw & 0x000000FE) >> 1) & 0x7F;
	    decoded.parity      <- (raw & 0x00000001);
	    
	    return decoded;
	}
	
	function enable() {
	    _rxPin.configure(DIGITAL_IN, receive.bindenv(this));
	}
	
	function disable() {
	    _rxPin.configure(DIGITAL_IN);
	}
}