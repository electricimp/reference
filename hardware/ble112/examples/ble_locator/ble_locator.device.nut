//..............................................................................
uuids <- {
    "2F234454CF6D4A0FADF2F4911BA9FFA6": true
};
address <- null;
scans <- {};

//..............................................................................
server.log("Device booted.");
ble112 <- BGLib(hardware.uart1289, hardware.pinB, hardware.pinA);

ble112.log("APP", "Booted ...");
ble112.reboot();

//..............................................................................
ble112.on("system_boot", function(event) {

    // Ping the device, make sure we can see it
    ble112.system_address_get(function(response) {
        
        if (response.result == 0 || response.result == "timeout") {
            
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
            ble112.log("ERR", "Error detecting the BLE112.");
        }
    })
})


//..............................................................................
function discover_mode(active = false) {
    
    // Setup the scanning in passive mode
    ble112.gap_set_scan_parameters(75, 50, active ? 1 : 0);

    // start scanning for peripherals
    ble112.gap_discover(BLE_GAP_DISCOVER_MODE.GAP_DISCOVER_GENERIC);

    // Handle incoming scan responses here
    ble112.on("gap_scan_response", function(event) {
        
        // Parse the advertising packet
        foreach (advdata in event.payload.data) {
            if (advdata.type == BLE_GAP_AD_TYPES.GAP_AD_TYPE_MANUFACTURER_DATA) {
                // This is an ibeacon
                if (advdata.data.slice(0, 4) == "\x4c\x00\x02\x15") {
                    // This is an iBeacon
                    local uuid = advdata.data.slice(4, 20);
                    uuid = parse_uuid(uuid);
                    if (uuid in uuids) {

                        local major = advdata.data.slice(20, 22);
                        major = (major[0] << 8) + (major[1]);
    
                        local minor = advdata.data.slice(22, 24);
                        minor = (minor[0] << 8) + (minor[1]);
    
                        local power = advdata.data[24];
                        
                        local beaconid = format("%s:%d:%d", uuid, major, minor)
                        if (!(beaconid in scans)) {
                            scans[beaconid] <- {};
                            scans[beaconid].rssi <- {};
                            scans[beaconid].rssi[address] <- {};
                            scans[beaconid].rssi[address].time <- time();
                            scans[beaconid].rssi[address].samples <- 0;
                            scans[beaconid].rssi[address].rssi <- 0.0;
                        }
                        
                        local beacon = scans[beaconid];
                        beacon.uuid <- uuid;
                        beacon.major <- major;
                        beacon.minor <- minor;
                        beacon.time <- time();
                        beacon.rssi[address].samples++;
                        beacon.rssi[address].rssi += event.payload.rssi;
                        beacon.rssi[address].rssi /= 2;
                    }
                }
            }
        }
    })
}


//..............................................................................
function parse_uuid(uuid) {
    local result = "";
    foreach (ch in uuid) {
        result += format("%02X", ch)
    }
    return result;
}


//..............................................................................
function idle_updates() {

    imp.wakeup(60, idle_updates);
    if (scans.len() > 0) {
        agent.send("scans", scans);
        scans = {};
    }
    
}
imp.wakeup(10, idle_updates);



