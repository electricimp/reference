# IR Transmitter Class

This class allows the imp to encode and send IR packets. Currently the commonly-used [NEC and Extended NEC protocols](http://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol) are used. 

## Example Usage

For an example project that can build, transmit, receive, and decode NEC packets, see the [TV Remote](../examples/) example. This code can toggle the power on a Sanyo television, as well as capturing and decoding any NEC or Extended NEC packet.

## Hardware Setup

This class requires a simple circuit that uses both an imp PWM and an imp SPI MOSI to drive an IR LED. The PWM is used to provide a carrier signal, and the SPI is used to modulate that carrier. Currently, the SPI MOSI line must act as an active-high enable for the IR Transmitter. See the [IR Tail](../examples/ir-tail-sch.pdf) schematic for an example circuit.

## Class Usage

### Constructor: IRTransmitter(*spi*, *pwm*)

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| spi     | [spi](https://electricimp.com/docs/api/hardware/spi/) | N/A | The SPI interface the IR transmitter is connected to. The IR transmitter must be connected to the SPI MOSI pin. The constructor will reconfigure the SPI MOSI pin. Other SPI pins in the SPI interface provided are not used. |
| pwm | [pwm](https://electricimp.com/docs/api/hardware/pwm/) | N/A | The imp PWM pin used to provide the carrier signal. The constructor will reconfigure the PWM pin. |

#### Example

```squirrel
class IRTransmitter {...}

// instantiate an IR transmitter
irTx <- IRtransmitter(hardware.spi257, hardware.pin8);
```

## Class Methods

### buildNecPacket(*addr*, *cmd*)

#### Returns
Blob containing NEC packet waveform. Intended to be passed to IrTransmitter.sendPacket(*packet*)

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| addr     | integer | N/A | The target address to use in the returned NEC packet. Addresses can be 8 or 16 bits. If any of bits [16:8] are set, extended NEC will be used. Bits above 16 will be discarded. |
| cmd | integer | N/A | The command to use in the returned NEC packet. Commands may be 8 bits. Bits above bit 8 will be discarded. |

### sendPacket(*packet*)

#### Returns
None

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| packet  | blob | N/A | A blob containing the waveform to transmit. Packets should be build using the buildNecPacket method. |

## License 
The IR Transmitter class is licensed under the [MIT License](https://github.com/electricimp/TMD2772/blob/master/LICENSE).