# Modbus RTU Master #

This class implements the Modbus RTU protocol, allowing communication with Modbus devices such as industrial controllers and PLCs.

The following Modbus commands are implemented:

Command  | Description
:------: | :---------
**0x01** | Read Coils
**0x02** | Read Discrete Inputs
**0x03** | Read Holding Registers
**0x04** | Read Input Registers
**0x05** | Write Single Coil
**0x06** | Write Single Registers
**0x0F** | Write Multiple Coils
**0x10** | Write Multiple Registers


## Usage ##

### Constructor ###

```squirrel
modbus <- Modbus(hardware.uart12, 9200, 8, PARITY_NONE, 1, callbackHandler, errorHandler, 1.0);
```

#### Parameters ####
\#  | Type | Description
:-: | :--- | :------
1 | uart     | Unconfigured UART pins
2 | integer  | Baud Rate
3 | integer  | Data bits (7 or 8)
4 | const    | PARITY_NONE / PARITY_EVEN / PARITY_ODD
5 | integer  | Stop bits (1 or 2)
6 | function | Receive callback
7 | function | Error callback
8 | float    | Response timeout in seconds (optional)

### Callbacks ###

```squirrel
function errorHandler(functionCode, exceptionCode) {
    server.error(format("Function: 0x%02X, Exception: 0x%02X", functionCode, exceptionCode));
    // Handle some errors
}

function callbackHandler(data) {
    // Generic handler for callbacks from read functions
    // See function definition for 'data' argument format
}
```

### Read / Write Functions ###

#### 0x01 - readCoils(deviceAddress, startingAddress, quantity, callbackHandler = null)
**Description**: Reads status of 1-2000 contiguous coils in a single device.<br>
**Callback argument**: blob of length (quantity / 8), rounded up, one coil per bit, LSB->MSB (as per Modbus spec)

---
#### 0x02 - readInputs(deviceAddress, startingAddress, quantity, callbackHandler = null)
**Description**: Reads status of 1-2000 contiguous inputs in a single device<br>
**Callback Argument**: blob of length (quantity / 8), rounded up, one input per bit, LSB->MSB (as per Modbus spec)

---
#### 0x03 - readHoldingRegs(deviceAddress, startingAddress, quantity, callbackHandler = null)
**Description**: Read the values of up to 125 contiguous 16-bit holding registers<br>
**Callback Argument**: big-endian blob of length (quantity * 2), beginning with the startingAddress register

---
#### 0x04 - readInputRegs(deviceAddress, startingAddress, quantity, callbackHandler = null)
**Description**: Read the values of up to 125 contiguous 16-bit input registers<br>
**Callback Argument**: big-endian blob of length (quantity * 2), beginning with the startingAddress register

---
#### 0x05 - writeSingleCoil(deviceAddress, coilAddress, coilValue)
**Description**: Writes a single coil<br>
**Arguments**: coilValue argument is 0 (off) or 1 (on)

---
#### 0x06 - writeSingleReg(deviceAddress, regAddress, regValue)
**Description**: Writes a single register<br>
**Argument**: regValue argument is a 16-bit value (anything >16 bits will be truncated to the least sig. 16 bits)

---
#### 0x0F - writeMultipleCoils(deviceAddress, startingAddress, quantity, coilValues)
**Description**: Write up to 1968 coils in a single device<br>
**Argument**: coilValues argument should be a blob, startingAddress coil at LSB of first byte

---
#### 0x10 - writeMultipleRegs(deviceAddress, startingAddress, quantity, regValues)
**Description**: Write up to 123 registers in a single device<br>
**Argument**: regValues argument should be a big-endian blob of length (quantity * 2) and begin with the 16-bit value of startingAddress
