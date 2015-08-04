# IR Receiver Class

This class allows the imp to receive and decode IR packets with a simple IR photoresistor circuit or dedicated IC, such as the [Vishay TSOP38338](http://www.vishay.com/docs/81743/tsop381.pdf). Currently the commonly-used [NEC and Extended NEC protocols](http://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol) are supported. 

## Example Usage

For an example project that can build, transmit, receive, and decode NEC packets, see the [TV Remote](../Examples/) example. This code can toggle the power on a Sanyo television, as well as capturing and decoding any NEC or Extended NEC packet.

## Hardware Setup

This class requires a simple circuit that uses both an imp PWM and an imp SPI MOSI to drive an IR LED. The PWM is used to provide a carrier signal, and the SPI is used to modulate that carrier. Currently, the SPI MOSI line must act as an active-high enable for the IR Transmitter. See the [IR Tail](../Examples/ir-tail-sch.pdf) schematic for an example circuit.

## Class Usage

### Constructor: IRreceiver(*rxPin*, *callback*, *[idle_state]*)

#### Parameters

#### Return
None (see callback function)

| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| rxPin   | [DIGITAL_IN](https://electricimp.com/docs/api/hardware/pin/) | N/A | The which the IR reciever's data output is connected to. The class constructor will reconfigure this pin to assign it a callback function. |
| callback | function | N/A | This function will be called when a packet is received. The callback function must take one argument, which will be an array.|
| idle_state | 0 or 1 | 1 | Informs the class whether the line idles high or low when no packet is being received. The IR Receiver part on the IR Tail idles the data line high, while a simple phototransistor receiver will idle low. |

#### Callback Function
When the IR receiver senses a received IR packet, the packet will be recorded and passed to the callback function as an array. Each element in the array is a table containing keys "level" and "duration". This is very useful for printing the packet timing, if the protocol used is not known. 

The received packet can be compressed to a blob and/or decoded using other functions in this class.

#### Example

```squirrel
class IRReceiver {...}

function logRxPacket(packet_table) {
    // Throw away packets too short to be fully formed NEC packets
    if (packet_table.len() < 32) { return; }
    
    // Printing the raw packet timing before attempting to decode can be 
    // very helpful when trying to determine the protocol used
    server.log(format("Printing %d-symbol packet",packet.len()));
    for (local i = 0; i < packet.len(); i++) {
        local event = packet[i];
        server.log(format("%d: %d µs", event.level, event.duration));
    }
}

// instantiate an IR receiver
irRx <- IRreceiver(hardware.pin9, logRxPacket);
```

## Class Methods

### enable()

#### Returns
None

#### Parameters
None

Enables the IR receiver. The callback function configured in the constructor will be called if the IR receiver senses a level transition.

### disable()

#### Returns
None

#### Parameters
None

Disables the IR receiver. The callback function will not be called until the receiver is re-enabled.

### packetTableToBlob(*packet_array*)

#### Returns
Blob containing the binary NEC or Extended NEC packet. Edge transition times are compared to NEC timing constants to decode the packet. Results may vary if used on a non-NEC packet.

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| packet_array | array of tables | N/A | An array of tables, each with the keys "level" and "duration", as passed to the receiver callback function |

### decodeNec(*packet_blob*)

#### Returns
Table
| key | type | Description |
| targetAddr | integer | the 8-bit target address, as received in the NEC packet |
| invTargetAddr | integer | the 8-bit inverse of the target address, as received in the NEC packet. If targetAddr != ~invTargetAddr, the error key will be present |
| cmd | integer | the 8-bit command, as received in the NEC packet |
| invCmd | integer | the 8-bit inverse of hte command, as received in the NEC packet. If cmd != ~invCmd, the error key will be present |
| error | string | present if an error is detected while decoding the NEC packet, such as cmd != ~invCmd |

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| packet_blob | blob | N/A | A binary blob containing an NEC packet, as returned by packetTableToBlob |

### decodeExtendedNec(*packet_blob*)

#### Returns
Table
| key | type | Description |
| targetAddr | integer | the 16-bit target address, as received in the NEC packet |
| cmd | integer | the 8-bit command, as received in the NEC packet |
| invCmd | integer | the 8-bit inverse of hte command, as received in the NEC packet. If cmd != ~invCmd, the error key will be present |
| error | string | present if an error is detected while decoding the NEC packet, such as cmd != ~invCmd |

#### Parameters
| Name    | Type    | Default | Description |
|---------|---------|---------|-------------|
| packet_blob | blob | N/A | A binary blob containing an NEC packet, as returned by packetTableToBlob |

#### Example

```squirrel
class IRReceiver {...}

function logRxPacket(packet_table) {
    // Throw away packets too short to be fully formed NEC packets
    if (packet_table.len() < 32) { return; }
    
    // Pack array of transitions into a binary blob
    local packet_blob = irRx.packetTableToBlob(packet_table);
    
    // Attempt to decode the binary blob as an NEC packet
    local necPacket = irRx.decodeNec(packet_blob);
    server.log(format("Decoding NEC Packet: 0x%08X",necPacket.raw));
    if ("error" in necPacket) {
        server.log("Error while decoding NEC packet: "+necPacket.error);
        server.log("Trying Extended NEC");
        necPacket = irRx.decodeExtendedNec(packet_blob);
    }

    server.log(format("Addr: 0x%02X, Cmd: 0x%02X", necPacket.targetAddr, necPacket.cmd));
}

// instantiate an IR receiver
irRx <- IRreceiver(hardware.pin9, logRxPacket);
```

## License 
The IR Transmitter class is licensed under the [MIT License](https://github.com/electricimp/TMD2772/blob/master/LICENSE).