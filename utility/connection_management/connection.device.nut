// -----------------------------------------------------------------------------
// Connection manager

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
        connected = false;
        reason = _reason;
        server.connect(reconnect.bindenv(this), CONNECTION_TIMEOUT);
        if ("disconnected" in callbacks) callbacks.disconnected();
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
    function is_connected() {
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
    if (cm.is_connected()) server.log("Connected");
    led_grn.write(cm.is_connected() ? 0 : 1);
    led_red.write(cm.is_connected() ? 1 : 0);
} 

cm <- Connection();
cm.ondisconnect(changed_status);
cm.onreconnect(changed_status);
changed_status();

