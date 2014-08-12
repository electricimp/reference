/******************** PUBNUB LIBRARY ********************/
// Wrapper Class for PubNub, a publish-subscribe service
// REST documentation for PubNub is at http://www.pubnub.com/http-rest-push-api/
class PubNub {
    _pubNubBase = "https://pubsub.pubnub.com";
    _presenceBase = "https://pubsub.pubnub.com/v2/presence";
    
    _publishKey = null;
    _subscribeKey = null;
    _secretKey = null;
    _uuid = null
    
    // Class ctor. Specify your publish key, subscribe key, secret key, and optional UUID
    // If you do not provide a UUID, the Agent ID will be used
    constructor(publishKey, subscribeKey, secretKey, uuid = null) {
        this._publishKey = publishKey;
        this._subscribeKey = subscribeKey;
        this._secretKey = secretKey;
        
        if (uuid == null) uuid = split(http.agenturl(), "/").top();
        this._uuid = uuid;
    }
    
        
    /******************** PRIVATE FUNCTIONS (DO NOT CALL) *********************/
    function _defaultPublishCallback(err, data) {
        if (err) {
            server.log(err);
            return;
        }
        if (data[0] != 1) {
            server.log("Error while publishing: " + data[1]);
        } else {
            server.log("Published data at " + data[2]);
        }
    }
    
    /******************* PUBLIC MEMBER FUNCTIONS ******************************/
    
    // Publish a message to a channel
    // Input:   channel (string)
    //          data - squirrel object, will be JSON encoded 
    //          callback (optional) - to be called when publish is complete
    //      Callback takes two parameters: 
    //          err - null if successful
    //          data - squirrel object; JSON-decoded response from server
    //              Ex: [ 1, "Sent", "14067353030261382" ]
    //      If no callback is provided, _defaultPublishCallback is used
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
    
    // Subscribe to one or more channels
    // Input:
    //      channels (array) - array of channels to subscribe to
    //      callback (function) - called when new data arrives on any of the subscribed channels
    //          Callback takes three parameters:
    //              err (string) - null on success
    //              result (table) - contains (channel, value) pairs for each message received
    //              timetoken - nanoseconds since UNIX epoch, from PubNub service
    //      timetoken (optional) - callback with any new value since (timetoken)
    // Callback will be called once with result = {} and tt = 0 after first subscribing
    function subscribe(channels, callback, tt = 0) {
        local channellist = "";
        local channelidx = 1;
        foreach (channel in channels) {
            channellist += channel;
            if (channelidx < channels.len()) {
                channellist += ",";
            }
            channelidx++;
        }
        local url = format("%s/subscribe/%s/%s/0/%s?uuid=%s", _pubNubBase, _subscribeKey, channellist, tt.tostring(), _uuid);
        http.get(url).sendasync( function(resp) {
            local err = null;
            local data = null;
            local messages = null;
            local rxchannels = null;
            local tt = null;
            local result = {};
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    messages = data[0];
                    tt = data[1];
                    if (data.len() > 2) {
                        rxchannels = split(data[2],",");
                        local chidx = 0;
                        foreach (ch in rxchannels) {
                            result[ch] <- messages[chidx++]
                        }
                    } else { 
                        if (messages.len() == 0) {
                            // successfully subscribed; no data yet
                        } else  {
                            // no rxchannels, so we have to fall back on the channel we called with
                            result[channels[0]] <- messages[0];
                        } 
                    }
                } catch (ex) {
                    err = ex;
                }
            }
            
            // re-start polling loop
            // channels and callback are still in scope because we got here with bindenv
            this.subscribe(channels,callback,tt);
            // callback
            callback(err, result, tt);
        }.bindenv(this));
    }
    
    // Get historical data from a channel
    // Input:
    //      channel (string)
    //      limit - max number of historical messages to receive
    //      callback - called on response from PubNub, takes two parameters:
    //          err - null on success
    //          data - array of historical messages
    function history(channel, limit, callback) {
        local url = format("%s/history/%s/%s/0/%d", _pubNubBase, _subscribeKey, channel, limit);
        
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            // process data
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
            } else {
                data = http.jsondecode(resp.body);
            }
            callback(err, data);
        }.bindenv(this));
    }
    
    // Inform Presence Server that this UUID is leaving a given channel
    // UUID will no longer be returned in results for other presence services (whereNow, hereNow, globalHereNow)
    // Input: 
    //      channel (string)
    // Return: None
    function leave(channel) {
        local url = format("%s/sub_key/%s/channel/%s/leave?uuid=%s",_presenceBase,_subscribeKey,channel,_uuid);
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
            
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
                throw "Error Leaving Channel: "+err;
            }
        });
    }
    
    // Get list of channels that this UUID is currently marked "present" on
    // UUID is "present" on channels to which it is currently subscribed or publishing
    // Input:
    //      callback (function) - called when results are returned, takes two parameters
    //          err - null on success
    //          channels (array) - list of channels for which this UUID is "present"
    function whereNow(callback) {
        local url = format("%s/sub-key/%s/uuid/%s",_presenceBase,_subscribeKey,_uuid);
        http.get(url).sendasync(function(resp) {
            local err = null;
            local data = null;
        
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
                throw err;
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    if (!("channels" in data.payload)) {
                        err = "Channel list not found: "+resp.body;
                        throw err;
                    } 
                    data = data.payload.channels;
                } catch (err) {
                    callback(err,data);
                }
                callback(err,data);
            }
        });
    }
    
    // Get list of UUIds that are currently "present" on this channel
    // UUID is "present" on channels to which it is currently subscribed or publishing
    // Input:
    //      channel (string)
    //      callback (function) - called when results are returned, takes two parameters
    //          err - null on success
    //          result - table with two entries:
    //              occupancy - number of UUIDs present on channel
    //              uuids - array of UUIDs present on channel   
    function hereNow(channel, callback) {
        local url = format("%s/sub-key/%s/channel/%s",_presenceBase,_subscribeKey,channel);
        http.get(url).sendasync(function(resp) {
            //server.log(resp.body);
            local data = null;
            local err = null;
            local result = {};
        
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
                throw err;
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    if (!("uuids" in data)) {
                        err = "UUID list not found: "+resp.body;
                    } 
                    if (!("occupancy" in data)) {
                        err = "Occpancy not found"+resp.body;
                    }
                    result.uuids <- data.uuids;
                    result.occupancy <- data.occupancy;
                } catch (err) {
                    callback(err,result);
                }
                callback(err,result);
            }
        });
    }
    
    // Get list of UUIds that are currently "present" on this channel
    // UUID is "present" on channels to which it is currently subscribed or publishing
    // Input:
    //      channel (string)
    //      callback (function) - called when results are returned, takes two parameters
    //          err - null on success
    //          result - table with two entries:
    //              occupancy - number of UUIDs present on channel
    //              uuids - array of UUIDs present on channel       
    function globalHereNow(callback) {
        local url = format("%s/sub-key/%s",_presenceBase,_subscribeKey);
        http.get(url).sendasync(function(resp) {
            //server.log(resp.body);
            local err = null;
            local data = null;
            local result = {};
        
            if (resp.statuscode != 200) {
                err = format("%i - %s", resp.statuscode, resp.body);
                throw err;
            } else {
                try {        
                    data = http.jsondecode(resp.body);
                    if (!("channels" in data.payload)) {
                        err = "Channel list not found: "+resp.body.payload;
                    } 
                    result = data.payload.channels;
                } catch (err) {
                    callback(err,result);
                }
                callback(err,result);
            }
        });
    }
}

/******************** APPLICATION CODE ********************/
const PUBKEY = "pub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
const SUBKEY = "sub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
const SECRETKEY = "sec-c-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

channelBase <- split(http.agenturl(), "/").pop();
lightLevelChannel <- channelBase + "-lightLevel";
ledStateChannel <- channelBase + "-ledState";

pubnub <- PubNub(PUBKEY, SUBKEY, SECRETKEY);

pubnub.subscribe([ledStateChannel], function(err, result, tt) {
    if(result != null && ledStateChannel in result) {
        try {
            local data = http.jsondecode(result[ledStateChannel]);
            if ("state" in data) {
                device.send("led", data["state"].tointeger());
            }
        } catch(ex) {
            server.log("Error - " + ex);
        }            
    }
});

device.on("light", function(lightlevel) {
    pubnub.publish(lightLevelChannel, { light = lightlevel});
});


