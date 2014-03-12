// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const PROWL_KEY = "yourprowlkey";
const PROWL_URL = "https://api.prowlapp.com/publicapi";
const PROWL_APP = "Application title";

function sendToProwl(short="Short description", long="Longer description") {
    local data = { 
        apikey=PROWL_KEY, 
        url=http.agenturl(), 
        application=PROWL_APP, 
        event=short, 
        description=long
    };
    http.post(PROWL_URL+"/add?" + http.urlencode(data), {}, "").sendasync(function(res) {
        if (res.statuscode != 200) {
            server.error("Prowl failed: " + res.statuscode + " => " + res.body);
        }
    })
}

// Example
sendToProwl("Oh Snaps!", "This is a message from your Electric Imp");
