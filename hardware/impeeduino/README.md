

This firmware will allow you to program the ATmega328 built into the Impduino. 
It parses Intel HEX files delivered via HTTP POST (form) and implements the STK500v1 serial protocol to talk to the connected ATmega328.

You will need to install the default "opticode" bootloader using an ICSP cable.
To do this you will need an ISP or use another Ardiuno and the ArduinoISP sketch.

You might need to adjust the signature of the ATmega328P in the avrdude configuration to make avrdude think its an ATmega328P.
/Applications/Arduino.app/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf

    From: signature		= 0x1e 0x95 0x0f;
	To:   signature		= 0x1e 0x95 0x14;

Once the ATMega is programmed you can continue to talk to it over the serial port.
