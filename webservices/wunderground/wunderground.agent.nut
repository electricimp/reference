// Weather Underground Forecast Agent
// Copyright (C) 2014 Electric Imp, inc.

// Wunderground constants
// Create your key here: http://www.wunderground.com/weather/api/
const WUNDERGROUND_KEY = "";

class Wunderground {
    _apiKey = null;
    _baseUrl = "http://api.wunderground.com/api/";
    _location = null;
    
    /***************************************************************************
     * apiKey - your Wunderground API Key
     * Location can be any of the following: 
     *  Country/City ("Australia/Sydney") 
     *  US State/City ("CA/Los_Altos") 
     *  Lat,Lon ("37.776289,-122.395234")  
     *  Zipcode ("94022") 
     *  Airport code ("SFO")
     **************************************************************************/
    constructor(apiKey, location) {
        this._apiKey = apiKey;
        this._location = location;
    }
    
    function getSunriseSunset(cb = null) {
        local request = http.get(_buildUrl("astronomy"), {});
        
        if (cb == null) {
            local resp = request.sendsync();
            if (resp.statuscode != 200) {
                server.log(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                return null;
            } else {
                local data = _parseSunriseSunsetResponse(resp.body);
                return data;
            }
        } else {
            request.sendasync(function(resp) {
                if (resp.statuscode != 200) {
                    server.log(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                } else {
                    local data = _parseSunriseSunsetResponse(resp.body);
                    cb(data);
                }
            }.bindenv(this));
        }
    }
    
    function getConditions(cb = null) {
        local request = http.get(_buildUrl("conditions"), {});
        if (cb == null) {
            local resp = request.sendsync();
            if (resp.statuscode != 200) {
                server.log(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                return null;
            } else {
                local data = http.jsondecode(resp.body);
                return data;
            }
        } else {
            request.sendasync(function(resp) {
                if (resp.statuscode != 200) {
                    server.log(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                } else {
                    local data = http.jsondecode(resp.body)
                    cb(data);
                }
            }.bindenv(this));
        }
    }
    
    /***** Private Function - Do Not Call *****/
    function _buildUrl(method) {
        return format("%s/%s/%s/q/%s.json", _baseUrl, _apiKey, method, _encode(_location));
    }

    function _parseSunriseSunsetResponse(body) {
        try {
            local data = http.jsondecode(body);

            return {
                "sunrise" : data.sun_phase.sunrise,
                "sunset" : data.sun_phase.sunset,
                "now" : data.moon_phase.current_time
            };
        } catch (ex) {
            server.log(format("Error Parsing Response - %s", ex));
            return null;
        }
    }
    
    function _encode(str) {
        return http.urlencode({ s = str }).slice(2);
    }
}

wunderground <- Wunderground(WUNDERGROUND_KEY, "94022");

wunderground.getSunriseSunset(function(data) {
    server.log(format("Sunrise at %s:%s", data.sunrise.hour, data.sunrise.minute));
    server.log(format("Sunset at %s:%s", data.sunset.hour, data.sunset.minute));
});

wunderground.getConditions(function(data) {
    // log everything
    foreach(k, v in data.current_observation) {
        server.log(k + ": " + v);
    }
});
