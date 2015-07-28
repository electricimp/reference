// Weather Underground Forecast Agent
// Copyright (C) 2014 Electric Imp, inc.

class Wunderground {

    static version = [1,0,0];

    static RESP_ERR = "Error fetching data";

    _apiKey = null;
    _baseUrl = "http://api.wunderground.com/api";
    _location = null;

    // Constructor takes two required parameters
     // apiKey - your Wunderground API Key
     // Location can be any of the following:
     //  Country/City ("Australia/Sydney")
     //  US State/City ("CA/Los_Altos")
     //  Lat,Lon ("37.776289,-122.395234")
     //  Zipcode ("94022")
     //  Airport code ("SFO")
    constructor(apiKey, location) {
        this._apiKey = apiKey;
        this._location = location;
    }

    function getLocation() {
        return _location;
    }

    function setLocation(newLocation) {
        _location = newLocation;
    }

    // response object contains - current temp, weather condition, humidity, wind, 'feels like' temp, barametric pressure
    function getConditions(cb) {
        local request = http.get(_buildUrl("conditions"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.current_observation);
            }
        }.bindenv(this));
    }

    function getForecast(cb, extended = false) {
        local endPoint = "forecast";
        if(extended) {
            endPoint = "forecast10day";
        }
        local request = http.get(_buildUrl(endPoint), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.forecast);
            }
        }.bindenv(this));
    }

    function getHourly(cb, extended = false) {
        local endPoint = "hourly";
        if(extended) {
            endPoint = "hourly10day";
        }
        local request = http.get(_buildUrl(endPoint), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.hourly_forecast);
            }
        }.bindenv(this));
    }

    function getYesterday(cb) {
        local request = http.get(_buildUrl("yesterday"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.history);
            }
        }.bindenv(this));
    }

    // Date format YYYYMMDD
    function getHistory(cb, date) {
        local request = http.get(_buildUrl("history_" + date), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.history);
            }
        }.bindenv(this));
    }

    function getAstronomy(cb) {
        local request = http.get(_buildUrl("astronomy"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.moon_phase);
            }
        }.bindenv(this));
    }

    function getAlmanac(cb) {
        local request = http.get(_buildUrl("almanac"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.almanac);
            }
        }.bindenv(this));
    }

    function getGeoLookup(cb) {
        local request = http.get(_buildUrl("geolookup"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.location);
            }
        }.bindenv(this));
    }

    function getCurrentHurricane(cb) {
        local request = http.get(format("%s/%s/currenthurricane/view.json", _baseUrl, _apiKey), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.currenthurricane);
            }
        }.bindenv(this));
    }

    function getTide(cb) {
        local request = http.get(_buildUrl("tide"), {});

        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data.tide);
            }
        }.bindenv(this));
    }

    ////////////////// Private Function - Do Not Call ///////////////////
    function _buildUrl(method) {
        return format("%s/%s/%s/q/%s.json", _baseUrl, _apiKey, method, _location);
    }

}