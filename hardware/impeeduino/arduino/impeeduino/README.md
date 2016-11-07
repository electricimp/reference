# Impeeduino Communication Scheme
This document provides documentation for the communication scheme between the imp001 and the ATMega. Incoming serial data is interpreted byte by byte, with commands differentiated from regular ASCII data by checking the most significant bit of each byte. This allows us to take advantage of regular strings sent via Serial.print() on the Arduino as a simple way to pass data while still leaving sufficient address space to assign most common functions to concise commands. 

## Instruction Format
Instruction format: `1[op (3b)][addr (4b)]`

Any byte received that does not have its MSB set to 1 is interpreted as ASCII data and is added to function call buffer. The next 3 bits (bits 6:4) define the opcode, which determines what operation to perform. The last 4 bits (bits 3:0) define an address, usually used to describe a pin number.

### 000 (0x80): Configure Pin
A command to configure a pin must be followed by arbitrary data op specifying the config type. 

Arbitrary data command byte format: `1111[configtype (4b)]`

| Config Type | Decimal | Hex | Binary |
| ----------- | ------- | --- | ------ |
| Input       | 0       | 0x0 | 0000 |
| Input Pullup| 1       | 0x1 | 0001 |
| Output      | 2       | 0x2 | 0010 |
| PWM Output  | 3       | 0x3 | 0011 |

### 001 (0x90): Digital Read
The Arduino responds to a digital read command with digital write command byte corresponding to the read value. For instance, if the Arduino receives `0x96`, instructing a digital read of pin 6, it will respond with `0xA6` (Digital Write 0 on Pin 6) if pin 6 is low or `0xB6` (Digital Write 1 on Pin 6) if pin 6 is high.

### 010 (0xA0): Digital Write 0
Write digital low to the specified pin address.
### 011 (0xB0): Digital Write 1
Write digital high to the specified pin address.

### 100 (0xC0): Analog Op
This opcode represents both analog reads and writes. Since there are only 5 analog inputs and 6 PWM enabled outputs on the Arduino, this first bit of the address field can be used to choose between a analogWrite or analogRead while still being able to address all the applicable pins. In the future it might be worth redesignating one of the function call opcodes in order to address boards with more outputs.

Analog operation format: `1100[W/~R (1b)][addr (3b)]`

For analog writes, the Arduino pin numbers are remapped to the available address space as shown below:

| Arduino Pin Number | Command Address | Example Analog Write |
| -------- | --------- | ----------- |
| 3 | 0 | `0xC8 = 1100 1 000` |
| 5 | 1 | `0xC9 = 1100 1 001` |
| 6 | 2 | `0xCA = 1100 1 010` |
| 9 | 3 | `0xCB = 1100 1 011` |
| 10 | 4 | `0xCC = 1100 1 100` |
| 11 | 5 | `0xCD = 1100 1 101` |

Analog writes must also pass a 1 byte argument for the PWM duty cycle. The two bytes after the intial analogWrite command must be arbitrary data bytes with the least significant word, then most significant word, of the duty cycle. 
Thus a complete analogWrite instruction would be: `1100 1[addr (3b)], 1101[LSB (4b)], 1101[MSB (4b)]`.
	
Analog reads return a 10-bit ADC value. The Arduino responds with a copy of the original analog operation command followed by 3 arbitrary data commands containing the 10-bit ADC value split into 3 words. The words are sent in little-endian order.
A complete analogRead response would be: `1100 0[addr (3b)],  1101 [ADC(3:0)], 1101 [ADC(7:4)], 1101 00[ADC(9:8)]`
	
### 101 (0xD0): Arbitrary Data
This operation is used by other operations to send words of binary data. It is preferable to have an arbitrary data operation in order to avoid issues with interfering with ASCII data being sent as part of a function call or have awkward situations such as long strings of `0xFF` bytes being confused with a -1 read return value.

### 110 (0xE0) and 111 (0xF0): Call/Return
These operations call user-defined functions in the Arduino code. A character array buffer stores incoming ASCII characters received on the UART bus and is passed as the argument to function calls. Between the opcodes `0xE0` and `0xF0`, there are 32 possible functions that may be called. These are referred to with a 5-bit ID, meaning that it may be more accurate to describe the call operation format as: `11[function id (5b)]`

There are two function calls that are reserved for system use.
 - *call 0* (`0xE0` or `11000000`) is used to clear the receive buffers.
 - *call 31* (`0xFF` or `11111111`) may not be used to avoid any confusion with -1, which is commonly used to indicate "no data" by UART read functions.
	
The complete function call process is summarized below:

Valid functions ids are 1-30 (`0x01` to `0x1E`).
function 0  `(0x00)` is reserved as "clear buffer."
function 31 `(0xFF)` is not allowed to avoid confusion with -1.

1. Imp sends *call 0x00* to clear Arduino function buffer
2. Imp sends function argument as ASCII characters (0-127)
3. Arduino places received characters into buffer
4. Imp sends *call 0xXX* to initiate call of the function with id number 0xXX
5. Arduino calls *functionXX()* with the function buffer's contents as the argument
6. *functionXX* returns, optionally with a character array return value
7. Arduino sends *call 0x00* to clear Imp's return value buffer
8. Arduino sends return value as ASCII characters
9. Imp places received characters into buffer
10. Arduino sends *call 0xXX* to indicate function return
11. If a callback has been set, Imp calls it with the returned value as an argument.
