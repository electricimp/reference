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

    // gets and hourly forecast (1 day if extended = false, 10 day if exteded = true)
    function getHourly(cb, extended = false) {
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

    // gets weatehr data for specified date (Date format YYYYMMDD)
    function getHistory(cb, date) {
        local request = http.get(_buildUrl("history_" + date), {});
        _sendRequest(request, cb, "history");
    }

    // gets moon, sunset, and sunrise data
    function getAstronomy(cb) {
        local request = http.get(_buildUrl("astronomy"), {});
        _sendRequest(request, cb, "moon_phase");
    }

    // gets normal and record high and low temperature data
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
    function getCurrentHurricane(cb) {
        local request = http.get(format("%s/%s/currenthurricane/view.json", _baseUrl, _apiKey), {});
        _sendRequest(request, cb, "currenthurricane");
    }

    // gets tidal information
    function getTide(cb) {
        local request = http.get(_buildUrl("tide"), {});
        _sendRequest(request, cb, "tide");
    }

    ////////////////// Private Functions - Do Not Call ///////////////////
    function _buildUrl(method) {
        return format("%s/%s/%s/q/%s.json", _baseUrl, _apiKey, method, _location);
    }

    function _sendRequest(request, cb, dataKey) {
        request.sendasync(function(resp) {
            local data = http.jsondecode(resp.body);
            if (resp.statuscode != 200) {
                cb(format("%s: %i", RESP_ERR, resp.statuscode), resp, data);
            } else {
                cb(null, resp, data[dataKey]);
            }
        }.bindenv(this));
    }

}