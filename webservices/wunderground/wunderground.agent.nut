// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Wunderground {

    static version = [1,0,0];

    static RESP_ERR = "Error fetching data.";
    static MULTIPLE_LOCATION_ERR = "Specified location returned multiple results.";

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
        setLocation(location);
    }

    function getLocation() {
        return _location;
    }

    function setLocation(newLocation) {
        // .tostring to handle zip codes, etc passed as numbers
        _location = newLocation.tostring();
    }

    // gets current weather conditions
    function getConditions(cb) {
        local request = http.get(_buildUrl("conditions"), {});
        _sendRequest(request, cb, "current_observation");
    }

    // gets a 3 day (extended = false) or 10 day (extended = true) weather forecast
    function getForecast(cb, extended = false) {
        local endPoint = "forecast";
        if(extended) { endPoint = "forecast10day"; }
        local request = http.get(_buildUrl(endPoint), {});
        _sendRequest(request, cb, "forecast");
    }

    function getExtendedForecast(cb) {
        getForecast(cb, true);
    }

    // gets and hourly forecast (1 day)
    function getHourly(cb) {
        local endPoint = "hourly";
        if(extended) { endPoint = "hourly10day"; }
        local request = http.get(_buildUrl(endPoint), {});
        _sendRequest(request, cb, "hourly_forecast");
    }

    // gets weather data for yesterday
    function getYesterday(cb) {
        local request = http.get(_buildUrl("yesterday"), {});
        _sendRequest(request, cb, "history");
    }

    // gets weather data for specified date (Date format YYYYMMDD)
    function getHistory(date, cb) {
        local request = http.get(_buildUrl("history_" + date), {});
        _sendRequest(request, cb, "history");
    }

    // gets moon, sunset, and sunrise data
    function getAstronomy(cb) {
        local request = http.get(_buildUrl("astronomy"), {});
        _sendRequest(request, cb, "moon_phase");
    }

    // gets normal and record temperature data
    function getAlmanac(cb) {
        local request = http.get(_buildUrl("almanac"), {});
        _sendRequest(request, cb, "almanac");
    }

    // gets nearby weather station locations
    function getGeoLookup(cb) {
        local request = http.get(_buildUrl("geolookup"), {});
        _sendRequest(request, cb, "location");
    }

    // gets information about current hurricanes and tropical storms
    function getCurrentHurricanes(cb) {
        local request = http.get(format("%s/%s/currenthurricane/view.json", _baseUrl, _apiKey), {});
        _sendRequest(request, cb, "currenthurricane");
    }

    // gets tidal information
    function getTides(cb) {
        local request = http.get(_buildUrl("tide"), {});
        _sendRequest(request, cb, "tide");
    }

    ////////////////// Private Functions - Do Not Call ///////////////////
    function _buildUrl(method) {
        return format("%s/%s/%s/q/%s.json", _baseUrl, _apiKey, method, _location);
    }

    function _sendRequest(request, cb, dataKey) {
        request.sendasync(_responseHandlerFactory(cb, dataKey));
    }

    function _responseHandlerFactory(cb, dataKey) {
        return function(resp) {
            local data = {};

            try {
                data = http.jsondecode(resp.body);
            } catch (ex) {
                // If there was an error decoding the data
                cb(ex, resp, null);
                return;
            }

            // If we got a non-200 response (request failed)
            if (resp.statuscode != 200) {
                cb(format("%s: %i", Wunderground.RESP_ERR, resp.statuscode), resp, null);
                return;
            }

            // If an error was returned
            if ("response" in data && "error" in data.response) {
                cb(data.response.error.type, resp, null);
                return;
            }

            // If we got back a list of locations instead of the desired results
            if ("response" in data && "results" in data.response && data.response.results.len() > 1) {
                cb(Wunderground.MULTIPLE_LOCATION_ERR, resp, null);
                return;
            }

            // If everything worked as expected
            cb(null, resp, data[dataKey]);
        };
    }
}
