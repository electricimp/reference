/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* 
 * Tom Buttner
 * tom@electricimp.com
 */

/*
 * Generic Class to send IR Remote Control Codes
 * Useful for:
 * 		- TV Remotes
 *		- Air conditioner / heater units
 * 		- Fans / remote-control light fixtures
 *		- Other things not yet attempted!
 * For more information on Differential Pulse Position Modulation, see
 * http://learn.adafruit.com/ir-sensor
 *
 */
class IR_transmitter {

 	/* The following variables set the timing for the transmitter and can be overridden in the constructor. 
 	 * The timing for the start pulse, marker pulses, and 1/0 time will vary from device to device. */

 	// Times for start pulse (in microseconds)
	START_TIME_HIGH 			= 3300.0;
	START_TIME_LOW				= 1700.0;

	/* Pulses are non-information bearing; the bit is encoded in the break after each pulse.
	 * PULSE_TIME sets the width of the pulse in microseconds. */
	PULSE_TIME 					= 420.0;

	// Time between pulses to mark a "1" (in microseconds)
	TIME_LOW_1					= 1200.0;
	// Time between pulses to mark a "0" (in microseconds)
	TIME_LOW_0					= 420.0;

	// PWM carrier frequency (typically 38 kHz in US, some devices use 56 kHz, especially in EU)
	CARRIER 					= 38000.0;

	// Number of times to repeat a code when sending
	CODE_REPEATS  				= 2;

	// Time to wait (in seconds) between code sends when repeating
	PAUSE_BETWEEN_SENDS 		= 0.05;

	spi = null;
	pwm = null;

	/* 
	 * Instantiate a new IR_transmitter
	 *
	 * Input: 
	 * 		_spi (spi object): SPI bus to use when sending codes
	 * 		_pwm (pin object): PWM-capable pin object
	 *
	 * The objects will be configured when this.send() is called.
	 */
	constructor(_spi, _pwm) {
		this.spi = _spi;
		this.pwm = _pwm;
	}

	/* 
	 * Send an IR Code over the IR LED 
	 * 
	 * Input: 
	 * 		IR Code (string). Each bit is represented by a literal character in the string.
	 *			Example: "111000001110000001000000101111111"
	 * 			Both states are represented by a fixed-width pulse, followed by a low time which varies to 
	 * 			indicate the state. 
	 *
	 * Return:
	 * 		None
	 */
	function send(code) {

		/* Configure the SPI and PWM for each send. 
		 * This ensures that they're not in an unknown state if reconfigured by other code between sends */
		this.pwm.configure(PWM_OUT, 1.0/CARRIER, 0.0);
		local clkrate = 1000.0 * spi.configure(SIMPLEX_TX,117);
		local bytetime = 8 * (1000000.0/clkrate);
		// ensure SPI lines are low
		spi.write("\x00");

		// calculate the number of bytes we need to send each signal
		local start_bytes_high = (START_TIME_HIGH / bytetime).tointeger();
		local start_bytes_low =  (START_TIME_LOW / bytetime).tointeger();
		local pulse_bytes = (PULSE_TIME / bytetime).tointeger();
		local bytes_1 = (TIME_LOW_1 / bytetime).tointeger();
		local bytes_0 = (TIME_LOW_0 / bytetime).tointeger();

		local code_blob = blob(pulse_bytes); // blob will grow as it is written

		// Write the start sequence into the blob
		for (local i = 0; i < start_bytes_high; i++) {
			code_blob.writen(0xFF, 'b');
		}
		for (local i = 0; i < start_bytes_low; i++) {
			code_blob.writen(0x00, 'b');
		}

		// now encode each bit in the code
		foreach (bit in code) {
			// this will be set when we figure out if this bit in the code is high or low
			local low_bytes = 0;
			// first, encode the pulse (same for both states)aa
			for (local j = 0; j < pulse_bytes; j++) {
				code_blob.writen(0xFF,'b');
			}

			// now, figure out if the bit is high or low
			// ascii code for "1" is 49 ("0" is 48)
			if (bit == 49) {
				//server.log("Encoding 1");
				low_bytes = bytes_1;
			} else {
				//server.log("Encoding 0");
				low_bytes = bytes_0;
			}

			// write the correct number of low bytes to the blob, then check the next bit
			for (local k = 0; k < low_bytes; k++) {
				code_blob.writen(0x00,'b');
			}
		}
			
		// the code is now written into the blob. Time to send it. 

		// enable PWM carrier
		pwm.write(0.5);

		// send code as many times as we've specified
		for (local i = 0; i < CODE_REPEATS; i++) {
			spi.write(code_blob);
			// clear the SPI bus
			spi.write("\x00");
			imp.sleep(PAUSE_BETWEEN_SENDS);
		}
		
		// disable pwm carrier
		pwm.write(0.0);
		// clear the SPI lines
		spi.write("\x00");
	}

	/* 
	 * Update the timing parameters of the IR_transmitter.
	 *
	 * This is generally necessary when switching between devices or device manufacturers, 
	 * 	as different implementations use different timing.
	 *
	 * Input: 
	 * 		_start_time_high: (integer) High time of start pulse, in microseconds
	 *		_start_time_low:  (integer) Low time of start pulse, in microseconds
	 * 		_pulse_time: 	  (integer) High time (non-data-bearing) of marker pulses, in microseconds
	 * 		_time_low_1: 	  (integer) Low time after marker pulse to designate a 1, in microseconds
	 * 		_time_low_0: 	  (integer) Low time after marker pulse to designate a 0, in microseconds
	 * 		_carrier: 		  (integer) Carrier frequency for the IR signal, in Hz
	 * 		_code_repeats: 	  (integer) Number of times to repeat a code when sending
	 * 		_pause: 		  (float) 	Time to pause between code sends when repeating (in seconds)
	 *
	 */
	function set_timing(_start_time_high, _start_time_low, _pulse_time, _time_low_1, _time_low_0, 
		_carrier, _code_repeats, _pause) {

	 	START_TIME_HIGH 	= _start_time_high * 1.0;
	  	START_TIME_LOW 		= _start_time_low * 1.0;

	  	PULSE_TIME 			= _pulse_time * 1.0;

	  	TIME_LOW_1 			= _time_low_1 * 1.0;
	  	TIME_LOW_0 			= _time_low_0 * 1.0;

	  	CARRIER 			= _carrier * 1.0;

	  	CODE_REPEATS 		= _code_repeats;
	  	PAUSE_BETWEEN_SENDS = _pause;
	 }
}

/* AGENT CALLBACKS ----------------------------------------------------------*/

agent.on("send_code", function(code) {
	sender.send(code);
	server.log("Code sent.");
});

agent.on("set_timing", function(target) {
	/*
	server.log("Device: got new target device information");
	foreach (key, value in target) {
		server.log(key+" : "+value);
	}
	*/
	sender.set_timing(target.START_TIME_HIGH, target.START_TIME_LOW, target.PULSE_TIME, target.TIME_LOW_1,
		target.TIME_LOW_0, target.CARRIER, 4, target.PAUSE_BETWEEN_SENDS);
	server.log("Device timing set.");
});

/* RUNTIME STARTS HERE ------------------------------------------------------*/

imp.configure("IR Transmitter",[],[]);

// instantiate an IR transmitter
sender <- IR_transmitter(hardware.spi257, hardware.pin1);