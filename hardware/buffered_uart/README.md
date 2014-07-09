BufferedUART
============
The BufferedUART class wraps all the functionality of hardware.uart but buffers the input so you don't have to repeatedly call uart.read().

Contributors
============

- Aron

Usage
=====
The class behaves very much like a normal hardware.uart object except that the callback function (or alternatively the ```read``` function) provide the resulting buffer in the form of a blob.

Callback mode:

```
uart <- BufferedUART(hardware.uart57);
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, function(buf) {
    server.log(format("UART: [%s]", buf.tostring()))
})
.setbuffersize(80)  // Fire an event every time there are eighty bytes in the buffer
.seteol("\r\n");    // or when a carriage return or newline are received.

```

Blocking read mode:

```
uart <- BufferedUART(hardware.uart57);
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS)
.setbuffersize(8)   // Return every time there are eight bytes in the buffer
.seteol("\r\n");    // or when a carriage return or newline are received.

local buf = uart.read(5); // or after a 5 seconds timeout.
if (buf.len() > 0) server.log(format("UART: [%s]", buf.tostring()))

```
