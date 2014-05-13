// #include "bglib.device.nut"

// -------------------------------------------------------------------------
function hexdump(label, message) {
    local line = blob(80);
    local endofline = line.len();
    local block1 = label.len() + 2;
    local block3 = endofline-20;
    
    for (local i = 0; i < line.len(); i++) line[i] = ' ';
    line.seek(0); line.writestring(label);
    line[block3] = '|'; line[endofline-3] = '|'; line[endofline-2] = '\r'; line[endofline-1] = '\n';
            
    local hex_pos = block1, asc_pos = block3+1, ch_in_line = 0;
    for (local i = 0; i < message.len(); i++) {
        local ch = message[i];
        ch_in_line++;
        
        local ch_hex = format("%02x", ch);
        line[hex_pos++] = ch_hex[0];
        line[hex_pos++] = ch_hex[1];
        
        if (ch_in_line == 16) hex_pos += 3;
        else if (ch_in_line == 8) hex_pos += 2;
        else hex_pos += 1;
 
        if (ch >= ' ' && ch <= '~') line[asc_pos++] = ch;
        else line[asc_pos++] = '.';
 
        if (ch_in_line == 16) {
            hex_pos = block1;
            asc_pos = block3+1;
            ch_in_line = 0;
            
            uart_log.write(line.tostring());
            
            // Reset the blob;
            for (local i = 0; i < line.len(); i++) line[i] = ' ';
            line.seek(0); line.writestring(label);
            line[block3] = '|'; line[endofline-3] = '|'; line[endofline-2] = '\r'; line[endofline-1] = '\n';
        }
    }
    
    if (ch_in_line > 0) {
        uart_log.write(line.tostring());
    }
}

// -------------------------------------------------------------------------
function debug_read() {
    // Responds to commands from the debug port
    local ch;
    while ((ch = uart_log.read()) != -1) {
        switch (ch) {
            case '\r': uart_log.write("\r\n"); 
                       break;
            case 'c':  uart_log.write("\x1B[2J"); 
                       break;
            case 'd':  BLE_LOG_DEBUG = 1 - BLE_LOG_DEBUG; 
                       break;
            case 'D':  BLE_LOG_COMMS = 1 - BLE_LOG_COMMS; 
                       break;
            case 'r':  uart_log.write("Rebooting the ble112\r\n"); 
                       ble112.reboot(); 
                       break;
            case 'R':  uart_log.write("Rebooting the imp\r\n"); 
                       uart_log.flush(); 
                       imp.deepsleepfor(1); 
                       break;
            case 's':  uart_log.write("Display statistics ...\r\n"); 
                       break;
        }
    }
}


//..............................................................................
server.log("Device booted.");
ble112 <- BGLib(hardware.uart1289, hardware.pinB, hardware.pinA);

uart_log <- hardware.uart6E;
uart_log.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS, debug_read);

ble112.log("APP", "\r\n\r\nBooted ...\r\n\n\n\n\n\n\n\n\n\n\n\n");
ble112.reboot();

//..............................................................................
ble112.on("log", function(type, message) {
    
    if (message == "event gap_scan_response") {
        // Dump these
    } else if (type == "ERR") {
        uart_log.write(format("%s: %s\r\n", type, message));
        server.error(format("%s: %s", type, message));
    } else if (type == "SEND" || type == "RECV") {
        hexdump(type, message);
    } else if (type == "DUMP") {
        hexdump(type, message);
    } else {
        uart_log.write(format("%s: %s\r\n", type, message));
        server.log(format("%s: %s", type, message));
    }    
});

//..............................................................................
ble112.on("system_boot", function(event) {

    // Ping the device, make sure we can see it
    ble112.system_address_get(function(response) {
        
        if (response.result == 0) {
            // Store this globally
            address = format("%s", response.payload.address);
            local location = {};
            location.address <- address;
            location.mac <- imp.getmacaddress();
            location.deviceid <- hardware.getdeviceid();
            agent.send("location", location);
            
            // Start passive scanning
            discover_mode();
        } else {
            ble112.log("APP", "Error detecting the BLE112.");
        }
    })
})

//..............................................................................
connect_to <- {};
active_scanning <- false;
conn_timer <- null;
agent.on("discover", function(address) {
    
    // Register this address to be discovered
    if (!(address in connect_to)) connect_to[address] <- {};
    connect_to[address].waiting <- 3;
    
})

//..............................................................................
address <- "";
scans <- {};
scans_changed <- false;
gatts <- {};
gatts_changed <- false;
function discover_mode(active = false) {
    
    // Update the state of the scanning
    active_scanning = active;
    
    // Setup the scanning in passive mode
    ble112.gap_set_scan_parameters(75, 50, active ? 1 : 0);

    // start scanning for peripherals
    ble112.gap_discover(BLE_GAP_DISCOVER_MODE.GAP_DISCOVER_GENERIC);

    // Handle incoming scan responses here
    ble112.on("gap_scan_response", function(event) {
        
        if (!(event.payload.sender in gatts)) {
            gatts[event.payload.sender] <- {};
        }
        
        local gatt = gatts[event.payload.sender];
        if (!(event.payload.sender in scans)) {
            local sender = {};
            sender.new <- true;
            sender.old <- false;
            sender.addr <- event.payload.sender;
            sender.addr_type <- event.payload.address_type;
            sender.type <- event.payload.packet_type;
            sender.location <- address;
            scans[event.payload.sender] <- sender;
            
            // A new device should trigger an active scan
            gatts_changed = true;
            
            // Temporary - mark this to be connected to
            if (!(address in connect_to)) {
                connect_to[address] <- {};
                connect_to[address].waiting <- 3;
            }
            
        }
        
        local sender = scans[event.payload.sender];
        sender.rssi <- event.payload.rssi;
        sender.last_seen <- time();
        if (sender.old) {
            sender.first_seen <- time();
            sender.old <- false;
            scans_changed = true;
        }
        if (sender.new) {
            sender.first_seen <- time();
            scans_changed = true;
        }
        
        // Parse the advertising packet
        foreach (advdata in event.payload.data) {
            if (advdata.type == BLE_GAP_AD_TYPES.GAP_AD_TYPE_LOCALNAME_COMPLETE) {
                // This is a localname packet
                local localname = format("%s", advdata.data);
                gatt.localname <- localname;
            } else if (advdata.type == BLE_GAP_AD_TYPES.GAP_AD_TYPE_MANUFACTURER_DATA) {
                // This is an ibeacon
                if (advdata.data.slice(0, 4) == "\x4c\x00\x02\x15") {
                    // This is an iBeacon
                    local uuid = advdata.data.slice(4, 20);
                    uuid = ble112.hexdump(uuid, false).toupper();
                    gatt.uuid <- uuid;

                    local major = advdata.data.slice(20, 22);
                    major = (major[0] << 8) + (major[1]);
                    gatt.major <- major;

                    local minor = advdata.data.slice(22, 24);
                    minor = (minor[0] << 8) + (minor[1]);
                    gatt.minor <- minor;

                    local power = advdata.data[24];
                    gatt.power <- power;
                }
            }
        }
            

        // If we are waiting for this beacon, connect to it
        if (sender.addr in connect_to) {

            if (connect_to[sender.addr].waiting <= 0) {
                
                // We don't have any more tries left
                delete connect_to[sender.addr];
                
            } else if (event.payload.packet_type == "non-connectable") {
            
                // We can't connect to this beacon right now
                connect_to[sender.addr].waiting--;
                
            } else {
            
                // Finally, try to connect
                ble112.on("gap_scan_response", null);
                connect_to[sender.addr].waiting--;
                
                ble112.gap_connect_direct(sender.addr, sender.addr_type, 0x06, 0x0c, 0x200, 0);
                
                // Handle a connection timeout
                conn_timer = imp.wakeup(5, function() {
                    conn_timer = null;
                    
                    ble112.log("APP", format("Timeout connecting to %s", sender.addr));
                    
                    // Cancel the connection attempt
                    ble112.gap_end_procedure();
                    
                    // Return to passive scanning
                    discover_mode()
                })
            }
        }
    })

}


//..............................................................................
// Handle new connections here
connections <- {};
attributes <- [];
ble112.on("connection_status", function(event) {
    
    if (conn_timer) imp.cancelwakeup(conn_timer); conn_timer = null;
    ble112.log("APP", format("Connection from %s (%s) was %s",
                    event.payload.address, 
                    event.payload.address_type,
                    event.payload.flags.connected ? "successful" : "unsuccessful"));
                    
    local address = event.payload.address;
    connections[event.payload.connection] <- {  "address": address };
    
    attributes.clear();
    attributes.push({name="name", uuid="\x00\x2A"})
    attributes.push({name="battery", uuid="\x19\x2A"})
    attributes.push({name="model", uuid="\x24\x2A"})
    attributes.push({name="serial", uuid="\x25\x2A"})
    attributes.push({name="manufacturer", uuid="\x29\x2A"})

    // Start the service discovery process
    attribute_scan(event.payload.connection);
});

//..............................................................................
// Step through the standard attributes reading their values
function attribute_scan(connection) {
    
    if (attributes.len() > 0) {
        
        // Read the next attribute
        ble112.attclient_read_by_type(connection, 0x0001, 0xFFFF, attributes[0].uuid, function(response) {
            
            if (response.result == 0) {
                ble112.on("attclient_attribute_value", function(event) {
                    // We have an attribute, store it
                    local address = connections[connection].address;
                    local attr = attributes[0].name;
                    if (attr == "battery") {
                        gatts[address][attr] <- format("%d%%", event.payload.value[0]);
                    } else {
                        gatts[address][attr] <- format("%s", event.payload.value);;
                    }
                });
                
                ble112.on("attclient_procedure_completed", function(event) {
                    // That's all for this search
                    attributes.remove(0);
                    attribute_scan(connection);
                });
            } else {
                // Abort
                attributes.clear();
                attribute_scan(connection);
            }
            
        });
        
    } else {

        // That's all folks
        ble112.connection_disconnect(connection);
        ble112.on("attclient_attribute_value", null);
        ble112.on("attclient_procedure_completed", null);
        
        // Send the current gatt data
        agent.send("gatts", gatts)
        gatts = {};
    }
        
}


//..............................................................................
// Handle disconnections
ble112.on("connection_disconnected", function(event) {
    
    if (conn_timer) imp.cancelwakeup(conn_timer); conn_timer = null;
    
    ble112.log("APP", "Disconnected from " + connections[event.payload.connection].address);
    delete connect_to[connections[event.payload.connection].address];
    delete connections[event.payload.connection];
    
    // Return to discover mode (active if we are scanning for specific devices)
    discover_mode()
})


//..............................................................................
function idle_updates() {
    idle_update_timer = imp.wakeup(60, idle_updates);
    
    agent.send("scans", scans);
    scans_changed = false;
    
    agent.send("gatts", gatts);
    gatts = {};

    // Turn on active scanning for a while
    if (gatts_changed && !active_scanning) {
        // Turn off passive scanning
        ble112.gap_end_procedure(function(response) {
            // Turn on active scanning
            discover_mode(true);
            
            // Wait 20 seconds
            imp.wakeup(20, function() {
                gatts_changed = false;
                
                // Turn off active scanning
                ble112.gap_end_procedure(function(response) {
                    
                    // Return to discover mode (active if we are scanning for specific devices)
                    discover_mode()

                });
            })
        });
    }

}
idle_update_timer <- imp.wakeup(60, idle_updates);


//..............................................................................
function check_for_changes() {
    imp.wakeup(1, check_for_changes);

    // Look for old devices
    foreach (sender in scans) {
        if (!sender.old) {
            if (time() - sender.last_seen > 10) {
                sender.old = true;
                scans_changed = true;
            }
        }
    }
        
    // Send the changed sender list
    if (scans_changed) {
        
        scans_changed = false;
        agent.send("scans", scans);
        
        imp.cancelwakeup(idle_update_timer);
        idle_update_timer <- imp.wakeup(60, idle_updates);
        
        // Remove old devices
        foreach (id,sender in scans) {
            if (sender.old) {
                delete scans[id];
            } else {
                sender.new = false;
            }
        }
            
        
    }
}
check_for_changes();


