// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Weather Underground Forecast Agent
// Create your key API here: http://www.wunderground.com/weather/api/

class Wunderground {

    _apiKey = null;
    _location = null;
    _baseUrl = null;
    
    /*
     * apiKey - your Wunderground API Key
     * Location can be any of the following: 
     *  Country/City ("Australia/Sydney") 
     *  US State/City ("CA/Los_Altos") 
     *  Lat,Lon ("37.776289,-122.395234")  
     *  Zipcode ("94022") 
     *  Airport code ("SFO")
     */
    constructor(apiKey, location, baseUrl = "http://api.wunderground.com/api/") {
        _apiKey = apiKey;
        _location = location;
        _baseUrl = baseUrl;
    }
    
    /*
     * Returns the astonomical data (sunrise/sunset) for your location.
     */
    function getSunriseSunset(cb = null) {
        local url = _buildUrl("astronomy");
        if (cb == null) {
            local resp = _commit(url);
            if (resp.statuscode != 200) {
                server.error(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                return null;
            } else {
                return _parseSunriseSunsetResponse(resp.body);
            }
        } else {
            request.sendasync(function(resp) {
                if (resp.statuscode != 200) {
                    server.log(format("Error fetching sunrise/sunset data: %i - %s", resp.statuscode, resp.body));
                    cb(null);
                } else {
                    cb(_parseSunriseSunsetResponse(resp.body));
                }
            }.bindenv(this));
        }
    }
    

    /*
     * Returns the current weather conditions at your location.
     */
    function getConditions(cb = null) {
        local url = _buildUrl("conditions");
        if (cb == null) {
            local resp = _commit(url);
            if (resp.statuscode != 200) {
                server.error(format("Error fetching conditions: %i - %s", resp.statuscode, resp.body));
                return null;
            } else {
                return http.jsondecode(resp.body);
            }
        } else {
            return _commit(url, function(resp) {
                if (resp.statuscode != 200) {
                    server.error(format("Error fetching conditions: %i - %s", resp.statuscode, resp.body));
                    cb(null);
                } else {
                    cb(http.jsondecode(resp.body));
                }
            }.bindenv(this));
        }
    }
    
    /***** Private Function - Do Not Call *****/
    function _buildUrl(method) {
        return format("%s/%s/%s/q/%s.json", _baseUrl, _apiKey, method, _encode(_location));
    }

    function _encode(str) {
        return http.urlencode({ s = str }).slice(2);
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
            server.error(format("Error Parsing Response - %s", ex));
            return null;
        }
    }
    
    /*
     * Perform the provided HTTP request. Retry after a delay if the result is 429 (throttle).
     */
    function _commit(url, cb = null) {
        // make the request
        local request = http.get(url);
        if (cb) {
            return request.sendasync(function(res) {
                if (res.statuscode == 429) {
                    imp.wakeup(1, function() {
                        _commit(url, cb);
                    }.bindenv(this))
                } else {
                    cb(res);
                }
            }.bindenv(this));
        } else {
            local res = request.sendsync();
            if (res.statuscode == 429) {
                imp.sleep(1);
                return _commit(url, cb);
            } else {
                return res;
            }
        }
    }


}
