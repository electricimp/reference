// see http://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol
class IRtransmitter {
    
	static NEC_START_TIME_HIGH_US 			= 9000.0;
    static NEC_START_TIME_LOW_US			= 4500.0;
	static NEC_PULSE_TIME_US				= 600.0;
	static NEC_LOW_TIME_US_1				= 1700.0;
	static NEC_LOW_TIME_US_0	    		= 600.0;

	// PWM carrier frequency (typically 38 kHz in US, some devices use 56 kHz, especially in EU)
	static CARRIER_FREQ_HZ				= 38000.0;
	// Carrier Duty Cycle
	static CARRIER_DC                  = 0.25;
	// target speed to run the SPI at
	static SPI_CLOCKRATE_KHZ           = 117;

	// Time to wait (in seconds) between code sends when repeating
	static PAUSE_BETWEEN_SENDS 		= 0.05;

	_spi = null;
	_pwm = null;
	_bytetime_us = null;
	
	_nec_max_packet_size = null;
	
	// blobs to hold pre-calculated bytestreams for re-used symbols
	NEC_START   = blob(2);
	NEC_ONE     = blob(2);
	NEC_ZERO    = blob(2);
	NEC_PULSE   = blob(2);
	NEC_REPEAT  = blob(2);

	constructor(spi, pwm) {
		_spi = spi;
		_pwm = pwm
		
        // configure the SPI and figure out our actual clockrate and byte time
		_pwm.configure(PWM_OUT, 1.0/CARRIER_FREQ_HZ, 0.0);
		local clkrate = _spi.configure(SIMPLEX_TX | NO_SCLK | CLOCK_IDLE_LOW, SPI_CLOCKRATE_KHZ);
		_bytetime_us = 8 * (1000.0/clkrate);
		
        _generateNecSymbols();
	}
	
	function _generateNecSymbols() {
	    // calculate the number of bytes we need to send each signal
		local nec_start_bytes_high = (NEC_START_TIME_HIGH_US / _bytetime_us).tointeger();
		local nec_start_bytes_low =  (NEC_START_TIME_LOW_US / _bytetime_us).tointeger();
		local nec_pulse_bytes = (NEC_PULSE_TIME_US / _bytetime_us).tointeger();
		local nec_bytes_1 = (NEC_LOW_TIME_US_1 / _bytetime_us).tointeger();
		local nec_bytes_0 = (NEC_LOW_TIME_US_0 / _bytetime_us).tointeger();
		_nec_max_packet_size = nec_start_bytes_high + nec_start_bytes_low + (33 * (nec_pulse_bytes + nec_bytes_0));
		
		// generate the start symbol
		for (local i = 0; i < nec_start_bytes_high; i++) {
			NEC_START.writen(0xFF, 'b');
		}
		for (local i = 0; i < nec_start_bytes_low; i++) {
			NEC_START.writen(0x00, 'b');
		}
		
		// generate the pulse for the "0" and "1" symbols
		for (local i = 0; i < nec_pulse_bytes; i++) {
		    NEC_ONE.writen(0xFF, 'b');
		    NEC_ZERO.writen(0xFF, 'b');
		    NEC_PULSE.writen(0xFF, 'b');
		}
		// finish the "0" symbol
		for (local i = 0; i < nec_bytes_0; i++) {
		    NEC_ZERO.writen(0x00, 'b');
		}
		// finish the "1" symbol
		for (local i = 0; i < nec_bytes_1; i++) {
		    NEC_ONE.writen(0x00, 'b');
		}
		
		// NEC "repeat" packet shows key is held
		NEC_REPEAT.writeblob(NEC_START);
		NEC_REPEAT.writeblob(NEC_PULSE);
	}
    // Build an NEC Packet 
    // Input:
    //      targetAddr: 8-bit or 16-bit target address
    //      cmd: 8-bit command
    function buildNecPacket(addr, cmd) {
        local addr_len = 8;
        // mask given values to size
        addr = addr.tointeger() & 0xFFFF;
        cmd = cmd.tointeger() & 0xFF;
        
        // pre-allocate a blob larger than we'll need for speed
		local packet = blob(_nec_max_packet_size);
		packet.writeblob(NEC_START);
		
		// figure out if we're using NEC or extended NEC
		if (addr & 0xFF00) {
		    addr_len = 16;
		}
		
		// write the target address
		for (local i = 0; i < addr_len; i++) {
		    local bit = addr & (0x01 << i);
		    packet.writeblob(bit ? NEC_ONE : NEC_ZERO);
		}
		// write the inverse address, if not using extended NEC
		if (addr_len == 8) {
		    local addr_inv = ~addr & 0xFF;
		    for (local i = 0; i < addr_len; i++) {
    		    local bit = addr_inv & (0x01 << i);
    		    packet.writeblob(bit ? NEC_ONE : NEC_ZERO);
    		}
		}
		// write the command byte
		for (local i = 0; i < 8; i++) {
		    local bit = cmd & (0x01 << i);
		    packet.writeblob(bit ? NEC_ONE : NEC_ZERO);
		}
		// write the inverse of the command byte
		local cmd_inv = ~cmd & 0xFF;
	    for (local i = 0; i < 8; i++) {
		    local bit = cmd_inv & (0x01 << i);
		    packet.writeblob(bit ? NEC_ONE : NEC_ZERO);
		}
	    // write the stop pulse
	    packet.writeblob(NEC_PULSE);
		
		packet.seek(0);
		return packet;
    }
    
	function sendPacket(pkt, num_packets = 1, num_repeats = 0) {
		// ensure SPI lines are low
		_spi.write("\x00");
		// enable PWM carrier
		_pwm.write(CARRIER_DC);

		// send code as many times as we've specified
		for (local i = 0; i < num_packets; i++) {
			_spi.write(pkt);
			// clear the SPI bus
			_spi.write("\x00");
			imp.sleep(PAUSE_BETWEEN_SENDS);
		}
		// send repeat codes as specififed
		for (local i = 0; i < num_repeats; i++) {
		    _spi.write(NEC_REPEAT);
		    _spi.write("\x00");
		    imp.sleep(PAUSE_BETWEEN_SENDS);
		}
		
		// set output lines low
		_pwm.write(0.0);
		_spi.write("\x00");
	}
}