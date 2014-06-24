Pulse Sensor
==============
The PulseSensor class allows you to easily work with an [Analog Pulse Sensor](https://www.sparkfun.com/products/11574).

Contributors
============
[CircuitFlower](https://github.com/circuitFlower)
[BeardedInventor](https://github.com/beardedinventor)

Usage
=====
Example instantiation:

```
pulse <- PulseSensor(hardware.pin2, function(state) {
	server.log(state);	// 1 or 0
});
```