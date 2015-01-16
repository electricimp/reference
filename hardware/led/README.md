LED
====

Blink an LED in a non-blocking way

Contributors
============

- Brandon

Example Code
============

Example Instantiation

```
red <- LED(hardware.pin2);

// 3 fast blinks followed by 3 slow blinks
red.blink(3, 0.2, 0.4, 
	function() { 
		red.blink(3, 0.6, 1.2, function() {
			server.log("Done blinking");
		})
	});
```