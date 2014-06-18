class PubNub {
    _pubNubBase = "https://pubsub.pubnub.com";
    
    _publishKey = null;
    _subscribeKey = null;
    _secretKey = null;
    
    _uuid = null
    
    constructor(publishKey, subscribeKey, secretKey, uuid = null) {
        this._publishKey = publishKey;
        this._subscribeKey = subscribeKey;
        this._secretKey = secretKey;
        
        if (uuid == null) uuid = split(http.agenturl(), "/").top();
        this._uuid = uuid;
    }
    
    function publish(channel, data, callback = null) {
        local url = format("%s/publish/%s/%s/%s/%s/%s/%s?uuid=%s", _pubNubBase, _publishKey, _subscribeKey, _secretKey, channel, "0", http.jsonencode(data), _uuid);
        
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                } catch (ex) {
                    err = ex;
                }
            }
            
            // callback
            if (callback != null) callback(err, data);
            else _defaultPublishCallback(err, data);
        }.bindenv(this));
    }
    
    function subscribe(channel, callback, tt = 0) {
        local url = format("%s/subscribe/%s/%s/0/%s?uuid=%s", _pubNubBase, _subscribeKey, channel, tt.tostring(), _uuid);
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    if (data.len() == 2) {
                        this.subscribe(channel, callback, data[1]);
                    }
                } catch (ex) {
                    err = ex;
                }
            }
            
            // callback
            callback(err, data);
            
        }.bindenv(this));
    }
    
    /******************** PRIVATE FUNCTIONS (DO NOT CALL) ********************/
    function _defaultPublishCallback(err, data) {
        if (err) {
            server.log(err);
            return;
        }
        if (data[0] != 1) {
            server.log("Uh oh - " + data[1]);
        } else {
            server.log("Success - " + data[2]);
        }
    }
}

pubNub <- PubNub("demo", "demo", "0");

pubNub.subscribe("hello_world", function(err, data) {
    if (err != null) {
        server.log(err);
        return;
    }
    
    foreach(d in data[0]) {
        server.log(d);
    }
});

// wait a second (for requests to open, then send some data)
imp.wakeup(1.0,function() { 
    pubNub.publish("hello_world", {"foo": "bar"});
    pubNub.publish("hello_world", "test test test");
});

