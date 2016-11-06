# Impeeduino 0.0.?

This Impeeduino is a mashup of an imp001 and an Arduino. This library provides a simple way to instruct the Arduino side of the Impeeduino to perform basic tasks over UART. 

<!--
**To add this library to your project, add** `#require "Utilities.nut:1.0.0"` **to the top of your agent or device code.**
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

Resets the ATMega processor.

```squirrel
impeeduino.reset();
```

### pinMode(*pin, mode*)

Configures the specified GPIO pin to behave either as an input or an output.

```squirrel
// Example here
```

### digitalWrite(*pin, value*)

Writes a value to a digital pin

```squirrel
// Example here
```

### analogWrite(*pin, value*)

Writes an analog value (PWM wave) to a pin. value represents the duty cycle and ranges between 0 (off) and 255 (always on).

```squirrel
// Example here
```

### digitalRead(*pin[, callback]*)

Reads the value from a specified digital pin

#### Asynchronous Example

```squirrel
// Code here
```

#### Synchronous Example

```squirrel
// Code here
```

### analogRead(*pin[, callback]*)

Reads the value from a specified analog pin

#### Asynchronous Example

```squirrel
// Code here
```

#### Synchronous Example

```squirrel
// Code here
```
### functionCall(*id[, argument, callback]*)

Performs a function call on the Arduino.

```squirrel
// Example here
```

## Licence

<!--
Impeeduino.class.nut is provided under the [license](./LICENSE).
-->