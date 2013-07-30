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
 * Generic Class to learn IR Remote Control Codes 
 * Useful for:
 * 		- TV Remotes
 *		- Air conditioner / heater units
 * 		- Fans / remote-control light fixtures
 *		- Other things not yet attempted!
 *
 * For more information on Differential Pulse Position Modulation, see
 * http://learn.adafruit.com/ir-sensor
 *
 * Input: 
 *
 */
class IR_receiver {

	/* Receiver Thresholds in us. Inter-pulse times < THRESH_0 are zeros, 
	 * while times > THRESH_0 but < THRESH_1 are ones, and times > THRESH_1 
	 * are either the end of a pulse train or the start pulse at the beginning of a code */
	THRESH_0					= 600;
	THRESH_1					= 1500;

	/* IR Receive Timeouts
	 * IR_RX_DONE is the max time to wait after a pulse before determining that the 
	 * pulse train is complete and stopping the reciever. */
	IR_RX_DONE					= 4000; // us

	/* IR_RX_TIMEOUT is an overall timeout for the receive loop. Prevents the device from
	 * locking up if the IR signal continues to oscillate for an unreasonable amount of time */
	IR_RX_TIMEOUT 				= 1500; // ms

	/* The receiver is disabled between codes to prevent firing the callback multiple times (as 
	 * most remotes send the code multiple times per button press). IR_RX_DISABLE determines how
	 * long the receiver is disabled after successfully receiving a code. */
	IR_RX_DISABLE				= 0.2500; // seconds

	/* The Vishay TSOP6238TT IR Receiver IC is active-low, while a simple IR detector circuit with a
	 * IR Phototransistor and resistor will be active-high. */
	IR_IDLE_STATE				= 1;

	rx_pin = null;

	/* Name of the callback to send to the agent when a new code is recieved. 
	 * This is done instead of just returning the code because this class is called as a state-change callback; 
	 * The main loop will not have directly called receive() and thus will not be prepared to receive the code. */
	agent_callback = null;

	/* 
	 * Receive a new IR Code on the input pin. 
	 * 
	 * This function is configured as a state-change callback on the receive pin in the constructor,
	 * so it must be defined before the constructor.
	 */
	function receive() {

		// Code is stored as a string of 1's and 0's as the pulses are measured.
		local newcode = array(256);
		local index = 0;

		local last_state = rx_pin.read();
		local duration = 0;

		local start = hardware.millis();
		local last_change_time = hardware.micros();

		local state = 0;
		local now = start;

		/* 
		 * This loop runs much faster with while(1) than with a timeout check in the while condition
		 */
		while (1) {

			/* determine if pin has changed state since last read
			 * get a timestamp in case it has; we don't want to wait for code to execute before getting the
			 * timestamp, as this will make the reading less accurate. */
			state = rx_pin.read();
			now = hardware.micros();

			if (state == last_state) {
				// last state change was over IR_RX_DONE ago; we're done with code; quit.
				if ((now - last_change_time) > IR_RX_DONE) {
					break;
				} else {
					// no state change; go back to the top of the while loop and check again
					continue;
				}
			}

			// check and see if the variable (low) portion of the pulse has just ended
			if (state != IR_IDLE_STATE) {
				// the low time just ended. Measure it and add to the code string
				duration = now - last_change_time;
				
				if (duration < THRESH_0) {
					newcode[index++] = 0;
				} else if (duration < THRESH_1) {
					newcode[index++] = 1;
				} 
			}

			last_state = state;
			last_change_time = now;

			// if we're here, we're currently measuring the low time of a pulse
			// just wait for the next state change and we'll tally it up
		}

		// codes have to end with a 1, effectively, because of how they're sent
		newcode[index++] = 1;

		// codes are sent multiple times, so disable the receiver briefly before re-enabling
		disable();
		imp.wakeup(IR_RX_DISABLE, enable.bindenv(this));

		local result = stringify(newcode, index);
		agent.send(agent_callback, result);
	}

	/* 
	 * Instantiate a new IR Code Reciever
	 * 
	 * Input: 
	 * 		_rx_pin: (pin object) pin to listen to for codes. 
	 *			Requires a pin that supports state-change callbacks.
	 * 		_rx_idle_state: (integer) 1 or 0. State of the RX Pin when idle (no code being transmitted).
	 * 		_agent_callback: (string) string to send to the agent to indicate the agent callback for a new code.
	 * 		
	 * 		OPTIONAL:
	 * 
	 * 		_thresh_0: (integer) threshold in microseconds for a "0". Inter-pulse gaps shorter than this will 
	 * 			result in a zero being received.
	 *		_thresh_1: (integer) threshold in microseconds for a "1". Inter-pulse gaps longer than THRESH_0 but
	 * 			shorter than THRESH_1 will result in a 1 being received. Gaps longer than THRESH_1 are ignored.
	 *		_ir_rx_done: (integer) time in microseconds to wait for the next pulse before determining that the end
	 * 			of a pulse train has been reached. 
	 *		_ir_rx_timeout: (integer) max time in milliseconds to listen to a new code. Prevents lock-up if the 
	 *			IR signal oscillates for an unreasonable amount of time.
	 * 		_ir_rx_disable: (integer) time in seconds to disable the receiver after successfully receiving a code.
	 */
	constructor(_rx_pin, _rx_idle_state, _agent_callback, _thresh_0 = null, _thresh_1 = null,
		_ir_rx_done = null, _ir_rx_timeout = null, _ir_rx_disable = null) {
		this.rx_pin = _rx_pin;
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));

		IR_IDLE_STATE = _rx_idle_state;

		agent_callback = _agent_callback;

		/* If any of the timeouts were passed in as arguments, override the default value for that
		 * timeout here. */
		if (_thresh_0) {
			THRESH_0 = _thresh_0;
		}

		if (_thresh_1) {
			THRESH_1 = _thresh_1;
		}

		if (_ir_rx_done) {
			IR_RX_DONE = _ir_rx_done;
		}

		if (_ir_rx_timeout) {
			IR_RX_TIMEOUT = _ir_rx_timeout;
		}

		if (_ir_rx_disable) {
			IR_RX_DISABLE = _ir_rx_disable;
		}
	}

	function enable() {
		rx_pin.configure(DIGITAL_IN, receive.bindenv(this));
	}

	function disable() {
		rx_pin.configure(DIGITAL_IN);
	}

	function stringify(data, len) {
		local result = "";
		for (local i = 0; i < len; i++) {
			result += format("%d",data[i]);
		}
		return result;
	}
}

/* RUNTIME STARTS HERE ------------------------------------------------------*/
imp.configure("IR Receiver",[],[]);

// instatiate an IR receiver and supply it with the name of the agent callback to call on a new code
learn <- IR_receiver(hardware.pin2, 1, "newcode");