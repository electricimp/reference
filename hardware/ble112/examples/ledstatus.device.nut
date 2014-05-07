// These are produced by BGUpdate in the attributes.txt file
const c_led_status = 17;

//..............................................................................
server.log("Device booted.");
ble112.reboot();

//..............................................................................
ble112.on("system_boot", function(event) {

    // Ping the device, make sure we can see it
    ble112.system_hello(function(response) {
        
        // Configure the pins on port 1 and turn off the blue LED
        ble112.hardware_io_port_write(1, 0x01, 0);
        ble112.hardware_io_port_config_direction(1, 0x01);
        
        // Update the GATT database to show the same status.
        ble112.attributes_write(c_led_status, 0, 0);
        
        // Set the advertising interval
        ble112.gap_set_adv_parameters(320, 480, 7);
        
        // Start advertising
        ble112.gap_set_mode(BLE_GAP_DISCOVERABLE_MODE.GAP_GENERAL_DISCOVERABLE, BLE_GAP_CONNECTABLE_MODE.GAP_UNDIRECTED_CONNECTABLE);
        
    })
})

//..............................................................................
// Handle a connection by turning on the LED
ble112.on("connection_status", function(event) {
    
    if (event.payload.flags.connected) {
        // Turn on the LED
        ble112.hardware_io_port_write(1, 0x01, 1);
        
        // Update the GATT database to show the same status.
        ble112.attributes_write(c_led_status, 0, 1);
    }
    
});
    
//..............................................................................
// Handle a disconnect by restarting advertising
ble112.on("connection_disconnected", function(event) {
    
    // Turn off the LED again
    ble112.hardware_io_port_write(1, 0x01, 0);

    // Update the GATT database to show the same status.
    ble112.attributes_write(c_led_status, 0, 0);
    
    // Set the advertising interval
    ble112.gap_set_adv_parameters(320, 480, 7);
    
    // Start advertising
    ble112.gap_set_mode(BLE_GAP_DISCOVERABLE_MODE.GAP_GENERAL_DISCOVERABLE, BLE_GAP_CONNECTABLE_MODE.GAP_UNDIRECTED_CONNECTABLE);
    
});

//..............................................................................
// Handle a change to the value of an attribute
ble112.on("attributes_value", function(event) {
    
    // If the LED attribute changes
    if (event.payload.handle == c_led_status) {
        
        // Change the LED status too
        ble112.hardware_io_port_write(1, 0x01, event.payload.value[0]);
    }
})

