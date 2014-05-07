//..............................................................................
server.log("Device booted.");
ble112.reboot();

//..............................................................................
ble112.on("system_boot", function(event) {

    // Ping the device, make sure we can see it
    ble112.system_hello(function(response) {
        
        // Prepare the advertising data to Apple specifications
        local adv_data = 
            // Flags = LE General Discovery, Single mode device
            "\x02\x01\x06" +
            
            // Manufacturer data (Apple)
            "\x1a\xff" +
            
            // Preamble
            "\x4c\x00\x02\x15" + 
            
            // UUID
            "\xE2\xC5\x6D\xB5\xDF\xFB\x48\xD2\xB0\x60\xD0\xF5\xA7\x10\x96\xE0" +
            
            // Major
            "\x12\x34" +
            
            // Minor
            "\x56\x78" + 
            
            // TX Power (-58)
            "\xc6";
            
        
        // Set the advertising data
        ble112.gap_set_adv_data(0, adv_data)
        
        // Set the advertising interval
        ble112.gap_set_adv_parameters(200, 100, 7);
        
        // Start advertising
        ble112.gap_set_mode(BLE_GAP_DISCOVERABLE_MODE.GAP_USER_DATA, BLE_GAP_CONNECTABLE_MODE.GAP_UNDIRECTED_CONNECTABLE);
        
    })
})

//..............................................................................
// Handle a disconnect by restarting advertising
ble112.on("connection_disconnected", function(event) {
    
    // Set the advertising interval
    ble112.gap_set_adv_parameters(200, 100, 7);
    
    // Start advertising
    ble112.gap_set_mode(BLE_GAP_DISCOVERABLE_MODE.GAP_USER_DATA, BLE_GAP_CONNECTABLE_MODE.GAP_UNDIRECTED_CONNECTABLE);
    
});

