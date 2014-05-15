// -----------------------------------------------------------------------------
// Connection manager

class Connection {

    static CONNECTION_TIMEOUT = 30;
    
    connected = null;
    reason = null;
    reconnected = null;
    
    // .........................................................................
    constructor() {
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
    }
    
    // .........................................................................
    // Reconnect on network failure
    function reconnect(_state) {
        if (_state == SERVER_CONNECTED) {
            connected = true;
            if (reconnected) reconnected(reason);
        } else {
            server.connect(reconnect.bindenv(this), CONNECTION_TIMEOUT);
        }
    }
    
    // .........................................................................
    function onreconnect(_reconnected) {
        reconnected = _reconnected;
    }

    // .........................................................................
    function is_connected() {
    	return connected;
    }
}


// ------------------[ Example usage ]------------------

cm <- Connection();
cm.onreconnect(function(reason) {
	server.log("Connected")
});
