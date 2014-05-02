//..............................................................................
enum State {
    Standby,
    AdvertiserSearch,
    Connecting,
    Connected,
    QueryingGroups,
    QueryingCharacteristics,
    ReadingCharacteristicsValues,
    ReadingName,
    ReadingAppearance,
    Disconnecting
}
scanned <- {};
connections <- {};
currentState <- State.Standby;

function discover_mode() {
    
    // Handle incoming scan responses here
    ble112.on("gap_scan_response", function(event) {
        
        if (currentState == State.AdvertiserSearch) {
            
            // If we have a new device 
            if (!(event.payload.sender in scanned)) {
                
                // Get the local name of the device if we have an active connection.
                // This can't happen in a passive connection
                local local_name = "Unnamed";
                /*
                if (event.payload.data.len() > 2) {
                    if (event.payload.data[1] == 0x09) {
                        local_name = format("%s", event.payload.data.slice(2))
                    }
                }
                */
                ble112.log("APP", format("New device: %s (%s)", local_name, event.payload.sender));
                
                scanned[event.payload.sender] <- {  "payload": event.payload, 
                                                    "local_name": local_name, 
                                                    "name": local_name, 
                                                    "appearance": 0,
                                                    "connected": false,
                                                    "first_seen" : time(),
                                                    "last_seen" : time(),
                                                    "next_connect" : time() + BLE_CONN_BACKOFF,
                                                    "last_reported" : 0,
                                                 };
                                                 
                // Connect to this new device
                currentState = State.Connecting;
            }
            
            // If we have an old device we haven't connected to yet
            else if (!scanned[event.payload.sender].connected && time() >= scanned[event.payload.sender].next_connect) {
                
                // Connect to this device
                scanned[event.payload.sender].last_seen = time();
                currentState = State.Connecting;
                
            } else {
                
                // Update the record that we have seen the device
                scanned[event.payload.sender].last_seen = time();
                
            }
            
            // Do we connect to this device?
            if (currentState == State.Connecting) {
                ble112.gap_connect_direct(event.payload.sender, event.payload.address_type, 0x06, 0x0c, 0x200, 0);
            }
        } 
    })
    
    
    // Handle new connections here
    ble112.on("connection_status", function(event) {
        ble112.log("APP", format("Connection from %s (%s) was %s",
                        event.payload.address, event.payload.address_type,
                        event.payload.flags.connected ? "successful" : "unsuccessful"));
        
        // Store the connection for later
        connections[event.payload.connection] <- {  "address": event.payload.address, 
                                                    "services" : {}, // services -> characteristics -> handle, value
                                                    "_services" : [],
                                                    "_characteristics" : [],
                                                 };
        // Back off reconnecting
        local scanned_device = scanned[event.payload.address];
        scanned_device.next_connect = time() + BLE_CONN_BACKOFF;
        
        // Start by reading the name
        currentState = State.ReadingName;
        ble112.attclient_read_by_type(event.payload.connection, 0x0001, 0xFFFF, "\x00\x2A")
        ble112.on("attclient_attribute_value", function(event) {
            
            // We have the name, store it
            scanned_device.connected = true;
            local name = format("%s", event.payload.value);
            if (name != "") {
                scanned_device.name = name;
            }
            ble112.log("APP", format("Connected to: %s", scanned_device.name));
        });
    });
    
    
    // Handle ATT Client read results
    ble112.on("attclient_group_found", function(event) {

        // ble112.log("APP", format("Discovered service group of type '%s'", ble112.hexdump(event.payload.uuid, false)));
        
        // Store the new service group
        local connection = connections[event.payload.connection];
        connection.services[event.payload.uuid] <- {};
        connection._services.push( { "start": event.payload.start, 
                                     "end": event.payload.end, 
                                     "uuid": event.payload.uuid } );
    })
    
    
    // Finished reading the ATT Client results
    ble112.on("attclient_procedure_completed", function(event) {
        
        local connection = connections[event.payload.connection];

        // We have finished reading the name and appearance of the device
        if (currentState == State.ReadingName) {
            
            // Ask the device to send its appearance
            currentState = State.ReadingAppearance;
            ble112.attclient_read_by_type(event.payload.connection, 0x0001, 0xFFFF, "\x01\x2A")
            
            // Now read the appearance
            ble112.on("attclient_attribute_value", function(event) {
                
                // We have the appearance, store it
                local connection = connections[event.payload.connection];
                scanned[connection.address].appearance = event.payload.value[0] + (event.payload.value[1] >> 8);

            });
            
            return;
        }
        if (currentState == State.ReadingAppearance) {
            
            // Ask the device to list all its service groups. 
            // Sends zero or more attclient_group_found's and finishes with attclient_procedure_completed.
            currentState = State.QueryingGroups;
            ble112.attclient_read_by_group_type(event.payload.connection, 0x0001, 0xFFFF, "\x00\x28")
            return;
            
        }
        
        // We have finished scanning attclient_read_by_group_type
        if (currentState == State.QueryingGroups) {
            currentState = State.QueryingCharacteristics;
        } 
        
        // We have finished scannning attclient_find_information
        if (currentState == State.QueryingCharacteristics || currentState == State.ReadingCharacteristicsValues) {
            if (connection._services.len() > 0) {
                
                // Ask the next service group
                local service = connection._services[0]; connection._services.remove(0);
                
                // Prepare to handle the responses
                ble112.on("attclient_find_information_found", function(event) {
                    
                    // ble112.log("APP", format("Discovered characteristic of type '%s'", ble112.hexdump(event.payload.uuid, false)));
                    
                    // Store the result
                    local connection = connections[event.payload.connection];
                    connection.services[service.uuid][event.payload.uuid] <- { "handle": event.payload.chrhandle, "value": null} ;
                    
                    // Don't scan the infrastructure nodes
                    switch (event.payload.uuid) {
                        // Level 0
                        case "\x00\x18": // Generic access profile
                        case "\x01\x18": // Generic attribute profile
                            return;
                        
                        // Level 1
                        case "\x00\x28": // Primary service
                        case "\x00\x28": // Primary service
                        case "\x01\x28": // Secondary service
                        case "\x02\x28": // Include
                        case "\x03\x28": // Chacteristic
                            return;
                        
                        // Level 2
                        case "\x00\x29": // Characteristic Extended Properties
                        // case "\x01\x29": // Characteristic User Description 
                        case "\x02\x29": // Client Characteristic Configuration 
                        case "\x03\x29": // Server Characteristic Configuration
                        case "\x04\x29": // Characteristic Format
                        case "\x05\x29": // Characteristic Aggregate Format
                        case "\x06\x29": // Valid Range
                        case "\x07\x29": // External Report Reference
                        case "\x08\x29": // Report Reference
                            return;
                    }
                    
                    // Queue the scanner to read the values
                    connection._characteristics.push( { "service": service.uuid,
                                                        "uuid": event.payload.uuid,
                                                        "handle": event.payload.chrhandle } );
                })

                // Sends the "give me the characteristics of this service group" command
                // ble112.log("APP", format("Discovering characteristics for service '%s'", ble112.hexdump(service.uuid, false)));
                ble112.attclient_find_information(event.payload.connection, service.start, service.end);
                
            } else {
                
                currentState = State.ReadingCharacteristicsValues;
                ble112.on("attclient_find_information_found", null);
                
                if (connection._characteristics.len() > 0) {
                    
                    // Ask for the next characteristic
                    local characteristic = connection._characteristics[0]; connection._characteristics.remove(0);
                    
                    // Prepare to handle the response
                    ble112.on("attclient_attribute_value", function (event) {
                        
                        connection.services[characteristic.service][characteristic.uuid].value = event.payload.value;
                        
                        // Pretty up the data
                        local service;
                        switch (characteristic.service) {
                            // Level 1
                            case "\x00\x18": service = "Generic Access"; break;
                            case "\x0a\x18": service = "Device Information"; break;
                            case "\x0f\x18": service = "Battery"; break;

                            default: 
                                service = ble112.hexdump(characteristic.service, false);
                        }
                            
                        local value = format("[%s]", event.payload.value);
                        if (event.payload.value.len() <= 2) {
                            value = ble112.hexdump(event.payload.value, true);
                        } else {
                            for (local i = 0; i < event.payload.value.len(); i++) {
                                local ch = event.payload.value[i];
                                if (!(ch >= ' ' && ch <= '~') && !(ch == 0x00 && i == event.payload.value.len()-1)) {
                                    value = ble112.hexdump(event.payload.value, true);
                                    break;
                                }
                            }
                        }
                        
                        local uuid; 
                        switch (characteristic.uuid) {
                            // Level 2
                            case "\x01\x29": uuid = "Characteristic Description"; break;
                            
                            // Level 3
                            case "\x00\x2a": uuid = "Device Name"; break;
                            case "\x01\x2a": uuid = "Appearance"; break;
                            case "\x02\x2a": uuid = "Privacy"; break;
                            case "\x19\x2a": uuid = "Battery Level"; break;
                            case "\x23\x2a": uuid = "System ID"; break;
                            case "\x24\x2a": uuid = "Model Number"; break;
                            case "\x25\x2a": uuid = "Serial Number"; break;
                            case "\x26\x2a": uuid = "Firmware Revision"; break;
                            case "\x27\x2a": uuid = "Hardware Revision"; break;
                            case "\x28\x2a": uuid = "Software Revision"; break;
                            case "\x29\x2a": uuid = "Manufacturer Name"; break;
                            
                            // Catchall
                            default: uuid = ble112.hexdump(characteristic.uuid, false);
                        }
                        
                        
                        ble112.log("APP", format("Attribute for service '%s', characteristic '%s': %s", service, uuid, value));
                        
                        if (connection._characteristics.len() > 0) {
                            
                            // Resends the "give me the value for this characteristic" command
                            characteristic = connection._characteristics[0]; connection._characteristics.remove(0);
                            // ble112.log("APP", format("Reading attributes for service '%s', characteristic '%s' ...", ble112.hexdump(characteristic.service, false), ble112.hexdump(characteristic.uuid, false)));
                            ble112.attclient_read_by_handle(event.payload.connection, characteristic.handle);
                            
                        } else {
                            
                            delete connection._services;
                            delete connection._characteristics;
                            ble112.on("attclient_attribute_value", null);
                            
                            currentState = State.Disconnecting;
                            ble112.connection_disconnect(event.payload.connection);
                            
                            ble112.log("APP", format("Discovered '%s' with appearance %d", scanned[connection.address].name, scanned[connection.address].appearance));

                        }
                    });
                    
                    // Sends the "give me the value for this characteristic" command
                    ble112.log("APP", format("Reading attributes for service '%s', characteristic '%s' ...", ble112.hexdump(characteristic.service, false), ble112.hexdump(characteristic.uuid, false)));
                    ble112.attclient_read_by_handle(event.payload.connection, characteristic.handle);
                } else {
                    
                    delete connection._services;
                    delete connection._characteristics;
                    ble112.on("attclient_attribute_value", null);
                    
                    currentState = State.Disconnecting;
                    ble112.connection_disconnect(event.payload.connection);
                    
                    ble112.log("APP", format("Discovered '%s' with appearance %d", scanned[connection.address].name, scanned[connection.address].appearance));

                }
            }
        }
    })
    
    
    // Handle disconnections
    ble112.on("connection_disconnected", function(event) {
        
        ble112.log("APP", format("%s has disconnected\r\n", connections[event.payload.connection].address));
        delete connections[event.payload.connection];
        
        // Return to discover mode
        discover_mode()
    })
    
    
    // Configure passive scanning
    currentState = State.AdvertiserSearch;
    ble112.gap_set_scan_parameters(75, 50, 0, function(response) {
        
        // start scanning for slaves
        ble112.gap_discover(BLE_GAP_DISCOVER_MODE.GAP_DISCOVER_GENERIC);
    })
    
}


//..............................................................................
ble112.on("system_boot", function(event) {

    // Initialise the state
    scanned = {};
    connections = {};
    currentState = State.Standby;

    // Ping the device, make sure we can see it
    ble112.system_hello(function(response) {
        discover_mode();
        
        if (checkDevices_timer) imp.cancelwakeup(checkDevices_timer); 
        checkDevices_timer = imp.wakeup(1, checkDevices);
    })
    
})


//..............................................................................
checkDevices_timer <- null;
function checkDevices() {
    checkDevices_timer = imp.wakeup(1, checkDevices);
    
    foreach (address,data in scanned) {
        if (data.last_reported == 0 && time() - data.last_seen > 10) {
            server.log(format("Device %s (%s) has gone away", data.name, address));
            data.last_reported = time();
            data.last_seen = 0;
        } else if (data.last_reported != 0 && data.last_seen != 0) {
            server.log(format("Device %s (%s) has appeared", data.name, address));
            data.last_reported = 0;
        }
    }
}



//..............................................................................
BLE_LOG_DEBUG <- 0;
BLE_LOG_COMMS <- 0;
BLE_LOG_ERROR <- 1;
BLE_LOG_UART  <- true;
_log_last_message <- null;
_log_last_message_cnt <- 0;

ble112.on("log", function(type, message) {

    // Send binary dumps to the serial port exclusively.
    if (type == "RECV" || type == "SEND") {
        if (BLE_LOG_COMMS) {
            
            local line = blob(80);
            local endofline = line.len();
            local hexblock = (type.len() == 0) ? 0 : type.len() + 2;
            local ascblock = endofline - 20;
            
            for (local i = 0; i < line.len(); i++) line[i] = ' ';
            line.seek(0); line.writestring(type);
            line[ascblock] = '|'; line[endofline-3] = '|'; line[endofline-2] = '\r'; line[endofline-1] = '\n';
                    
            local hex_pos = hexblock, asc_pos = ascblock+1, ch_in_line = 0;
            for (local i = 0; i < message.len(); i++) {
                ch_in_line++;
                local ch = message[i];

                local ch_hex = format("%02x", ch);
                line[hex_pos++] = ch_hex[0];
                line[hex_pos++] = ch_hex[1];
                
                if (ch_in_line == 16) hex_pos += 3;
                else if (ch_in_line == 8) hex_pos += 2;
                else hex_pos += 1;

                if (ch >= ' ' && ch <= '~') line[asc_pos++] = ch;
                else line[asc_pos++] = '.';

                if (ch_in_line == 16) {
                    hex_pos = hexblock;
                    asc_pos = ascblock+1;
                    ch_in_line = 0;
                    
                    uart_log.write(line.tostring());
                    
                    // Reset the blob;
                    for (local i = 0; i < line.len(); i++) line[i] = ' ';
                    line.seek(0); line.writestring(type);
                    line[ascblock] = '|'; line[endofline-3] = '|'; line[endofline-2] = '\r'; line[endofline-1] = '\n';
                }
            }
            
            if (ch_in_line > 0) {
                uart_log.write(line.tostring());
            }
        }
        return;
    }
    
    // Send other logs to the serial port or the system logger
    if (type == "LOG" && !BLE_LOG_DEBUG) return;
    if (type == "ERR" && !BLE_LOG_ERROR) return;
    if (message.len() == 0) return;
    
    local logger = server.log.bindenv(server);
    if (type == "ERR") logger = server.error.bindenv(server);
    if (BLE_LOG_UART) {
        logger = uart_log.write.bindenv(uart_log);
    }
    
    if (message == _log_last_message) {
        // Back off if the results are repeating.
        _log_last_message_cnt++;
        if (math.sqrt(_log_last_message_cnt) % 2 == 0) {
            logger(format("%s (%d / %d): %dx %s\r\n", type, imp.getmemoryfree(), imp.rssi(), _log_last_message_cnt, message))
        }
    } else {
        _log_last_message_cnt = 1;
        _log_last_message = message;
        logger(format("%s (%d / %d): %s\r\n", type, imp.getmemoryfree(), imp.rssi(), message))
    }

})


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
            case 'r':  ble112.log("APP", "Rebooting ble112"); 
                       ble112.reboot(); 
                       break;
            case 'R':  ble112.log("APP", "Rebooting imp"); 
                       uart_log.flush(); 
                       imp.deepsleepfor(1); 
                       break;
        }
    }
}


//..............................................................................
uart_log <- hardware.uart6E;
uart_log.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS, debug_read);

//..............................................................................
server.log("Device booted.");
server.log("Key shortcuts: r = reboot ble112, R = reboot imp, c = clear screen, d = debug logs, D = comms trace");
ble112.log("APP", "\r\n\r\nBooted ...\r\n\n\n\n\n\n\n\n\n\n\n\n");
ble112.reboot();

