function toggleTVPower() {
    if (btn1.read()) {
    	// turn off the TV
        led.write(1);
        server.log("Sending");
        local pkt = irTx.buildNecPacket(0x04, 0x08);
        irTx.sendPacket(pkt, 1, 2);
        led.write(0);
    }
}

function printPacketTiming(packet) {
    server.log(format("Printing %d-symbol packet",packet.len()));
    for (local i = 0; i < packet.len(); i++) {
        local event = packet[i];
        server.log(format("%d: %d µs", event.level, event.duration));
    }
}

function logRxPacket(packet_table) {
    if (packet_table.len() < 32) { return; }
    
    // Printing the raw packet timing before attempting to decode can be 
    // very helpful when trying to determine the protocol used
    printPacketTiming(packet_table);
    local packet_blob = irRx.packetTableToBlob(packet_table);
    
    local necPacket = irRx.decodeNec(packet_blob);
    server.log(format("Decoding NEC Packet: 0x%08X",necPacket.raw));
    if ("error" in necPacket) {
        server.log("Error while decoding NEC packet: "+necPacket.error);
        server.log("Trying Extended NEC");
        necPacket = irRx.decodeExtendedNec(packet_blob);
    }

    server.log(format("Addr: 0x%02X, Cmd: 0x%02X", necPacket.targetAddr, necPacket.cmd));
}

/* RUNTIME STARTS HERE ------------------------------------------------------*/

server.log(imp.getsoftwareversion());

led <- hardware.pin5;
led.configure(DIGITAL_OUT, 0);

btn1 <- hardware.pin1;
btn1.configure(DIGITAL_IN_PULLDOWN, toggleTVPower);

// instantiate an IR transmitter
irTx <- IRtransmitter(hardware.spi257, hardware.pin8);

// instantiate an IR receiver
irRx <- IRreceiver(hardware.pin9, logRxPacket);
