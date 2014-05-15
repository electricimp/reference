

// -----------------------------------------------------------------------------
class Bullwinkle
{
    _handlers = null;
    _sessions = null;
    _partner  = null;
    _history  = null;
    _timeout  = 10;
    _retries  = 1;


    // .........................................................................
    constructor() {
        const BULLWINKLE = "bullwinkle";
        
        _handlers = { timeout = null, receive = null };
        _partner  = is_agent() ? device : agent;
        _sessions = { };
        _history  = { };
        
        // Incoming message handler
        _partner.on(BULLWINKLE, _receive.bindenv(this));
    }
    
    
    // .........................................................................
    function send(command, params = null) {
        
        // Generate an unique id
        local id = _generate_id();
        
        // Create and store the session
        _sessions[id] <- Bullwinkle_Session(this, id, _timeout, _retries);

        return _sessions[id].send("send", command, params);
    }
    
    
    // .........................................................................
    function ping() {
        
        // Generate an unique id
        local id = _generate_id();
        
        // Create and store the session
        _sessions[id] <- Bullwinkle_Session(this, id, _timeout, _retries);
        
        // Send it
        return _sessions[id].send("ping");
    }
    
    
    // .........................................................................
    function is_agent() {
        return (imp.environment() == ENVIRONMENT_AGENT);
    }

    
    // .........................................................................
    function onreceive(callback) {
        _handlers.receive <- callback;
    }
    
    
    // .........................................................................
    function ontimeout(callback, timeout = null) {
        _handlers.timeout <- callback;
        if (timeout != null) _timeout = timeout;
    }
    
    
    // .........................................................................
    function set_timeout(timeout) {
        _timeout = timeout;
    }
    
    
    // .........................................................................
    function set_retries(retries) {
        _retries = retries;
    }
    
    
    // .........................................................................
    function _generate_id() {
        // Generate an unique id
        local id = null;
        do {
            id = math.rand();
        } while (id in _sessions);
        return id;
    }
    
    // .........................................................................
    function _is_unique(context) {
        
        // Clean out old id's from the history
        local now = time();
        foreach (id,t in _history) {
            if (now - t > 100) {
                delete _history[id];
            }
        }
        
        // Check the current context for uniqueness
        local id = context.id;
        if (id in _history) {
            return false;
        } else {
            _history[id] <- time();
            return true;
        }
    }
        
    // .........................................................................
    function _clone_context(ocontext) {
        local context = {};
        foreach (k,v in ocontext) {
            switch (k) {
                case "type":
                case "id":
                case "time":
                case "command":
                case "params":
                    context[k] <- v;
            }
        }
        return context;
    }
    
    
    // .........................................................................
    function _end_session(id) {
        if (id in _sessions) {
            delete _sessions[id];
        }
    }


    // .........................................................................
    function _receive(context) {
        local id = context.id;
        switch (context.type) {
            case "send":
            case "ping":
                // Immediately ack the message
                local response = { type = "ack", id = id, time = Bullwinkle_Session._timestamp() };
                if (!_handlers.receive) {
                    response.type = "nack";
                }
                _partner.send(BULLWINKLE, response);
                
                // Then handed on to the callback
                if (context.type == "send" && _handlers.receive && _is_unique(context)) {
                    try {
                        // Prepare a reply function for shipping a reply back to the sender
                        context.reply <- function (reply) {
                            local response = { type = "reply", id = id, time = Bullwinkle_Session._timestamp() };
                            response.reply <- reply;
                            _partner.send(BULLWINKLE, response);
                        }.bindenv(this);
                        
                        // Fire the callback
                        _handlers.receive(context);
                    } catch (e) {
                        // An unhandled exception should be sent back to the sender
                        local response = { type = "exception", id = id, time = Bullwinkle_Session._timestamp() };
                        response.exception <- e;
                        _partner.send(BULLWINKLE, response);
                    }
                }
                break;
                
            case "nack":
            case "ack":
                // Pass this packet to the session handler
                if (id in _sessions) {
                    _sessions[id]._ack(context);
                }
                break;

            case "reply":
                // This is a reply for an sent message
                if (id in _sessions) {
                    _sessions[id]._reply(context);
                }
                break;
                
            case "exception":
                // Pass this packet to the session handler
                if (id in _sessions) {
                    _sessions[id]._exception(context);
                }
                break;

            default:
                throw "Unknown context type: " + context.type;
                
        } 
    }
    
}

// -----------------------------------------------------------------------------
class Bullwinkle_Session
{
    _handlers = null;
    _parent = null;
    _context = null;
    _timer = null;
    _timeout = null;
    _acked = false;
    _retries = null;

    // .........................................................................
    constructor(parent, id, timeout = 0, retries = 1) {
        _handlers = { ack = null, reply = null, timeout = null, exception = null };
        _parent = parent;
        _timeout = timeout;
        _retries = retries;
        _context = { time = _timestamp(), id = id };
    }
    
    // .........................................................................
    function onack(callback) {
        _handlers.ack = callback;
        return this;
    }
    
    // .........................................................................
    function onreply(callback) {
        _handlers.reply = callback;
        return this;
    }
    
    // .........................................................................
    function ontimeout(callback) {
        _handlers.timeout = callback;
        return this;
    }
    
    // .........................................................................
    function onexception(callback) {
        _handlers.exception = callback;
        return this;
    }
    
    // .........................................................................
    function send(type = "resend", command = null, params = null) {

        _retries--;
        
        if (type != "resend") {
            _context.type <- type;
            _context.command <- command;
            _context.params <- params;
        }
        
        if (_timeout > 0) _set_timer(_timeout);
        _parent._partner.send(BULLWINKLE, _context);
        
        return this;
    }
    
    // .........................................................................
    function _set_timer(timeout) {
        
        // Stop any current timers
        _stop_timer();
        
        // Start a fresh timer
        _timer = imp.wakeup(_timeout, _ontimeout.bindenv(this));
    }
        
    // .........................................................................
    function _ontimeout() {
            
        // Close down the timer and session
        _timer = null;
        
        if (!_acked && _retries > 0) {
            // Retry is required
            send();
        } else {
            // Close off this dead session
            _parent._end_session(_context.id)
            
            // If we are still waiting for an ack, throw a callback
            if (!_acked) {
                _context.latency <- _timestamp_diff(_context.time, _timestamp());
                if (_handlers.timeout) {
                    // Send the context to the session timeout handler
                    _handlers.timeout(_context);
                } else if (_parent._handlers.timeout) {
                    // Send the context to the global timeout handler
                    _parent._handlers.timeout(_context);
                }
            }
        }
    }
    
    // .........................................................................
    function _stop_timer() {
        if (_timer) imp.cancelwakeup(_timer);
        _timer = null;
    }
    
    // .........................................................................
    function _timestamp() {
        if (Bullwinkle.is_agent()) {
            local d = date();
            return format("%d.%06d", d.time, d.usec);
        } else {
            local d = math.abs(hardware.micros());
            return format("%d.%06d", d/1000000, d%1000000);
        }
    }

    
    // .........................................................................
    function _timestamp_diff(ts0, ts1) {
        // server.log(ts0 + " > " + ts1)
        local t0 = split(ts0, ".");
        local t1 = split(ts1, ".");
        local diff = (t1[0].tointeger() - t0[0].tointeger()) + (t1[1].tointeger() - t0[1].tointeger()) / 1000000.0;
        return math.fabs(diff);
    }


    // .........................................................................
    function _ack(context) {
        // Restart the timeout timer
        _set_timer(_timeout);
        
        // Calculate the round trip latency and mark the session as acked
        _context.latency <- _timestamp_diff(_context.time, _timestamp());
        _acked = true;
        
        // Fire a callback
        if (_handlers.ack) {
            _handlers.ack(_context);
        }

    }

        
    // .........................................................................
    function _reply(context) {
        // We can stop the timeout timer now
        _stop_timer();
        
        // Fire a callback
        if (_handlers.reply) {
            _context.reply <- context.reply;
            _handlers.reply(_context);
        }
        
        // Remove the history of this message
        _parent._end_session(_context.id)
    }
    
    
    // .........................................................................
    function _exception(context) {
        // We can stop the timeout timer now
        _stop_timer();
        
        // Fire a callback
        if (_handlers.exception) {
            _context.exception <- context.exception;
            _handlers.exception(_context);
        }
        
        // Remove the history of this message
        _parent._end_session(_context.id)
    }
        
}


// ==============================[ Sample code ]================================

bull <- Bullwinkle();
bull.set_timeout(5);
bull.set_retries(3);

bull.ontimeout(function (context) {
    server.log("Global timeout sending " + context.type);
})

bull.onreceive(function (context) {
    server.log("Received " + context.command + ", sending reply.");
    imp.wakeup(1, function() {
        context.reply("Cool!")
    })
})

function ping() {
    imp.wakeup(10, ping)
    bull.ping()
        .onack(function (context) {
            server.log(format("Ping took %d ms, %d bytes of free memory.", 1000 * context.latency, imp.getmemoryfree()))
        })
        .ontimeout(function(context) {
            server.log("Ping timeout");
        });
}
ping();

bull.send("command")
    .onreply(function(context) {
        server.log("Received reply from command '" + context.command + "': " + context.reply);
    })
    .ontimeout(function(context) {
        server.log("Received reply from command '" + context.command + "' after " + context.latency + "s");
    })
    .onexception(function(context) {
        server.log("Received exception from command '" + context.command + ": " + context.exception);
    })

