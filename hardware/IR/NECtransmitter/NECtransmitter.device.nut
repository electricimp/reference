class NECtransmitter {
    
	START_TIME_HIGH_US 			= 4500.0;
	START_TIME_LOW_US			= 4500.0;
	PULSE_TIME_US				= 600.0;
	LOW_TIME_US_1				= 1200.0;
	LOW_TIME_US_0	    		= 420.0;

	// PWM carrier frequency (typically 38 kHz in US, some devices use 56 kHz, especially in EU)
	CARRIER_FREQ_HZ				= 38000.0;
	// Carrier Duty Cycle
	CARRIER_DC                  = 0.25;
	// Number of times to repeat a code when sending
	// NEC standard specifies min 2, max 5
	CODE_REPEATS  				= 2;
	// target speed to run the SPI at
	SPI_CLOCKRATE_KHZ           = 117;

	// Time to wait (in seconds) between code sends when repeating
	PAUSE_BETWEEN_SENDS 		= 0.05;

	_spi = null;
	_pwm = null;
	_max_packet_size = null;
	
	// blobs to hold pre-calculated bytestreams for re-used symbols
	START   = blob(2);
	ONE     = blob(2);
	ZERO    = blob(2);

	constructor(spi, pwm) {
		_spi = spi;
		_pwm = pwm
		
        // configure the SPI and figure out our actual clockrate and byte time
		_pwm.configure(PWM_OUT, 1.0/CARRIER_FREQ_HZ, 0.0);
		local clkrate = spi.configure(SIMPLEX_TX, SPI_CLOCKRATE_KHZ);
		local bytetime_us = 8 * (1000000000.0/clkrate);
		
		// calculate the number of bytes we need to send each signal
		local start_bytes_high = (START_TIME_HIGH_US / bytetime_us).tointeger();
		local start_bytes_low =  (START_TIME_LOW_US / bytetime_us).tointeger();
		local pulse_bytes = (PULSE_TIME_US / bytetime_us).tointeger();
		local bytes_1 = (LOW_TIME_US_1 / bytetime_us).tointeger();
		local bytes_0 = (LOW_TIME_US_0 / bytetime_us).tointeger();
		_max_packet_size = start_bytes_high + start_bytes_low + (33 * (pulse_bytes + bytes_0));
		
		// generate the start symbol
		for (local i = 0; i < start_bytes_high; i++) {
			START.writen(0xFF, 'b');
		}
		for (local i = 0; i < start_bytes_low; i++) {
			START.writen(0x00, 'b');
		}
		
		// generate the pulse for the "0" and "1" symbols
		for (local i = 0; i < pulse_bytes; i++) {
		    ONE.writen(0xFF, 'b');
		    ZERO.writen(0xFF, 'b');
		}
		// finish the "0" symbol
		for (local i = 0; i < bytes_0; i++) {
		    ZERO.writen(0x00, 'b');
		}
		// finish the "1" symbol
		for (local i = 0; i < bytes_1; i++) {
		    ONE.writen(0xFF, 'b');
		}
	}

    // Build an NEC Packet 
    // Input:
    //      vendorId: 11-bit ID (Ex: Apple remotes use 0x43F)
    //      cmdPage: 5-bit command page (Ex: Apple remote uses page 0x0E for sendable cmds)
    //      deviceId: 8-bit field, use depends on target device (Ex: Apple remote uses this field when paired)
    //      cmd: 7-bit command
    function buildPacket(vendorId, cmdPage, deviceId, cmd) {
        // mask given values to size
        vendorId = vendorId.tointeger() & 0x07FF;
        cmdPage = cmdPage.tointeger() & 0x1F;
        deviceId = deviceId.tointeger() & 0xFF;
        cmd = cmd.tointeger() & 0x7F;
        
        // pre-allocate a blob larger than we'll need for speed
		local packet = blob(_max_packet_size);
		packet.writeblob(START);
		
		// keep track of our parity
		local paritySum = 0;
		
		for (local i = 11; i > 0; i--) {
		    local bit = vendorId & (0x01 << (i - 1));
		    packet.writeblob(bit ? ONE : ZERO);
		    paritySum += bit;
		}
		for (local i = 5; i > 0; i--) {
		    local bit = cmdPage & (0x01 << (i - 1));
		    packet.writeblob(bit ? ONE : ZERO);
		    paritySum += bit;
		}
		for (local i = 8; i > 0; i--) {
		    local bit = deviceId & (0x01 << (i - 1));
		    packet.writeblob(bit ? ONE : ZERO);
		    paritySum += bit;
		}
		for (local i = 7; i > 0; i--) {
		    local bit = cmd & (0x01 << (i - 1));
		    packet.writeblob(bit ? ONE : ZERO);
		    paritySum += bit;
		}
		packet.writeblob((paritySum & 0x01) ? ZERO : ONE);
		
		return packet;
    }
    
	function sendPacket(pkt) {
		// ensure SPI lines are low
		_spi.write("\x00");
		// enable PWM carrier
		_pwm.write(CARRIER_DC);

		// send code as many times as we've specified
		for (local i = 0; i < CODE_REPEATS; i++) {
			_spi.write(pkt);
			// clear the SPI bus
			_spi.write("\x00");
			imp.sleep(PAUSE_BETWEEN_SENDS);
		}
		
		// set output lines low
		_pwm.write(0.0);
		_spi.write("\x00");
	}
}