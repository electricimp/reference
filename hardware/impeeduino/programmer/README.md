# Impeedunio Programmer

This firmware will allow you to program the ATmega328 built into the Impeeduino. 
It parses Intel HEX files delivered via HTTP POST (form) and implements the STK500v1 serial protocol to talk to the connected ATmega328.


## Usage

This is not a library class. It represents an entire application for programming the Arduino via an Imp with a HEX file.
### Hardware Setup
1. Insert an imp001 into the SD card slot on the left side of the board. 
2. Then power the board via either the 7-12V DC jack or the USB connector. The green LED should light up to indicate power is connected. 
3. [Blink up](https://electricimp.com/docs/gettingstarted/blinkup/) the imp001 to your account and assign it to a new model. 
4. Copy the squirrel code in [impeeduino_programmer.agent.nut](./impeeduino_programmer.agent.nut) to the agent section and the code in [impeeduino_programmer.device.nut](./impeeduino_programmer.device.nut) to the device section. 
5. Hit "Build and Run," and verify that the agent and device restart in the log console.
6. Visit the agent URL in a browser and follow the instructions to upload a `.HEX` file generated from the Arduino IDE.

## Burning a Bootloader
The ATmega328 processors built into the Impeeduinos does not come with the bootloader preinstalled. In order to upload code over the serial port, it is necessary to install a compatible bootloader. This is a one-time operation that only has to be performed on new Impeeduino boards.

You will need to install the "[optiboot](https://code.google.com/p/optiboot/)" bootloader using an ICSP cable. At the time of writing, the latest version was [v5.0a](https://code.google.com/p/optiboot/downloads/detail?name=optiboot-v5.0a.zip).
To do this you will need an ISP or use [another Ardiuno as the ISP](http://arduino.cc/en/Tutorial/ArduinoISP) and the ArduinoISP sketch.

You might need to adjust the signature of the ATmega328P in the avrdude configuration to make avrdude think its an ATmega328P. This is on line 8486 on my installation.
/Applications/Arduino.app/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf

    From: signature		= 0x1e 0x95 0x0f;
	To:   signature		= 0x1e 0x95 0x14;

Once the ATMega is programmed you can continue to talk to it over the serial port.

Note, if you are using the [SparkFun Imp Shield](https://www.sparkfun.com/products/11401) then you may need to reverse the 
logic of the RESET pin. Where you see RESET.write(1), change it to RESET.write(0) and vice versa.

## Contributors

- Aron
- Sunny (Update documentation)
