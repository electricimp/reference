// Weather Underground Forecast Agent
// Copyright (C) 2014 Electric Imp, inc.

server.log("Weather Agent Running");
local AGENTRELOADED = true;

const UPDATEINTERVAL = 900; // fetch forecast every 10 minutes
updatehandle <- null;
WEBPAGE <- null;

// Add your own wunderground API Key here. 
// Register for free at http://api.wunderground.com/weather/api/
const WUNDERGROUND_KEY = "YOUR WEATHERUNDERGROUND KEY";
local WUNDERGROUND_URL = "http://api.wunderground.com/api/";
local LOCATIONSTR = "94041";
savedata <- server.load();
if ("locationstr" in savedata) { 
    LOCATIONSTR = savedata.locationstr;
    server.log("Restored Location String: "+LOCATIONSTR);
} 
local LAT = null;
local LON = null;

// this function just assigns a big string to a global. 
// that string happens to be a webpage
// this allows the agent to serve a web UI to the user ;)
// webpage must be stored as a verbatim multiline string, and therefore must not
// contain any double quotes (")
function prepWebpage() {
    WEBPAGE = @"<!DOCTYPE html>
    <html lang='en'>
      <head>
        <meta charset='utf-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <meta name='description' content=''>
        <meta name='author' content=''>
    
        <title>Weather</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAQAAAAAAAoAQAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAgAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAA/4QAAP///wAA0P8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABEREREREREAEAAAAAAAAQACIiIiIiIgACIiIiIiIiIAIiIiIiIiIgAiIiIiIiIiAAIiIiIiIiAAEAACIiIAAwAREQIiIgMzABERECIgMzMAERERAAMzMwAREREDMzMzABERERAzMzAAEREREQAAAQAAAAAAAAAACAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAQAA' rel='icon' type='image/x-icon' />        <link href='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css' rel='stylesheet'>
    
      </head>
      <body>

        <nav id='top' class='navbar navbar-static-top navbar-inverse' role='navigation'>
          <div class='container'>
            <div class='navbar-header'>
              <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='.navbar-ex1-collapse'>
                <span class='sr-only'>Toggle navigation</span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
              </button>
              <a class='navbar-brand'>Weather Dial</a>
            </div>
    
            <!-- Collect the nav links, forms, and other content for toggling -->
            <div class='collapse navbar-collapse navbar-ex1-collapse'>
              <ul class='nav navbar-nav'>
              </ul>
            </div><!-- /.navbar-collapse -->
          </div><!-- /.container -->
        </nav>
        
        <div class='container'>
          <div class='row' style='margin-top: 20px'>
            <div class='col-md-offset-2 col-md-8 well'>
                <div class='row' style = 'margin-top: 20px; margin-bottom: 20px; margin-left:5px; margin-right: 5px;'>
                    <iframe id='forecast_embed' type='text/html' frameborder='0' height='245' width='100%' src='https://forecast.io/embed/#lat=37.38864136&lon=-122.07505798&name=Mountain View, CA'></iframe>
                </div>
                <div class='input-group'>
                    <input type='text' class='form-control' id='newLocation'>
                    <span class='input-group-btn'>
                        <button class='btn btn-default' type='button' onClick='setLocation()'>Set Location</button>
                    </span>
                </div>
            </div>
          </div>
          <hr>
    
          <footer>
            <div class='row'>
              <div class='col-lg-12'>
                <p class='text-center'>Copyright &copy; Electric Imp 2013 &middot; <a href='http://facebook.com/electricimp'>Facebook</a> &middot; <a href='http://twitter.com/electricimp'>Twitter</a></p>
              </div>
            </div>
          </footer>
          
        </div><!-- /.container -->
    
      <!-- javascript -->
      <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js'></script>
      <script src='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js'></script>
      <script>
      
        var setLocationURL = document.URL+'/setLocation';
        var getLocationURL = document.URL+'/getLocation';
        var forecastBaseURL = 'https://forecast.io/embed/#';

        function setLocation() {
            var location = $('#newLocation').val();
            $.ajax({
                type: 'POST', 
                url: setLocationURL,
                data: location,
                success: function(dataString) {
                    var data = $.parseJSON(dataString);
                    console.log(dataString);
                    var p = $('#forecast_embed').parent();
                    $('#forecast_embed').remove();
                    p.prepend('<iframe id=\'forecast_embed\' type=\'text/html\' frameborder=\'0\' height=\'245\' width=\'100%\' src=\'' + forecastBaseURL+'&lat='+data.lat + '&lon='+data.lon+'&name='+data.name + '\'></iframe>');
                    $('#newLocation').val('');
                }
            });
        }
    
        $(document).ready(function() {
            $.ajax({
                type: 'GET',
                url: getLocationURL,
                success: function(dataString) {
                    console.log(dataString);
                    var data = $.parseJSON(dataString);
                    $('#forecast_embed').attr('src', forecastBaseURL+'&lat='+data.lat + '&lon='+data.lon+'&name='+data.name);
                }
            });
        });
    
      </script>
    </body>    
    </html>"
}

// Use weatherunderground to get the conditions, latitude and longitude given a location string.
// Location can be:
//   Country/City ("Australia/Sydney") 
//   US State/City ("CA/Los_Altos")
//   Lat,Lon ("37.776289,-122.395234") 
//   Zipcode ("94022") 
//   Airport code ("SFO")
function getConditions() {
    // prevent double-scheduled updates (in case both device and agent restart at some point)
    if (updatehandle) { imp.cancelwakeup(updatehandle); }
    
    // schedule next update
    updatehandle = imp.wakeup(UPDATEINTERVAL, getConditions);
    
    server.log(format("Agent getting current conditions for %s", LOCATIONSTR));
    // use http.urlencode to URL-safe the human-readable location string, 
    // the use string.split to remove "location=" from the result.
    local safelocationstr = split(http.urlencode({location = LOCATIONSTR}), "=")[1];
    local url = format("%s/%s/conditions/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, safelocationstr);
    server.log(url);
    local res = http.get(url, {}).sendsync();
    
    if (res.statuscode != 200) {
        server.log("Wunderground error: " + res.statuscode + " => " + res.body);
    } else {
        try {
            local response = http.jsondecode(res.body);
            local weather = response.current_observation;
            LAT = weather.observation_location.latitude.tofloat();
            LON = weather.observation_location.longitude.tofloat();
            
            local forecastString = "";
            // Chunk together our forecast into a printable string
            forecastString += ("Forecast for "+weather.display_location.city+", "+weather.display_location.state+" ("+LOCATIONSTR+"): ");
            forecastString += (weather.weather+", ");
            forecastString += ("Temperature "+weather.temp_f+"F, ");
            forecastString += (weather.temp_c+"C, ");
            forecastString += ("Humidity "+weather.relative_humidity+", ");
            forecastString += ("Pressure "+weather.pressure_in+" in. ");
            if (weather.pressure_trend == "+") {
                forecastString += "and rising, ";
            } else if (weather.pressure_trend == "-") {
                forecastString += "and falling, ";
            } else {
                forecastString += "and steady, ";
            }
            forecastString += ("Wind "+weather.wind_mph+". ");
            forecastString += weather.observation_time;
            server.log(forecastString);
            server.log("Sending conditions to device.");
            device.send("seteffect", {conditions = weather.weather, temperature = weather.temp_c});
            server.log("Conditions sent.");    
        } catch (e) {
            server.error("Wunderground error: " + e)
        }
        
    }
}

http.onrequest(function(req, resp) {
    resp.header("Access-Control-Allow-Origin", "*");

    local path = req.path.tolower();    
    server.log("new request to "+path+": "+req.body);

    if (path == "/getlocation" || path == "/getlocation/") {
        if (LAT == null || LON == null) {
            getConditions();
        }
        resp.send(200, http.jsonencode( { "lat":LAT,"lon":LON,"name":LOCATIONSTR } ));
    } else if (path == "/setlocation" || path == "/setlocation/") {
        LOCATIONSTR = req.body;
        getConditions();
        resp.send(200, http.jsonencode( { "lat":LAT,"lon":LON,"name":LOCATIONSTR } ));
        // keep the latest user-set location through agent restarts
        savedata.locationstr <- LOCATIONSTR; 
        server.save(savedata);
    } else {
        resp.send(200, WEBPAGE);
    }
});

// handle device restarts while agent carries on running
device.on("start", function(val) {
    getConditions();
    AGENTRELOADED = false;
});

// assign the webpage... kinda sloppy, sorry!
prepWebpage();

// handle agent restarts while device carries on running
imp.wakeup(5, function() {
    if (AGENTRELOADED) { getConditions(); }
});
