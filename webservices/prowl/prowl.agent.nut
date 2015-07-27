// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Prowl {

    static version = [1,0,0];

    _apiKey = null;
    _appName = null;
    _baseUrl = "https://api.prowlapp.com/publicapi";

    constructor(apiKey, appName) {
        this._apiKey = apiKey;
        this._appName = appName;
    }

    function push(event, description, cb = null) {
        local data = {
            "apikey" : _apiKey,
            "url" : http.agenturl(),
            "application" : _appName,
            "event" : event,
            "description": description
        };
        local request = http.post(_baseUrl + "/add?" + http.urlencode(data), {}, "");
        if (cb == null) {
            resp = request.sendsync();
            if (res.statuscode != 200) {
                server.error("Prowl failed: " + res.statuscode + " => " + res.body);
                return false;
            }
            return true;
        } else {
            request.sendasync(cb);
        }
    }
}