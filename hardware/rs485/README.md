RS485 UART Wrapper Class
------------------------
This class is designed to add read/write enable lines to the standard UART object, to allow it to be used with common RS485 ICs easily.

### Usage ###
There are two steps required to use this class: creating the object and configuring UART.
After completing these two steps, the RS485 object can be used like a UART or passed to any class that uses UART -
it will automatically drive the Read Enable/Write Enable pins appropriately when reading and writing.

#### 1. Create an RS485 object ####
##### Parameters #####
\#  | Type | Description
:-: | :----- | :------
1   | uart   | UART pins (unconfigured)
2   | pin    | Read Enable pin (unconfigured, optional)
3   | pin    | Write Enable pin (unconfigured, optional)
4   | const  | Read Enable polarity (optional)
5   | const  | Write Enable polarity (optional)
Polarity can be RS485.ACTIVE_HIGH or RS485.ACTIVE_LOW

```
rs485 <- RS485(hardware.uart12, hardware.pin7, hardware.pin5, RS485.ACTIVE_LOW, RS485.ACTIVE_HIGH);
```

#### 2. Configure the object's internal UART ####
#### Parameters ####
\#  | Type | Description
:-: | :--- | :------
1 | integer  | Baud Rate
2 | integer  | Data bits (7 or 8)
3 | const    | PARITY_NONE / PARITY_EVEN / PARITY_ODD
4 | integer  | Stop bits (1 or 2)
5 | const    | flags (see UART API docs)
6 | function | Callback function
```
rs485.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, myCallback);
```
