/*
The MIT License (MIT)

Copyright (c) 2013 Jason Snell

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


const GOOGLE_MAPS_URL = "https://maps.googleapis.com/maps/api";
function get_tzoffset(lat, lon, callback = null) {
    local url = format("%s/timezone/json?sensor=false&location=%f,%f&timestamp=%d", GOOGLE_MAPS_URL, lat, lon, time());
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Google maps error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local dst = json.dstOffset.tofloat();
                local raw = json.rawOffset.tofloat();
                local tzoffset = ((raw+dst)/60.0/60.0);
                
                if (callback) callback(tzoffset);
            } catch (e) {
                server.error("Google maps error: " + e)
                if (callback) callback(null);
            }
            
        }
    })
}

