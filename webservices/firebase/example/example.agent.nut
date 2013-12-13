const FIREBASE_URL = ""
const FIREBASE_AUTH = ""

const NEWLINE = "\n";

class Firebase {
    // General
    baseUrl = null;             // base url of your Firebase
    auth = null;                // Auth key (if auth is enabled)
    
    // For REST calls:
    defaultHeaders = { "Content-Type": "application/json" };
    
    // For Streaming:
    streamingHeaders = { "accept": "text/event-stream" };
    streamingRequest = null;    // The request object of the streaming request
    data = null;                // Current snapshot of what we're streaming
    callbacks = null;           // List of callbacks for streaming request
    
    /***************************************************************************
     * Constructor
     * Returns: FirebaseStream object
     * Parameters:
     *      baseURL - the base URL to your Firebase (https://username.firebaseio.com)
     *      auth - the auth token for your Firebase
     **************************************************************************/
    constructor(_baseUrl, _auth) {
        this.baseUrl = _baseUrl;
        this.auth = _auth;
        this.data = {}; 
        this.callbacks = {};
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
        if (streamingRequest) return false;
         
        if (onError == null) onError = _defaultErrorHandler.bindenv(this);
        local request = http.get(_buildUrl(path), streamingHeaders);
        this.streamingRequest = request.sendasync(

            function(resp) {
                server.log("Stream Closed (" + resp.statuscode + ": " + resp.body +")");
                // if we timed out and have autoreconnect set
                if (resp.statuscode == 28 && autoReconnect) {
                    stream(path, autoReconnect, onError);
                    return;
                }
                if (resp.statuscode == 307) {
                    if("location" in resp.headers) {
                        // set new location
                        local location = resp.headers["location"];
                        local p = location.find(path);
                        this.baseUrl = location.slice(0, p);

                        stream(path, autoReconnect, onError);
                        return;
                    }
                }
            }.bindenv(this),
            
            function(messageString) {
                //try {
                    server.log("MessageString: " + messageString);
                    local message = _parseEventMessage(messageString);
                    local changedRoot = _setData(message);
                    _findAndExecuteCallback(message.path, changedRoot);
                //} catch(ex) {
                    // if an error occured, invoke error handler
                    //onError([{ message = "Squirrel Error - " + ex, code = -1 }]);
                //}

            }.bindenv(this)
            
        );
        
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
     *      callback - a callback function with one parameter (data) to be 
     *                 executed when the data at path changes
     **************************************************************************/
    function on(path, callback) {
        callbacks[path] <- callback;
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
                server.log("Read: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local data = null;
                try {
                    data = http.jsondecode(res.body);
                } catch (err) {
                    server.log("Read: JSON Error: " + res.body);
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
    function push(path, data) {
        http.post(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.log("Push: Firebase response: " + res.statuscode + " => " + res.body)
            }
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
    function write(path, data) {
        http.put(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.log("Write: Firebase response: " + res.statuscode + " => " + res.body)
            }
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
    function update(path, data) {
        http.request("PATCH", _buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.log("Update: Firebase response: " + res.statuscode + " => " + res.body)
            } 
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
    function remove(path) {
        http.httpdelete(_buildUrl(path), defaultHeaders).sendasync(function(res) {
            if (res.statuscode != 200) {
                server.log("Delete: Firebase response: " + res.statuscode + " => " + res.body)
            }
        });
    }
    
    /************ Private Functions (DO NOT CALL FUNCTIONS BELOW) ************/
    // Builds a url to send a request to
    function _buildUrl(path) {
        local url = this.baseUrl + path + ".json";
        if (auth != null) url = url + "?auth=" + auth;
        return url;
    }

    // Default error handler
    function _defaultErrorHandler(errors) {
        foreach(error in errors) {
            server.log("ERROR " + error.code + ": " + error.message);
        }
    }

    // parses event messages
    function _parseEventMessage(text) {
        // split message into parts
        local lines = split(text, NEWLINE);
        
        // get the event
        local eventLine = lines[0];
        local event = eventLine.slice(7);
        
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

    // Sets data and returns root of changed data
    function _setData(message) {
        // base case - refresh everything
        if (message.event == "put" && message.path =="/") {
            data = (message.data != null) ? message.data : {};
            return data
        }
        
        local pathParts = split(message.path, "/");
        
        local currentData = data;
        local parent = data;
        
        foreach(part in pathParts) {
            parent=currentData;
            
            if (part in currentData) currentData = currentData[part];
            else {
                currentData[part] <- {};
                currentData = currentData[part];
            }
        }
        
        local key = pathParts.len() > 0 ? pathParts[pathParts.len()-1] : null;
        
        if (message.event == "put") {
            if (message.data == null) {
                if (key != null) delete parent[key];
                else data = {};
                return null;
            }
            else {
                if (key != null) parent[key] <- message.data;
                else data[key] <- message.data;
            }
        }
        
        if (message.event == "patch") {
            foreach(k,v in message.data) {
                if (key != null) parent[key][k] <- v
                else data[k] <- v;
            }
        }
        
        return (key != null) ? parent[key] : data;
    }

    // finds and executes a callback after data changes
    function _findAndExecuteCallback(path, callbackData) {
        local pathParts = split(path, "/");
        local key = "";
        for(local i = pathParts.len() - 1; i >= 0; i--) {
            key = "";
            for (local j = 0; j <= i; j++) key = key + "/" + pathParts[j];
            if (key in callbacks || key + "/" in callbacks) break;
        }
        if (key + "/" in callbacks) key = key + "/";
        if (key in callbacks) callbacks[key](callbackData);
    }
}

firebase <- Firebase(FIREBASE_URL, null);

firebase.on("/",function(data) {
    if ("led" in data) device.send("led", data.led.tointeger());
});

firebase.on("/led", function(state) {
    device.send("led", state);
});

firebase.stream("/", true);

firebase.read("/led", function(data) {
    server.log("led: " + data);
})

device.on("toggleLed", function(nullData) {
    local value = 1;
    if ("led" in firebase.data) value = 1 - firebase.data.led.tointeger();
    firebase.write("/led", value);
});
