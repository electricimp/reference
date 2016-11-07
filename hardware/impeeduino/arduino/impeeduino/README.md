Instruction format: 1[op (3b)][addr (4b)]
	Any byte received that does not have MSB set to 1 is interpreted as ASCII data,
	should be added to function call buffer.

000 (0x80) Configure Pin
	Must be followed by arb data with config type
	1111[configtype (4b)]
	0000 Input
	0001 Input PULLUP
	0010 Output

001 (0x90) Digital Read
	Arduino responds with digital write op corresponding to read value
	
010 (0xA0) Digital Write 0
011 (0xB0) Digital Write 1



100 (0xC0) Analog Op + W/~R + addr (3b)
	pin 3 : 0
	pin 5 : 1
	pin 6 : 2
	pin 9 : 3
	pin 10: 4
	pin 11: 5
	
	(0xC8 | addr) Analog Write: Must pass 1 byte argument 0-255 for PWM duty cycle
		- Full instruction is 1100 1[addr (3b)], 1101[LSB (4b)], 1101[MSB (4b)]
	
	(0xC0 | addr) Analog Read: Arduino responds w/ copy of op and 10-bit ADC value split into 3 bytes.
		- 1100 0[addr (3b)],  1101 [ADC(3:0)], 1101 [ADC(7:4)], 1101 00[ADC(9:8)]
		
	Note imp is little-endian.
	
101 (0xD0) Arb data/Reserved
	
110 (0xE0) Call/Return
	call 0 (11000000) reserved for "clear buffer"
111 (0xF0) Call/Return
	11111111 (0xFF) May not be used to avoid confusion
	
==========
Function call process

Valid functions are 1-30 (0x01 to 0x1E)
function 0  (0x00) is reserved as "clear buffer"
function 32 (0xFF) is not allowed to avoid 0xFF confusion with -1

1. Imp sends "call 0x00" to clear Arduino function buffer
2. Imp sends function argument as ASCII characters (0-127)
3. Arduino places received characters into buffer
4. Imp sends "call 0xXX" to initiate call of function #XX
5. Arduino calls functionXX() with the function buffer's contents as the argument
6. functionXX returns, optionally with a character array return value
7. Arduino sends "call 0x00" to clear Imp's return value buffer
8. Arduino sends return value as ASCII characters
9. Imp places received characters into buffer
10. Arduino sends "call 0xXX" to indicate function return
11. If a callback has been set, Imp calls it with the returned value as an argument.