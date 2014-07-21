// Weather Underground Forecast Agent
// Copyright (C) 2014 Electric Imp, Inc.

server.log("Weather Agent Running");

local AGENTRELOADED = true;

const UPDATEINTERVAL = 900; // fetch forecast every 10 minutes

updatehandle <- null;

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/

const WUNDERGROUND_KEY = "YOUR KEY HERE";
const WUNDERGROUND_URL = "http://api.wunderground.com/api/";
const ZIPCODE = "94041";

// calculate the color that corresponds to a given temperature
// assumes temperature in celsius

function tempToColor(temp) 
{
    local color = {};
    
    // scale red proportionally to temp, from 20 to 40 C
    
    color.red <- (255.0/20.0) * (temp - 20.0);
    if (color.red < 0) { color.red = 0; }
    if (color.red > 255) { color.red = 255; }
    
    // scale green proportionally to temp from 1 to 20, inversely from 20 to 39
    color.green <- 255 - ((255.0 / 19.0) * (math.abs(temp - 19.0)));
    if (color.green < 0) { color.green = 0; }
    if (color.green > 255) { color.green = 255; }

    // scale blue inversely to temp, from 0 to 20 C
    
    color.blue <- 255 - (255.0/20.0) * (temp);
    if (color.blue < 0) { color.blue = 0; }   
    if (color.blue > 255) { color.blue = 255; }
    
    server.log(format("Temp: %0.2f -> [%d,%d,%d]", temp, color.red, color.green, color.blue));
    
    return color;
}

// Use weatherunderground to get the conditions, latitude and longitude given a location string.

function getConditions() 
{
    // prevent double-scheduled updates (in case both device and agent restart at some point)
    
    if (updatehandle) { imp.cancelwakeup(updatehandle); }
    
    // schedule next update
    
    updatehandle = imp.wakeup(UPDATEINTERVAL, getConditions);
    
    // request the current conditions for our zipcode
    
    local url = format("%s/%s/conditions/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, ZIPCODE);
    local res = http.get(url, {}).sendsync();
    
    if (res.statuscode != 200) 
    {
        server.log("Wunderground error: " + res.statuscode + " => " + res.body);
    } 
    else 
    {
        // response parsing is in a try-catch to prevent runtime errors if our request does not return valid JSON
        
        try 
        {
            local response = http.jsondecode(res.body);
            local weather = response.current_observation;
            // calculate the color that corresponds to the current temperature, and send it to the device
            device.send("setcolor", tempToColor(weather.temp_c));
            server.log(format("Current Temperature for %s: %0.2f",ZIPCODE,weather.temp_c));
        } 
        catch (e) 
        {
            throw "Wunderground error: " + e;
        }
    }
}

function test() 
{
    for (local i = 0.0; i < 40.0; i++) 
    {
        device.send("setcolor",tempToColor(i));
        imp.sleep(0.25);
    }
}

http.onrequest(function(req, resp) {
    resp.header("Access-Control-Allow-Origin", "*");
    resp.send(200, "Electric Imp Weather Agent");
});

// handle device restarts while agent carries on running

device.on("start", function(val) {
    getConditions();
    AGENTRELOADED = false;
});

// handle agent restarts while device carries on running

imp.wakeup(5, function() {
    if (AGENTRELOADED) { getConditions(); }
});

