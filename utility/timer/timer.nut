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


// -----------------------------------------------------------------------------
// Timer class: Implements a simple timer class with one-off and interval timers
//              all of which can be cancelled.
//
// Author: Aron
// Created: October, 2013
// Updated: March, 2014
//
// =============================================================================
class Timer {

    self = null;
    cancelled = false;
    paused = false;
    running = false;
    callback = null;
    interval = 0;
    params = null;
    send_self = false;
    alarm_timer = null;

    // -------------------------------------------------------------------------
    constructor(_params = null, _send_self = false) {
        params = _params;
        send_self = _send_self;
        self = this;
    }

    // -------------------------------------------------------------------------
    function tzoffset(offset = null) {
        // Store and retrieve the tzoffset from the global scope
        if (!("timer_tzoffset" in ::getroottable())) ::timer_tzoffset <- 0;
        if (offset != null) ::timer_tzoffset <- offset;
        return ::timer_tzoffset;
    }
    
    // -------------------------------------------------------------------------
    function update(_params) {
        params = _params;
        return self;
    }

    // -------------------------------------------------------------------------
    function set(_duration, _callback = null) {
        if (_callback) callback = _callback;
        running = true;
        cancelled = false;
        paused = false;
        if (alarm_timer) imp.cancelwakeup(alarm_timer);
        if (_duration == 0) {
            alarm();
        } else {
            alarm_timer = imp.wakeup(_duration, alarm.bindenv(self))
        }
        return self;
    }

    // -------------------------------------------------------------------------
    function repeat(_interval, _callback) {
        interval = _interval;
        return set(_interval, _callback);
    }

    // -------------------------------------------------------------------------
    function now() {
        return alarm(true);
    }
    
    // -------------------------------------------------------------------------
    function at(_time, _callback) {
        if (typeof _time == "string") {
            local target = strtodate(_time, tzoffset())
            _time = target.time;
        }
        local diff = _time - time();
        if (diff < 0) diff = 0;
        return set(diff, _callback)
    }
    
    // -------------------------------------------------------------------------
    function daily(_time, _callback) {
        interval = 24*60*60;
        return at(_time, _callback)
    }
    
    // -------------------------------------------------------------------------
    function hourly(_time, _callback) {
        interval = 60*60;
        return at(_time, _callback)
    }
    
    // -------------------------------------------------------------------------
    function minutely(_time, _callback) {
        interval = 60;
        return at(_time, _callback)
    }
    
    // -------------------------------------------------------------------------
    function repeat_from(_time, _interval, _callback) {
        interval = _interval;
        return at(_time, _callback)
    }

    // -------------------------------------------------------------------------
    function cancel() {
        if (alarm_timer) imp.cancelwakeup(alarm_timer);
        alarm_timer = null;
        cancelled = true;
        running = false;
        callback = null;
        return self;
    }

    // -------------------------------------------------------------------------
    function pause() {
        paused = true;
        return self;
    }

    // -------------------------------------------------------------------------
    function unpause() {
        paused = false;
        return self;
    }

    // -------------------------------------------------------------------------
    function alarm(immediate = false) {
        if (!immediate) {
            if (interval > 0 && !cancelled) {
                alarm_timer = imp.wakeup(interval, alarm.bindenv(self))
            } else {
                running = false;
                alarm_timer = null;
            }
        }

        if (callback && !cancelled && !paused) {
            if (!send_self && params == null) {
                callback();
            } else if (send_self && params == null) {
                callback(self);
            } else if (!send_self && params != null) {
                callback(params);
            } else  if (send_self && params != null) {
                callback(self, params);
            }
        }
    }
        
    // -------------------------------------------------------------------------
    // Converts a string (of various formats) to a time stamp
    function strtodate(str, tz=0) {
        
        // Prepare the variables
        local year, month, day, hour, min, sec;

        // Capture the components of the date time string
        local ex = regexp(@" ([a-zA-Z]+) ([0-9]+), ([0-9]+) ([0-9]+):([0-9]+) ([AP]M)");
        local ca = ex.capture(str);
        if (ca != null) {
            year = str.slice(ca[3].begin, ca[3].end).tointeger();
            month = str.slice(ca[1].begin, ca[1].end); 
            switch (month) {
                case "January": month = 0; break;  case "February": month = 1; break;  case "March": month = 2; break;
                case "April": month = 3; break;    case "May": month = 4; break;       case "June": month = 5; break;
                case "July": month = 6; break;     case "August": month = 7; break;    case "September": month = 8; break;
                case "October": month = 9; break;  case "November": month = 10; break; case "December": month = 11; break;
                default: throw "Invalid month"; 
            }
            day = str.slice(ca[2].begin, ca[2].end).tointeger()-1;
            hour = str.slice(ca[4].begin, ca[4].end).tointeger();
            min = str.slice(ca[5].begin, ca[5].end).tointeger();
            sec = 0;
            
            // Tweak the 12-hour clock 
            if (hour == 12) hour = 0;
            if (str.slice(ca[6].begin, ca[6].end) == "PM") hour += 12;
            
        } else {
            ex = regexp(@"([0-9]+):([0-9]+)(:([0-9]+))?");
            ca = ex.capture(str);
            if (ca.len() == 5) {
                local local_now = date(time() + tz);
                year = local_now.year;
                month = local_now.month;
                day = local_now.day-1;
                hour = str.slice(ca[1].begin, ca[1].end).tointeger();
                min = str.slice(ca[2].begin, ca[2].end).tointeger();
                if (ca[4].begin == ca[4].end) sec = 0;
                else sec = str.slice(ca[4].begin, ca[4].end).tointeger();
                
                // Tweak the 24 hour clock
                if (hour*60*60 + min*60 + sec < local_now.hour*60*60 + local_now.min*60 + local_now.sec) {
                    hour += 24;
                }
                
                // Adjust back to UTC
                tz = -tz;
                
            } else {
                throw "We are currently expecting, exactly, this format: 'Tuesday, January 7, 2014 9:57 AM'";
            }
        }
        
        // Do some bounds checking now
        if (year < 2012 || year > 2017) throw "Only 2012 to 2017 is currently supported";
    
        // Work out how many seconds since January 1st
        local epoch_offset = { "2012":1325376000, "2013":1356998400, "2014":1388534400, "2015":1420070400, "2016":1451606400, "2017":1483228800 };
        local seconds_per_month = [ 2678400, 2419200, 2678400, 2592000, 2678400, 2592000, 2678400, 2678400, 2592000, 2678400, 2592000, 2678400];
        local leap = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
        if (leap) seconds_per_month[1] = 2505600;
    
        local offset = epoch_offset[year.tostring()];
        for (local m = 0; m < month; m++) offset += seconds_per_month[m];
        offset += (day * 86400);
        offset += (hour * 3600);
        offset += (min * 60);
        offset += sec;
        offset += tz;

        // Finally, generate a date object from the offset
        local dateobj = date(offset);
        dateobj.str <- format("%02d-%02d-%02d %02d:%02d:%02d Z", dateobj.year, dateobj.month+1, dateobj.day, dateobj.hour, dateobj.min, dateobj.sec);
        return dateobj;
    }
    
}






/*............./[ Samples ]\..................
t <- Timer().set(10, function() {
     // Do something in 10 seconds
});
t <- Timer().repeat(10, function() {
     // Do something every 10 seconds plus immediately on execution.
}).now();
t.cancel();

Timer.tzoffset(-25200);
Timer().daily("11:00", function() {
	// Do something every 11am in UTC-7
});
............./[ Samples ]\..................*/
