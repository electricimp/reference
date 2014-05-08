

// -----------------------------------------------------------------------------
// WifiTimezone class
//
// Requests the imp to scan for wifi networks, sends that data to Google Maps to 
// geolocate the imp, sends that data to Google Maps to collect timezone data
//
class WifiTimezone {
    
    _scan_keyword = null;
    _wifis = null;
    _location = null;
    
    // -------------------------------------------------------------------------
    constructor(scan_keyword = "wifiscan") {
        
        _scan_keyword = scan_keyword;
        _wifis = [];
        _location = {};
        
    }
    
    // -------------------------------------------------------------------------
    // Requests the imp to scan the wifi networks it can see and return 
    // them all in a callback
    // 
    function getWifis(callback, timeout = 10) {

        // Send the command to the device to run the scan
        device.send(_scan_keyword, _scan_keyword)
        local timer;
        
        // Handle the reply
        device.on(_scan_keyword, function(wifis) {
            
            if (timer) imp.cancelwakeup(timer); timer = null;
            
            _wifis = wifis;
            callback(null, _wifis);
            device.on(_scan_keyword, function(d) {});
            
        }.bindenv(this));

        // Handle a timeout
        timer = imp.wakeup(timeout, function() {
            timer = null;

            callback("wifis timeout", null);
            device.on(_scan_keyword, function(d) {});
            
        }.bindenv(this))
        
    }
    
    // -------------------------------------------------------------------------
    // Sends the visible Wifi networks to Google to geolocate
    //
    function getLocation(callback, timeout = 60) {
        if (_wifis.len() == 0) throw "You must scan for wifi networks first";

        // Build the URL and POST data
        local timer;
        local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
        local headers = {};
        foreach (newwifi in _wifis) {
           
            local bssid = format("%s:%s:%s:%s:%s:%s", newwifi.bssid.slice(0,2), 
                                                      newwifi.bssid.slice(2,4), 
                                                      newwifi.bssid.slice(4,6), 
                                                      newwifi.bssid.slice(6,8), 
                                                      newwifi.bssid.slice(8,10), 
                                                      newwifi.bssid.slice(10,12));
            url += format("&wifi=mac:%s|ss:%d", bssid, newwifi.rssi);
            
       }
       
       // POST it to Google
       local req = http.get(url, headers);
       req.sendasync(function(res) {
    
            if (timer) imp.cancelwakeup(timer); timer = null;
           
            local err = null;
            if (res.statuscode == 200) {
                local json = http.jsondecode(res.body);
                if (!("status" in json)) {
                    err = format("Unexpected response from Google Location: %s", res.body);
                } else if (json.status == "OK") {
                    return callback(null, _location = json.location)
                } else {
                    err = format("Received status %s from Google Location", json.status);
                }
            } else {
                err = format("Received error response %d from Google Location", res.statuscode);
            }
            callback(err, null);
           
        }.bindenv(this));

       
        // Handle a timeout
        timer = imp.wakeup(timeout, function() {
            timer = null;

            req.cancel();
            callback("location timeout", null);
            
        }.bindenv(this))
       
    }
    
    // -------------------------------------------------------------------------
    // status	    Status of the API query. Either OK or FAIL.
    // timeZoneId	The name of the time zone. Refer to time zone list.
    // timeZoneName The long description of the time zone
    // gmtOffsetStr GMT Offset String such as GMT-7
    // rawOffset    The time zone's offset without DST changes
    // dstOffset    The DST offset to be added to the rawOffset to get the current gmtOffset
    // gmtOffset	The time offset in seconds based on UTC time.
    // time         Current local time in Unix timestamp.   
    // date         Squirrel date() object
    // dateStr      Date string formatted as YYYY-MM-DD HH-MM-SS
    //
    function getTZdata(callback, timeout = 60) {
        if (_location.len() != 2) throw "You must scan for wifi and get the location data first";

        // POST the location data to timezonedb
        local timer;
        local url = "https://maps.googleapis.com/maps/api/timezone/json?location=" + _location.lat + "," + _location.lng+"&timestamp="+time()+"&sensor=false";
        local headers = {};
        local req = http.get(url, headers);
        req.sendasync(function(res) {

            if (timer) imp.cancelwakeup(timer); timer = null;

            local err = null;
            local json = http.jsondecode(res.body);
            if (!("status" in json)) {
                err = format("Unexpected response from TimezoneDB: %s", res.body);
            } else if (json.status == "OK") {
                local t = time() + json.rawOffset + json.dstOffset;
                local d = date(t);
                json.time <- t;
                json.date <- d;
                json.dateStr <- format("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.month+1, d.day, d.hour, d.min, d.sec)
                json.gmtOffset <- json.rawOffset + json.dstOffset;
                json.gmtOffsetStr <- format("GMT%s%d", json.gmtOffset < 0 ? "-" : "+", math.abs(json.gmtOffset / 3600));
                return callback(null, json);
            } else {
                err = format("Received status %s from TimezoneDB", json.status);
            }
            callback(err, null);
            
        }.bindenv(this));

       
        // Handle a timeout
        timer = imp.wakeup(timeout, function() {
            timer = null;

            req.cancel();
            callback("tzdata timeout", null);
            
        }.bindenv(this))
       
        
    }
    
    
    // -------------------------------------------------------------------------
    // Calls getWifis(), getLocation() and getTZdata() and returns them all to the callback
    // callback = function(err, wifis, location, tzdata);
    //
    function get(callback) {
        getWifis(function(err, wifis) {
            if (err != null) return callback(err, wifis, null, null);
            getLocation(function(err, location) {
                if (err != null) return callback(err, wifis, location, null);
                getTZdata(function(err, tzdata) {
                    callback(err, wifis, location, tzdata);
                }.bindenv(this)); // getTZdata
            }.bindenv(this)); // getLocation
        }.bindenv(this)); // getWifis
    }
    

}



// ------------------------[ Example code ]------------------------

wtz <- WifiTimezone();
device.onconnect(function() {
    
    wtz.get(function(err, wifis, location, tzdata) {
        if (err == null) {
            server.log(format("%s %s", tzdata.dateStr, tzdata.gmtOffsetStr));
        } else {
            server.error(err);
        }
    }.bindenv(this))
    
})

