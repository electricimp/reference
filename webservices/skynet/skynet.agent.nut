/******************** Library Code ********************/
SkyNet <- {
    baseUrl = "http://skynet.im"
}

class SkyNet.Client {
    _token = null;
    
    constructor (token) {
        this._token = token;
    }
    
    function GetStatus() {
        local statusUrl = format("%s/status", SkyNet.baseUrl);
        local resp = http.get(statusUrl).sendsync();
        if (resp.statuscode != 200) {
            server.log("ERROR: Could not get system status (%s) - %s", resp.statuscode, resp.body);
            return false;
        } else {
            local data = http.jsondecode(resp.body);
            return ("skynet" in data && data.skynet == "online");
        }
    }
    
    function CreateDevice(uuid, properties = {}) {
        properties["uuid"] <- uuid;
        if (!("token" in properties)) properties["token"] <- _token;

        // set some default properties
        if (!("platform" in properties)) properties["platform"] <- "electric imp";
        
        local url = format("%s/devices", SkyNet.baseUrl);
        
        local resp = http.post(url, {}, http.urlencode(properties)).sendsync();
        if (resp.statuscode == 200) {
            local deviceData = http.jsondecode(resp.body);
            return SkyNet.Device(deviceData);
        } 
        
        server.log(format("ERROR: Could not create device (%s) - %s", resp.statuscode.tostring(), resp.body));
        return null;
    }
    
    function GetDevice(uuid, token = null) {
        if (token == null) token = _token;
        local deviceUrl = format("%s/devices/%s", SkyNet.baseUrl, uuid);
        local headers = {
            "skynet_auth_uuid": uuid,
            "skynet_auth_token": token
        };
        
        local deviceResp = http.get(deviceUrl, headers).sendsync();
        if (deviceResp.statuscode != 200) {
            server.log(format("ERROR: Could not get device (%s) - %s", deviceResp.statuscode.tostring(), deviceResp.body));
            return null;
        }
        
        local deviceData = http.jsondecode(deviceResp.body);
        if ("error" in deviceData) {
            server.log(format("ERROR: Could not get device. %s", deviceData.error.message));
            return null;
        }

        if (!("devices" in deviceData && deviceData.devices.len() == 1)) {
            server.log("ERROR: Could not get device. Unexpected device data");
            return null;
        } 
        
        return SkyNet.Device(deviceData.devices[0], token);
    }
    
    function DeleteDevice(uuid, token = null) {
        if (token == null) token = _token;
        local deleteUrl = format("%s/devices/%s", SkyNet.baseUrl, uuid);
        local headers = { "skynet_auth_uuid": uuid, "skynet_auth_token": token };
        local resp = http.httpdelete(deleteUrl, headers).sendsync();
        if (resp.statuscode == 200) return true;
        
        server.log(format("ERROR: Could not delete device (%s) - %s", resp.statuscode.tostring(), resp.body));
        return false;
    }
}

class SkyNet.Device {
    _properties = null;
    
    // streaming
    _onDataCallback = null;
    _streamingRequest = null;
    
    constructor(properties, token = null) {
        _properties = properties;
        if (token != null && !("token" in _properties)) _properties["token"] <- token;
    }
    
    function serialize() {
        return http.jsonencode(_properties);
    }
    
    function UpdateProperties(properties) {
        local url = format("%s/devices/%s", SkyNet.baseUrl, _properties.uuid);
        local headers = { 
            "Content-Type": "application/json",
            "skynet_auth_uuid": _properties.uuid,
            "skynet_auth_token": _properties.token
        };
        
        local resp = http.put(url, headers, http.jsonencode(properties)).sendsync();
        
        if (resp.statuscode != 200) {
            server.log(format("ERROR: Could not update device (%s) - %s", resp.statuscode.tostring(), resp.body));
            return;
        }
        
        local data = http.jsondecode(resp.body);
        if ("error" in data) {
            server.log(format("ERROR: Could not update device - %s", data.error.message));
            return;
        }
        
        // if everything worked, update properties
        foreach(k,v in data) {
            if (k == "fromUuid" || k == "eventCode") continue;
            
            if (v == null) {
                if (k in _properties) delete _properties[k];
            } else {
                if (k in _properties) _properties[k] = v;
                else _properties[k] <- v;
            }
        }
    }
    
    function Push(data) {
        local url = format("%s/data/%s", SkyNet.baseUrl,  _properties.uuid);
        local headers = { 
            "Content-Type": "application/json",
            "skynet_auth_uuid": _properties.uuid, 
            "skynet_auth_token": _properties.token
        };
        
        local resp = http.post(url, headers, http.jsonencode(data)).sendsync();
        if (resp.statuscode != 200) {
            server.log(format("ERROR: Could not post data (%s) - %s", resp.statuscode.tostring(), resp.body));
            return;
        }
        
        local data = http.jsondecode(resp.body);
        if ("error" in data) {
            server.log(format("ERROR: Could not post data - %s", data.error.message));
            return;
        }

    }
    
    function GetData() {
        local url = format("%s/data/%s", SkyNet.baseUrl, _properties.uuid);
        local headers = {
            "skynet_auth_uuid": _properties.uuid,
            "skynet_auth_token": _properties.token
        };
        
        local resp = http.get(url, headers).sendsync();
        
        if (resp.statuscode != 200) {
            server.log(format("ERROR: Could not get data (%s) - %s", resp.statuscode.tostring(), resp.body));
            return null;
        }
        
        local data = http.jsondecode(resp.body);
        if ("error" in data) {
            server.log(format("ERROR: Could not get data. %s", data.error.message));
            return null;
        }

        return data;
    }
    
    function onData(cb) {
        _onDataCallback = cb;
    }
    
    function StreamData(autoReconnect = true, streamingRetryTimeout = 10.0) {
        if (_streamingRequest != null) {
            _streamingRequest.cancel();
            _streamingRequest = null;
        }
        
        local url = format("%s/subscribe/%s", SkyNet.baseUrl, _properties.uuid);
        local headers = {
            "skynet_auth_uuid": _properties.uuid, 
            "skynet_auth_token": _properties.token
        };
        
        server.log("Opening stream..");
        _streamingRequest = http.get(url, headers).sendasync(function(resp) {
            server.log(format("Stream closed (%s - %s)", resp.statuscode.tostring(), resp.body));
            if (autoReconnect) {
                StreamData(true);
            }
        }.bindenv(this), function(data) {
            if (_onDataCallback != null) {
                try {
                    local splitData = split(data, "\n\r")
                    local d = null;
                    if (splitData.len() == 1) d = http.jsondecode(splitData[0]);
                    else d = http.jsondecode(splitData[1])
                    if (!("fromUuid" in d)) {
                        _onDataCallback(d);
                    }
                } catch (ex) {
                    server.log("Error in onData callback: " + ex);
                    server.log("data=" + data);
                }
            }
        }.bindenv(this));
    }
}

/******************** Application Code ********************/
// token are your devices' security - keep it secret
token <- "b9a964a0-f3b9-4974-b2ad-024dae549f5e";
// we automagically generate an uuid by grabbing the last part
// of the agentURL
uuid <- split(http.agenturl(), "/").pop();

// Instantiate the Skynet Client
skynet <- SkyNet.Client(token);

// Check if this device already exists - if it doesn't, create it
device <- skynet.GetDevice(uuid);
if (device == null) {
    device = skynet.CreateDevice(uuid);
}

// setup streaming
device.onData(function(data){ 
    local s = "";
    if ("r" in data && data.r.tointeger() >= 50) {
        s = "high"
    } else {
        s = "low"
    }
    
    server.log(format("Got a %s request (%s)", s, data.r));
});

// start the stream
device.StreamData(true);    //auto-reconnect

//push some random data every 10 seconds
function loop() {
    imp.wakeup(10.0, loop);
    device.Push({ r = math.rand() % 100 });
} loop();
