Button
==============
Button class is a class for using a button connected to an IO pin. Buttons can be configured either active high or active low, with or without a pullup/down and with a callback on press and/or release.

Contributors
============
Brandon Harris

Usage
=====
Example instantiation:

```
//Example Instantiation
b1 <- Button(hardware.pin1, DIGITAL_IN_PULLUP, button.NORMALLY_HIGH,
            function(){server.log("Button 1 Pressed")},
            function(){server.log("Button 1 released")}
            );
```
