SN54LS164W Shift Register Class
-------------------------------
This class encapsulates the basic function of the SN54LS164W shift register using bit banging. It is simple and generic and can probably be used for many similar chips. 

### Usage ###
Instantiate the class, providing the three key pins (data, clear and clock). These will be configured as required by the class.
Then use read() and write() functions to access their values. Note that read() only takes from the classes memory and doesn't actually read the values from the pins.

```
sr <- SN54LS164W(hardware.pinB, hardware.pinC, hardware.pinD);


// Turns output pin 7 on and off, once a second.
testchl <- 7;
testval <- 0;
function test() {
	    imp.wakeup(1, test);
		server.log("Set to: " + sr.write(testchl, testval).read(testchl));
		testval = 1 - testval;
}
test();

```
