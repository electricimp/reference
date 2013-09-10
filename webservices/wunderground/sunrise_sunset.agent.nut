/*
The MIT License (MIT)

Copyright (c) 2013 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

// Location can be:
//   Country/City ("Australia/Sydney") 
//   US State/City ("CA/Los_Altos")
//   Lat,Lon ("37.776289,-122.395234") 
//   Zipcode ("94022") 
//   Airport code ("SFO")

const WUNDERGROUND_KEY = "yourapikey";
const WUNDERGROUND_URL = "http://api.wunderground.com/api";
function get_sunrise_sunset(location, callback) {
    local url = format("%s/%s/astronomy/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, location);
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.error("Wunderground error: " + res.statuscode + " => " + res.body);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local sunrise = json.sun_phase.sunrise;
                local sunset = json.sun_phase.sunset;
                local now = json.moon_phase.current_time;
                if (callback) callback(sunrise, sunset, now);
            } catch (e) {
                server.error("Wunderground error: " + e)
                if (callback) callback(null, null, null);
            }
            
        }
    })
}

