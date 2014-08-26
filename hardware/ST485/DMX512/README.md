Non-Isolated DMX with the [ST485](http://www.st.com/web/en/resource/technical/document/datasheet/CD00002183.pdf)
===================================

Author: [Tom Byrne](https://github.com/tombrew/)

## Hardware Setup
The ST485 requires three pins to use: One non-flow-controlled UART and a GPIO for TX enable. Any imp UART can be used. 

The ST485 is used in the [Kaylee](https://electricimp.com/docs/hardware/resources/reference-designs/kaylee/) reference design.

## DMX512
DMX512 is a communications protocol often used to control performance lighting and automation. This example firmware uses the Kaylee reference design as a DMX512 controller. The software is capable of controlling up to 512 devices, but the DMX512 standard limits the number of connected devices to 32 per bus (though it is not clear if any users actually practice this limit).

This example does not generate a 100% perfectly-compliant DMX512 frame; the DMX512 standard states that the initial break period should be 100µs, with a 12µs mark-after-break, followed by 513 bytes of what is essentially 250kbaud UART with 1 start byte, 2 stop bytes, and no parity byte. 

Because the imp cannot currently generate multiple-byte-period UART breaks, the UART TX pin is reconfigured as a DIGITAL_OUT to send the break. The time required for this operation forces the break to about 430µs. The time required to reconfigure the UART after the break forces the mark-after-break to about 80µs. 

Many DMX512 devices will accept this stretched break and mark-after-break and work without complaint, but some device may not. 
