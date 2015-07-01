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
// - Back off the reconnection attempts to conserve batteries.
// - Put the device to deep sleep while offline and reattempt to connect on wakeup.
// 
class Connection {

    static CONNECTION_TIMEOUT = 30;
    static SEND_TIMEOUT = 10;
    static CHECK_TIMEOUT = 5;
    static MAX_LOGS = 100;
    
    connected = null;
    connecting = false;
    stayconnected = true;
    reason = null;
    callbacks = null;
    blinkup_timer = null;
    logs = null;
    
    // .........................................................................
    constructor(_do_connect = true) {
        callbacks = {};
        logs = [];
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, SEND_TIMEOUT);
        connected = server.isconnected();
        imp.wakeup(CHECK_TIMEOUT, _check.bindenv(this));
        
        if (_do_connect && !connected) imp.wakeup(0, connect.bindenv(this));
        else if (connected) imp.wakeup(0, _reconnect.bindenv(this));
    }
    
    
    // .........................................................................
    function _check() {
        imp.wakeup(CHECK_TIMEOUT, _check.bindenv(this));
        if (!server.isconnected() && !connecting && stayconnected) {
            // We aren't connected or connecting, so we should try
            _disconnected(NOT_CONNECTED, true);
        }
    }
    

    // .........................................................................
    function _disconnected(_reason, _do_reconnect = false) {
        local fireevent = connected;
        connected = false;
        connecting = false;
        reason = _reason;
        if (fireevent && "disconnected" in callbacks) callbacks.disconnected();
        if (_do_reconnect) connect();
    }
    
    // .........................................................................
    function _reconnect(_state = null) {
        if (_state == SERVER_CONNECTED || _state == null) {
            connected = true;
            connecting = false;
            
            // Dump the logs
            while (logs.len() > 0) {
                local logo = logs[0];
                logs.remove(0);
                local d = date(logo.ts);
                local msg = format("%04d-%02d-%02d %02d:%02d:%02d UTC %s", d.year, d.month+1, d.day, d.hour, d.min, d.sec, logo.msg);
                if (logo.err) server.error(msg);
                else          server.log(msg);
            }
            
            if ("connected" in callbacks) callbacks.connected(SERVER_CONNECTED);
        } else {
            connected = false;
            connecting = false;
            connect();
        }
    }
    
    
    // .........................................................................
    function connect(withblinkup = true) {
        stayconnected = true;
        if (!connected && !connecting) {
            server.connect(_reconnect.bindenv(this), CONNECTION_TIMEOUT);
            connecting = true;
        }
        
        if (withblinkup) {
            // Enable BlinkUp for 60 seconds
            imp.enableblinkup(true);
            if (blinkup_timer) imp.cancelwakeup(blinkup_timer);
            blinkup_timer = imp.wakeup(60, function() {
                blinkup_timer = null;
                imp.enableblinkup(false);
            }.bindenv(this))
            
        }
    }
    
    // .........................................................................
    function disconnect() {
        stayconnected = false;
        server.disconnect();
        _disconnected(NOT_CONNECTED, false);
    }

    // .........................................................................
    function isconnected() {
        return connected == true;
    }

    // .........................................................................
    function ondisconnect(_disconnected = null) {
        if (_disconnected == null) delete callbacks["disconnected"];
        else callbacks["disconnected"] <- _disconnected;
    }

    // .........................................................................
    function onconnect(_connected = null) {
        if (_connected == null) delete callbacks["connected"];
        else callbacks["connected"] <- _connected;
    }

    // .........................................................................
    function log(msg, err=false) {
        if (server.isconnected()) server.log(msg);
        else logs.push({msg=msg, err=err, ts=time()})
        if (logs.len() > MAX_LOGS) logs.remove(0);
    }

    // .........................................................................
    function error(msg) {
        log(msg, true);
    }

}


// ------------------[ Example usage ]------------------

cm <- Connection();
cm.onconnect(function(reason=null) {
    cm.log("Connected")
});
cm.ondisconnect(function(reason=null) {
    cm.error("Disconnected")
});

