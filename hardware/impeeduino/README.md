Impeedunio Programmer
=====================

This firmware will allow you to program the ATmega328 built into the Impduino. 
It parses Intel HEX files delivered via HTTP POST (form) and implements the STK500v1 serial protocol to talk to the connected ATmega328.

You will need to install the "[optiboot](https://code.google.com/p/optiboot/)" bootloader using an ICSP cable. At the time of writing, the latest version was [v5.0a](https://code.google.com/p/optiboot/downloads/detail?name=optiboot-v5.0a.zip).
To do this you will need an ISP or use [another Ardiuno as the ISP](http://arduino.cc/en/Tutorial/ArduinoISP) and the ArduinoISP sketch.

You might need to adjust the signature of the ATmega328P in the avrdude configuration to make avrdude think its an ATmega328P.
/Applications/Arduino.app/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf

    From: signature		= 0x1e 0x95 0x0f;
	To:   signature		= 0x1e 0x95 0x14;

Once the ATMega is programmed you can continue to talk to it over the serial port.

Note, if you are using the [SparkFun Imp Shield](https://www.sparkfun.com/products/11401) then you may need to reverse the 
logic of the RESET pin. Where you see RESET.write(1), change it to RESET.write(0) and vice versa.


Contributors
============

- Aron

Usage
=====

This is not a library class. It represents an entire application for programming the Arduino via an Imp with a HEX file.
You can adapt it to your needs, such as combining the programming functionality with application level communication.

