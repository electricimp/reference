// -----------------------------------------------------------------------------
class Firebase {
    // General
    db = null;              // the name of your firebase
    auth = null;            // Auth key (if auth is enabled)
    baseUrl = null;         // Firebase base url
    prefixUrl = "";         // Prefix added to all url paths (after the baseUrl and before the Path)
    
    // For REST calls:
    defaultHeaders = { "Content-Type": "application/json" };
    
    // For Streaming:
    streamingHeaders = { "accept": "text/event-stream" };
    streamingRequest = null;    // The request object of the streaming request
    data = null;                // Current snapshot of what we're streaming
    callbacks = null;           // List of callbacks for streaming request
    keepAliveTimer = null;

    /***************************************************************************
     * Constructor
     * Returns: FirebaseStream object
     * Parameters:
     *      baseURL - the base URL to your Firebase (https://username.firebaseio.com)
     *      auth - the auth token for your Firebase
     **************************************************************************/
    constructor(_db, _auth) {
        const KEEP_ALIVE = 120;
        
        db = _db;
        baseUrl = "https://" + db + ".firebaseio.com";
        auth = _auth;
        data = {}; 
        callbacks = {};
    }
    
    /***************************************************************************
     * Attempts to open a stream
     * Returns: 
     *      false - if a stream is already open
     *      true -  otherwise
     * Parameters:
     *      path - the path of the node we're listending to (without .json)
     *      autoReconnect - set to false to close stream after first timeout
     *      onError - custom error handler for streaming API 
     **************************************************************************/
    function stream(path = "", autoReconnect = true, onError = null) {
        // if we already have a stream open, don't open a new one
        if (isStreaming()) return false;
         
        if (onError == null) onError = _defaultErrorHandler.bindenv(this);
        streamingRequest = http.get(_buildUrl(path), streamingHeaders);
        streamingRequest.sendasync(

            function(resp) {
                
                // server.log("Stream Closed (" + resp.statuscode + ": " + resp.body +")");
                streamingRequest = null;

                // if we timed out and have autoreconnect set
                if (resp.statuscode == 28 && autoReconnect) {
                    stream(path, autoReconnect, onError);
                    return;
                }
                if (resp.statuscode == 307) {
                    if("location" in resp.headers) {
                        // set new location
                        local location = resp.headers["location"];
                        local p = location.find(".firebaseio.com")+16;
                        baseUrl = location.slice(0, p);
                        stream(path, autoReconnect, onError);
                        return;
                    }
                }
            }.bindenv(this),
            
            function(messageString) {
                // server.log("MessageString: " + messageString);
                local message = _parseEventMessage(messageString);
                if (message) {
                    // Update the internal cache
                    _updateCache(message);
                    
                    foreach (path,callback in callbacks) {
                        // Check out every callback
                        local change = _getDataFromPath(path, message.path, data);
                        if (change == null) continue;

                        // Call the matched callback
                        callback(change.path, change.data);
                    }
                }
            }.bindenv(this)
            
        );
        
        // Tickle the keepalive timer
        if (keepAliveTimer) imp.cancelwakeup(keepAliveTimer);
        keepAliveTimer = imp.wakeup(KEEP_ALIVE, _keepAliveExpired.bindenv(this))
        
        // Return true if we opened the stream
        return true;
    }
    

    /***************************************************************************
     * Returns whether or not there is currently a stream open
     * Returns: 
     *      true - streaming request is currently open
     *      false - otherwise
     **************************************************************************/
    function isStreaming() {
        return (streamingRequest != null);
    }
    
    /***************************************************************************
     * Closes the stream (if there is one open)
     **************************************************************************/
    function closeStream() {
        if (streamingRequest) { 
            streamingRequest.cancel();
            streamingRequest = null;
        }
    }
    
    /***************************************************************************
     * Registers a callback for when data in a particular path is changed.
     * If a handler for a particular path is not defined, data will change,
     * but no handler will be called
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're listending to (without .json)
     *      callback - a callback function with two parameters (id, data) to be 
     *                 executed when the data at path changes
     **************************************************************************/
    function on(path, callback) {
        if (path.len() > 0 && path.slice(0, 1) != "/") path = "/" + path;
        if (path.len() > 1 && path.slice(-1) == "/") path = path.slice(0, -1);
        callbacks[path] <- callback;
    }
    
    /***************************************************************************
     * Reads a path from the internal cache. Really handy to use in an .on() handler
     **************************************************************************/
    function fromCache(path) {
        local _data = data;
        foreach (step in split(path, "/")) {
            if (step == "") continue;
            if (step in _data) _data = _data[step];
            else throw "Path not found";
        }
        return _data;
    }
     
    /***************************************************************************
     * Reads data from the specified path, and executes the callback handler
     * once complete.
     *
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're reading
     *      callback - a callback function with one parameter (data) to be 
     *                 executed once the data is read
     **************************************************************************/    
     function read(path, callback = null) {
        http.get(_buildUrl(path), defaultHeaders).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.error("Read: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local data = null;
                try {
                    data = http.jsondecode(res.body);
                } catch (err) {
                    server.error("Read: JSON Error: " + res.body);
                    return;
                }
                if (callback) callback(data);
            }
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Pushes data to a path (performs a POST)
     * This method should be used when you're adding an item to a list.
     * 
     * NOTE: This function does NOT update firebase.data
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're pushing to
     *      data     - the data we're pushing
     **************************************************************************/    
    function push(path, data, priority = null, callback = null) {
        if (priority != null && typeof data == "table") data[".priority"] <- priority;
        http.post(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.error("Push: Firebase responded " + res.statuscode + " to changes to " + path)
            }
            if (callback) callback(res);
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Writes data to a path (performs a PUT)
     * This is generally the function you want to use
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're writing to
     *      data     - the data we're writing
     **************************************************************************/    
    function write(path, data, callback = null) {
        http.put(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.error("Write: Firebase responded " + res.statuscode + " to changes to " + path)
            }
            if (callback) callback(res);
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Updates a particular path (performs a PATCH)
     * This method should be used when you want to do a non-destructive write
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're patching
     *      data     - the data we're patching
     **************************************************************************/    
    function update(path, data, callback = null) {
        http.request("PATCH", _buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.error("Update: Firebase responded " + res.statuscode + " to changes to " + path)
            }
            if (callback) callback(res);
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Deletes the data at the specific node (performs a DELETE)
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're deleting
     **************************************************************************/        
    function remove(path, callback = null) {
        http.httpdelete(_buildUrl(path), defaultHeaders).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.error("Delete: Firebase responded " + res.statuscode + " to changes to " + path)
            }
            if (callback) callback(res);
        });
    }
    
    /************ Private Functions (DO NOT CALL FUNCTIONS BELOW) ************/
    // Builds a url to send a request to
    function _buildUrl(path) {
        // Normalise the /'s
        // baseURL = <baseURL>
        // prefixUrl = <prefixURL>/
        // path = <path>
        if (baseUrl.len() > 0 && baseUrl[baseUrl.len()-1] == '/') baseUrl = baseUrl.slice(0, -1);
        if (prefixUrl.len() > 0 && prefixUrl[0] == '/') prefixUrl = prefixUrl.slice(1);
        if (prefixUrl.len() > 0 && prefixUrl[prefixUrl.len()-1] != '/') prefixUrl += "/";
        if (path.len() > 0 && path[0] == '/') path = path.slice(1);
        
        local url = baseUrl + "/" + prefixUrl + path + ".json";
        url += "?ns=" + db;
        if (auth != null) url = url + "&auth=" + auth;
        
        return url;
    }

    // Default error handler
    function _defaultErrorHandler(errors) {
        foreach(error in errors) {
            server.error("ERROR " + error.code + ": " + error.message);
        }
    }

    // parses event messages
    function _parseEventMessage(text) {
        // split message into parts
        local lines = split(text, "\n");
        if (lines.len() < 2) return null;
        
        // Check for error conditions
        if (lines.len() == 3 && lines[0] == "{" && lines[2] == "}") {
            local error = http.jsondecode(text);
            server.error("Error parsing Firebase event message: " + error.error);
            return null;
        }

        // Tickle the keep alive timer
        if (keepAliveTimer) imp.cancelwakeup(keepAliveTimer);
        keepAliveTimer = imp.wakeup(KEEP_ALIVE, _keepAliveExpired.bindenv(this))
        
        // get the event
        local eventLine = lines[0];
        local event = eventLine.slice(7);
        if(event.tolower() == "keep-alive") return null;
        
        // get the data
        local dataLine = lines[1];
        local dataString = dataLine.slice(6);
    
        // pull interesting bits out of the data
        local d = http.jsondecode(dataString);
        local path = d.path;
        local messageData = d.data;
        
        // return a useful object
        return { "event": event, "path": path, "data": messageData };
    }

    // Updates the local cache
    function _updateCache(message) {
        // base case - refresh everything
        if (message.event == "put" && message.path == "/") {
            data = (message.data == null) ? {} : message.data;
            return data
        }

        local pathParts = split(message.path, "/");
        local key = pathParts.len() > 0 ? pathParts[pathParts.len()-1] : null;

        local currentData = data;
        local parent = data;

        // Walk down the tree following the path
        foreach (part in pathParts) {
            parent = currentData;
            
            if (!(part in currentData)) {
                currentData[part] <- {};
            }
            currentData = currentData[part];
        }
        
        // Make the changes to the found branch
        if (message.event == "put") {
            if (message.data == null) {
                if (key != null) {
                    delete parent[key];
                } else {
                    data = {};
                }
            } else {
                if (key != null) parent[key] <- message.data;
                else data[key] <- message.data;
            }
        } else if (message.event == "patch") {
            foreach(k,v in message.data) {
                if (key != null) parent[key][k] <- v
                else data[k] <- v;
            }
        }
        
        // Now clean up the tree, removing any orphans
        _cleanTree(data);
    }

    // Cleans the tree by deleting any empty nodes
    function _cleanTree(branch) {
        foreach (k,subbranch in branch) {
            if (typeof subbranch == "array" || typeof subbranch == "table") {
                _cleanTree(subbranch)
                if (subbranch.len() == 0) delete branch[k];
            }
        }
    }

    // Steps through a path to get the contents of the table at that point
    function _getDataFromPath(c_path, m_path, m_data) {
        
        // Make sure we are on the right branch
        if (m_path.len() > c_path.len() && m_path.find(c_path) != 0) return null;
            
        // Walk to the base of the callback path
        local new_data = m_data;
        foreach (step in split(c_path, "/")) {
            if (step == "") continue;
            if (step in new_data) {
                new_data = new_data[step];
            } else {
                new_data = null;
                break;
            }
        }
        
        // Find the data at the modified branch but only one step deep at max
        local changed_data = new_data;
        local new_path = "";
        if (m_path.len() > c_path.len()) {
            // Only a subbranch has changed, pick the subbranch that has changed
            local new_m_path = m_path.slice(c_path.len())
            foreach (step in split(new_m_path, "/")) {
                if (step == "") continue;
                new_path = step;
                if (step in changed_data) {
                    changed_data = changed_data[step];
                } else {
                    changed_data = null;
                }
                break;
            }
        }

        // Clean the path a bit
        local slashes = 0;
        for (local i = 0; i < new_path.len(); i++) {
            if (new_path[i] == '/') slashes++;
            else break;
        }
        if (slashes > 0) new_path = new_path.slice(slashes);

        return { path = new_path, data = changed_data };
    }
    
    // No keep alive has been seen for a while, lets reconnect
    function _keepAliveExpired() {
        closeStream();
    }
    
}


const FIREBASENAME = "your firebase";
const FIREBASESECRET = "your secret or token";

firebase <- Firebase(FIREBASENAME, FIREBASESECRET);
