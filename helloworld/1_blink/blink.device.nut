// configure the imp (this is best practice)
imp.configure("hello world", [], []);
// configure pin9 to be an DIGITAL_OUT pin
hardware.pin9.configure(DIGITAL_OUT);

// current state of the LED
ledState <- 0;

function loop() {
	// flip the state
	ledState = 1-ledState;
	// write the new state to the LED
	hardware.pin9.write(ledState);
	
	// wait half a second, then do it again
	imp.wakeup(0.5, loop);
}

// call blink to get the loop started
loop();