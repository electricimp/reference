LineUART
============
The LineUART class wraps all the functionality of hardware.uart but buffers the input until there is a complete line so you don't have to repeatedly call uart.read().

Contributors
============

- Aron

Usage
=====
The class behaves very much like a normal hardware.uart object except that the callback function provides the resulting buffer in the form of a blob. There is also an asynchronous send-and-wait-for-reply mode.

Callback mode:

```
uart <- LineUART(hardware.uart57);
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, function(buf) {
    server.log(format("UART: [%s]", buf.tostring()))
})
.setbuffersize(80)  // Fire an event every time there are eighty bytes in the buffer
.seteol("\r\n");    // or when a carriage return or newline is received.
```

Send and wait mode:

```
uart <- LineUART(hardware.uart57);
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS)
.setbuffersize(80)  // Fire an event when there are eighty bytes in the buffer
.seteol("\r\n");    // or when a carriage return or newline is received.

imp.wakeup(5, function() {
    uart.write("Send something", function(buf) {
        server.log(format("REPLY: [%s]", buf.tostring()))
    })
})
```
