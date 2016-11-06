# Impeeduino 0.0.?

The Impeeduino is a combination of an imp001 and an Arduino. This library provides a simple way to instruct the Arduino side of the Impeeduino to perform basic tasks over UART.

The Impeeduino squirrel library contained in `impeeduino.class.nut` pairs with the [impeeduino Arduino project](./arduino/impeeduino). More details on the underlying UART communication scheme and instructions on taking advantage of the user-modifiable function call system can be found in the corresponding [Readme file](./arduino/impeeduino/README.md).

To upload Arduino code onto the Impeeduino's ATmega328, an [Impeeduino Programmer model](./programmer) is provided. This model includes agent and device code for programming the Arduino via an Imp with a HEX file generated from the Arduino IDE.

<!--
**To add this library to your project, add** `#require "Impeeduino.nut:1.0.0"` **to the top of your device code.**
-->

## Class Usage

### Constructor: Impeeduino(*[serial, reset]*)

The constructor takes two arguments to instantiate the class: a non-configured UART bus and a GPIO pin connected to the Arduino's reset line. These default to the configuration used on the Impeeduino rev2, using `uart57` for serial communications and `pin1` for the reset line.

```squirrel
impeeduino <- Impeeduino();

// Equivalent, but more verbose instantiation:
impeeduino <- Impeeduino(hardware.uart57, hardware.pin1);
```

## Class Methods

### reset()

Resets the ATMega processor by bouncing the reset pin. Note that reseting will block the imp for about 0.2 seconds. 

```squirrel
impeeduino.reset();
```

### pinMode(*pin, mode*)

Configures the specified GPIO pin to the specified mode. Possible configurations are input, input with pullup, output, and PWM output. The relevant constants are summarized below. Note that not all ATMega pins are capable of being used for PWM output.

| Mode Constant     | Configuration |
| -------------     | ------------- |
| DIGITAL_IN        | Input (High Impedance) |
| DIGITAL_IN_PULLUP | Input with pullup |
| DIGITAL_OUT       | Digital output |
| PWM_OUT           | PWM output |


```squirrel
// Configure pin 2 as digital input
impeeduino.pinMode(2, DIGITAL_IN);

// Configure pin 3 as digital input with pullup
impeeduino.pinMode(3, DIGITAL_IN_PULLUP);

// Configure pin 4 as digital output
impeeduino.pinMode(4, DIGITAL_OUT);

// Configure pin 5 as PWM output
impeeduino.pinMode(5, PWM_OUT);
```

### digitalWrite(*pin, value*)

Writes a value to the specified digital pin. Value can be either a boolean or an integer value. For boolean values, true corresponding to high and false to low. For integers, non-zero values correspond to high and zero corresponds to false.

```squirrel
// Set pin 4 to HIGH
digitalWrite(4, 1);

// Set pin 4 to LOW
digitalWrite(4, 0);

// Toggle pin 4 every 2 seconds
isOn <- true;

function blink() {
	digitalWrite(4, isOn);
	isOn = !isOn;
	imp.wakeup(2, blink);
}

blink();
```

### analogWrite(*pin, value*)

Writes an analog value (PWM wave) to a pin. *value* is an integer value representing the duty cycle and ranges between 0 (off) and 255 (always on). For compatibility with imp code, value may also be a floating point duty ratio from 0.0 to 1.0. This is then rounded to the nearest available value.

```squirrel
// Configure pin 5 as pwm output
impeeduino.pinMode(5, PWM_OUT);

// Set pin 5 to 50% duty cycle
impeeduino.analogWrite(5, 0.5);

// Set pin 5 to 0% duty cycle (always off)
impeeduino.analogWrite(5, 0);

// Set pin 5 to 100% duty cycle (always on)
impeeduino.analogWrite(5, 255);
```

### digitalRead(*pin[, callback]*)

Reads the logical value of the specified digital pin and returns it as an integer. A value of 0 corresponds to digital low, a value of 1 corresponds to digital high.

If a callback parameter is provided, the reading executes asynchronously and the resulting integer value will be passed to the supplied function as the only parameter. If no callback is provided, the method blocks until the reading has been taken.

#### Asynchronous Example

```squirrel
// Read pin 2 asynchronously and log the returned value
impeeduino.digitalRead(2, function(value) {
	server.log("Async digital read: Pin 2 has value " + value);
});
```

#### Synchronous Example

```squirrel
// Read pin 2 and log the returned value
server.log("Digital read: Pin 2 has value " + impeeduino.digitalRead(2));
```

### analogRead(*pin[, callback]*)

Reads the value of the specified analog pin and returns it as an integer. The Arduino has a 10-bit ADC, so returned values will range from 0 to 1023.

If a callback parameter is provided, the reading executes asynchronously and the resulting integer value will be passed to the supplied function as the only parameter. If no callback is provided, the method blocks until the reading has been taken.

#### Asynchronous Example

```squirrel
// Read analog pin 0 asynchronously and log the returned value
impeeduino.analogRead(0, function(value) {
	server.log("Async analog read: Pin A0 has value " + value);
});
```

#### Synchronous Example

```squirrel
// Read analog pin 0 and log the returned value
server.log("Analog read: Pin A0 has value " + impeeduino.analogRead(0));
```
### functionCall(*id[, argument, callback]*)

Performs a function call on the Arduino. This is intended as a way to trigger additional functionality on the Arduino. There are 30 user-modifiable custom functions available in the Arduino code, with id numbers 1-30. 

Each function may take an ASCII string argument and optionally pass back an ASCII string return value. Because the underlying serial communication scheme uses the most significant bit to indicate commands, only standard ASCII characters (value 0-127) may be sent.

Arduino function calls are asynchronous. The returned string will be passed to as the sole parameter to the optional callback as a binary blob.

```squirrel
server.log("Calling function 1");
impeeduino.functionCall(1, "This is the argument", function(value) {
	server.log("Function 1 returned with value: " + value);
});
```

## Licence

The Impeeduino library is provided under the [MIT License](./LICENSE).