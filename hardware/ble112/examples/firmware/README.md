
Firmware
========

This contains the starting point for firmware for the BLE112. The notable points are all in hardware.xml:

- ```<usart channel="1" alternate="1" baud="57600" flow="true" endpoint="api" />``` configures the UART port and speed and enables the BGAPI.
- ```<sleep enable="false" />``` configures the BLE112 to NOT sleep.

