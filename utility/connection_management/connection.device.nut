// -----------------------------------------------------------------------------
// Connection manager
//
// This connection manager is designed to make the use of the RETURN_ON_ERROR timeout
// policy simple. All the developer has to do is create an instance of the connection 
// manager class and the timeout policy will change but the device will otherwise 
// behave the same - it will continuously try to restore a connection to the Wifi.
// Then all your network requests, like server.log(), will fail without freezing the CPU.
// 
// This class can be extended, if required, to do a few more things:
// - Regularly check server.isconnected() which will indicate a disconnected state 
//   much earlier than server.onunexpecteddisconnect().
// - Back off the reconnection attempts to conserve batteries.
// - Put the device to deep sleep while offline and reattempt to connect on wakeup.
// - Provide for developer requested connect() and disconnect() functions for manual
//   override of the defaul behaviour.
// 
class Connection {

    static CONNECTION_TIMEOUT = 30;
    
    connected = null;
    reason = null;
    callbacks = null;
    
    // .........................................................................
    constructor() {
        callbacks = {};
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, CONNECTION_TIMEOUT);
        server.onunexpecteddisconnect(disconnected.bindenv(this));
        connected = server.isconnected();
        if (!connected) server.connect(reconnect.bindenv(this), CONNECTION_TIMEOUT);
    }
    
    // .........................................................................
    function disconnected(_reason) {
        local fireevent = connected;
        connected = false;
        reason = _reason;
        server.connect(reconnect.bindenv(this), CONNECTION_TIMEOUT);
        if (fireevent && "disconnected" in callbacks) callbacks.disconnected();
    }
    
    // .........................................................................
    // Reconnect on network failure
    function reconnect(_state) {
        if (_state == SERVER_CONNECTED) {
            connected = true;
            if ("reconnected" in callbacks) callbacks.reconnected();
        } else {
            server.connect(reconnect.bindenv(this), CONNECTION_TIMEOUT);
        }
    }
    
    // .........................................................................
    function isconnected() {
        return connected;
    }

    // .........................................................................
    function ondisconnect(_disconnected = null) {
        if (_disconnected == null) delete callbacks["disconnected"];
        else callbacks["disconnected"] <- _disconnected;
    }

    // .........................................................................
    function onreconnect(_reconnected = null) {
        if (_reconnected == null) delete callbacks["reconnected"];
        else callbacks["reconnected"] <- _reconnected;
    }

}



// ------------------[ Example usage ]------------------

led_red  <- hardware.pin1;
led_grn  <- hardware.pin2;
led_grn.configure(DIGITAL_OUT); 
led_red.configure(DIGITAL_OUT); 
led_grn.write(1);
led_red.write(1);

function changed_status() {
    if (cm.isconnected()) server.log("Connected");
    led_grn.write(cm.isconnected() ? 0 : 1);
    led_red.write(cm.isconnected() ? 1 : 0);
} 

cm <- Connection();
cm.ondisconnect(changed_status);
cm.onreconnect(changed_status);
changed_status();

