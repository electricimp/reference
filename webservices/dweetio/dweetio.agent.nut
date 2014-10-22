class DweetIO {
    _baseUrl = "https://dweet.io";
    _streamingRequests = null;
    
    function constructor() {
        _streamingRequests = {};
    }
    
    function dweet(thing, data, callback = null) {
        local url = format("%s/dweet/for/%s", _baseUrl, thing);
        local headers = { 
            "content-type": "application/json" 
        };
        local dataString = http.jsonencode(data);
        
        local req = http.post(url, headers, dataString);
        return _request(req, callback);
    }
    
    function getLatest(thing, callback = null) {
        local url = format("%s/get/latest/dweet/for/%s", _baseUrl, thing);
        local headers = { 
            "content-type": "application/json" 
        };
        
        local req = http.get(url, headers);
        return _request(req, callback);        
    }
    
    function getHistory(thing, callback = null) {
        local url = format("%s/get/dweets/for/%s", _baseUrl, thing);
        local headers = { 
            "content-type": "application/json" 
        };
        
        local req = http.get(url, headers);
        return _request(req, callback);        
    }
    
    function stream(thing, callback) {
        server.log("Opening stream for: " + thing);
        
        local url = format("%s/listen/for/dweets/from/%s", _baseUrl, thing);
        local headers = { 
            "content-type": "application/json" 
        };

        local request = http.get(url, headers);
        if (thing in _streamingRequests) {
            _streamingRequests[thing] = null;
        } else {
            _streamingRequests[thing] <- null;
        }
        _streamingRequests[thing] = request.sendasync(
            
            function(resp) {
                // connection timeout
                if (resp.statuscode == 28 || resp.statuscode == 200) {
                    server.log("Reconnecting...")
                    stream(searchTerms, onTweet, onError);
                } else {
                    server.log("Stream unexpectedly closed: " + resp.statuscode + " - " + resp.body);
                }
            }.bindenv(this),
            
            function(body) {
                local dataLines = split(body, "\n\r");
                if (dataLines.len() != 2) {
                    server.log("Something weird happened...");
                    server.log(body);
                } else {
                    local data = http.jsondecode(dataLines[1]);
                    callback(data);
                }
            }.bindenv(this)
        );
    }
    
    /******************** PRIVATE FUNCTIONS (DO NOT CALL) ********************/
    function _request(req, callback) {
        if (callback == null) {
            return req.sendsync();
        } else {
            return req.sendasync(callback);
        }
    }
}

