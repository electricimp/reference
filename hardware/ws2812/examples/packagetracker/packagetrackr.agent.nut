// Package Tracker Agent
// Copyright (C) 2014 Electric Imp, inc.
// 
// Scrapes PackageTrackr.com

const trackURL = "http://www.packagetrackr.com/track/";
const UPDATEINTERVAL = 3600; // check on packages once per hour
WEBPAGE <- null;

// load list of packages from the server, if it's there
packages <- server.load();
// sample tracking numbers from PackageTrackr
/*
packages <- {
    "569991312258": 0,
    "796604647790": 0,
    "1Z6376604292556056": 0, 
    "RF301726177SG": 0,
    "9261290100100926772640":0,
    "9405510200974044038335":0
}
*/

// wakeup handle for package tracker update
updatehandle <- null;

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
    
        <title>Tracker</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAAAAAAAABoBQAAFgAAACgAAAAQAAAAIAAAAAEACAAAAAAAAAEAAAAAAAAAAAAAAAEAAAAAAAAAAAAACEajAPr6+gAAAgUABzuKACdlwgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMEAQEBAAAAAAAAAAAAAAMEBAEBAQEBAAAAAAAAAAMEBAQBAgICAQEAAAAAAAMEBAQEAQMCAwIBAQEAAAAEBAQEBAECAwICAQEBAQAABAQEBAQBAgIDAgEBAQEBAAQEBAQEAQMDAgIBAQEBAQADBAQEAQECAgMCAQEBAQEABAQEBAUFAQECAgEBAQEBAAQEBAUFBQUFAQEBAQEBAQAEBAUBAQEFBQUFBQEBAQEABAUFBQUBAQEFBQUFBQEBAAUFBQUFBQUFAQEBBQUFBQAAAAUFBQUFBQUFBQEBBQAAAAAAAAAFBQUFBQUFBQAAAAAAAAAAAAAABQUFAAAAAPB/AADgHwAAwA8AAIADAACAAQAAgAAAAIAAAACAAAAAgAAAAIAAAACAAAAAgAAAAIAAAADgAQAA/AMAAP+PAAA=' rel='icon' type='image/x-icon' />
        <link href='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css' rel='stylesheet'>
    
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
              <a class='navbar-brand'>Package Tracker</a>
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
                <h3>Currently Tracking:</h3>
                <div class='row' style = 'margin-top: 20px; margin-bottom: 20px; margin-left:5px; margin-right: 5px;'>
                    <ul id='trackers' class='list-group'></ul>
                </div>
                <div class='input-group'>
                    <input type='text' class='form-control' id='newTracker'>
                    <span class='input-group-btn'>
                        <button class='btn btn-default' type='button' onClick='addTracker();'>Track Package</button>
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
      
        var getListURL= document.URL+'/list';
        var addURL = document.URL+'/add';
        var removeURL = document.URL+'/remove';
        
        function removeTracker(who) {
            var tracker = who.parent().children('.trackingid').html();
            $.ajax({
                type: 'POST',
                url: removeURL,
                data: tracker,
                success: function() {
                    who.parent().remove();
                }
            })
        }

        function addTracker() {
            var tracker = $('#newTracker').val();
            $.ajax({
                type: 'POST', 
                url: addURL,
                data: tracker,
                success: function() {
                    var listEl = $('#trackers');
                    listEl.append(createListItem(tracker));
                    $('#newTracker').val('');
                }
            })
        }
    
        $(document).ready(function() {
            $.ajax({
                type: 'GET',
                url: getListURL,
                success: function(dataString) { 
                    var data = $.parseJSON(dataString);
                    for(var key in data) {
                        var listEl = $('#trackers');
                        listEl.append(createListItem(key));
                    }
                }
            })
        });

        function createListItem(key) {
             return listItem = '<li class=\'list-group-item\'><span class=\'trackingid\'>' + key + '</span><button type=\'button\' class=\'btn btn-default btn-sm pull-right\' style=\'margin-top: -5px;\' onClick=\'removeTracker($(this));\'><span class=\'glyphicon glyphicon-remove-sign\'></span></button></li>';
        }
    
      </script>
    </body>    
    </html>"
}

// convert a string of the form "Tuesday, January 7, 2014 9:57 AM" into a date object
function strtodate(str, tz=-300) {
    // Capture the components of the date time string
    local ex = regexp(@" ([a-zA-Z]+) ([0-9]+), ([0-9]+) ([0-9]+):([0-9]+) ([AP]M)");
    local ca = ex.capture(str);
    if (ca.len() != 7) throw "We are currently expecting, exactly, this format: 'Tuesday, January 7, 2014 9:57 AM'";
    
    // Parse out each of the components
    local month = str.slice(ca[1].begin, ca[1].end); 
    switch (month) {
        case "January": month = 0; break;  case "February": month = 1; break;  case "March": month = 2; break;
        case "April": month = 3; break;    case "May": month = 4; break;       case "June": month = 5; break;
        case "July": month = 6; break;     case "August": month = 7; break;    case "September": month = 8; break;
        case "October": month = 9; break;  case "November": month = 10; break; case "December": month = 11; break;
        default: throw "Invalid month"; 
    }
    local day = str.slice(ca[2].begin, ca[2].end).tointeger()-1;
    local year = str.slice(ca[3].begin, ca[3].end).tointeger();
    local hour = str.slice(ca[4].begin, ca[4].end).tointeger();
    local min = str.slice(ca[5].begin, ca[5].end).tointeger();
    if (hour == 12) hour = 0;
    if (str.slice(ca[6].begin, ca[6].end) == "PM") hour += 12;
    local sec = 0;
    
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
    offset += tz * 60;
    
    // Finally, generate a date object from the offset
    local dateobj = date(offset);
    dateobj.str <- format("%02d-%02d-%02d %02d:%02d Z", dateobj.year, dateobj.month+1, dateobj.day, dateobj.hour, dateobj.min);
    return dateobj;
}

// request tracking information from PackageTrackr for a given Tracking Number
// requests are sent and handled asynchronously
// the response handler updates the packages table and sends updates to the device
function track(trackingNumber) {
    http.get(trackURL+trackingNumber, {}).sendasync(function(res) {
        if (res.body.len() < 10000) { return server.error("Only received " + res.body.len() + " bytes"); }
        
        local status_start = res.body.find("<div id=\"status-description-radius");
        status_start = res.body.find(">", status_start) + 1;
        local status_end   = res.body.find("<", status_start);
        local status = res.body.slice(status_start, status_end);
        
        local delivered = null;
        local delivered_start = res.body.find("<th class=\"track-info-summary-name\">Delivered on:</th>")
        if (delivered_start) {
            delivered_start = res.body.find("<td class=\"track-info-summary-value\">", delivered_start);
            delivered_start = res.body.find(">", delivered_start+1)+1;
            local delivered_end   = res.body.find("<", delivered_start);
            delivered = res.body.slice(delivered_start, delivered_end);
        }
        
        // get a date object for the shipped date
        local shipped = null;
        local shipped_start = res.body.find("<th class=\"track-info-summary-name\">Shipped on:</th>")
        if (shipped_start) {
            shipped_start = res.body.find("<td class=\"track-info-summary-value\">", shipped_start);
            shipped_start = res.body.find(">", shipped_start+1)+1;
            local shipped_end   = res.body.find("<", shipped_start);
            shipped = strtodate(res.body.slice(shipped_start, shipped_end));
        }
        
        // get a date object for the scheduled delivery date
        local scheduled = null;
        local scheduledStr = null;
        local scheduled_start = res.body.find("<th class=\"track-info-summary-name\">Scheduled for:</th>")
        if (scheduled_start) {
            scheduled_start = res.body.find("<td class=\"track-info-summary-value\">", scheduled_start);
            scheduled_start = res.body.find(">", scheduled_start+1)+1;
            scheduled_start = res.body.find(">", scheduled_start+1)+1;
            local scheduled_end   = res.body.find("<", scheduled_start);
            scheduledStr = res.body.slice(scheduled_start, scheduled_end);
            scheduled = strtodate(scheduledStr);
        }
        
        local totalHours = 0;
        local hoursTilDelivery = 0;
        if (status == "Delivered") {
            server.log(format("Status: Delivered at %s", delivered));
            packages[trackingNumber] = 0;
            device.send("set", {"name":trackingNumber, "level":1});
        } else if (status == "In Transit" || status == "Arrived at Carrier&#39;s Facility") {
            totalHours = ((scheduled.time - shipped.time) / 3600.0);
            hoursTilDelivery = ((scheduled.time - time()) / 3600.0);
            server.log(format("Status: In transit, scheduled for %s, %0.1f hours away", scheduledStr, hoursTilDelivery));
            local level = 1.0 - (hoursTilDelivery / totalHours);
            packages[trackingNumber] <- level;
            device.send("set", { "name":trackingNumber,"level":level} );
        } else {
            server.log(format("Status: %s", status));
        }
    });
}

// iterate through each tracking number in the packages table and update the status
// this function schedules itself to run again every UPDATEINTERVAL seconds
function update() {
    // prevent double-scheduled updates (in case both device and agent restart at some point)
    if (updatehandle) { imp.cancelwakeup(updatehandle); }
    
    // schedule next update
    updatehandle = imp.wakeup(UPDATEINTERVAL, update);
    
    foreach (trackingNumber, hoursTilDelivery in packages) {
        // track implicitly upates hoursTilDelivery and sends the update to the device.
        track(trackingNumber);
    }
}

// add a new tracker to the list and update the device accordingly
function add(trackingNumber) {
    packages[trackingNumber] <- 0;
    track(trackingNumber);
    server.save(packages);
}

// remove a tracker from the list and update the device accordingly
function remove(trackingNumber) {
    delete packages[trackingNumber];
    device.send("remove", trackingNumber);
    server.save(packages);
}

http.onrequest(function(req, resp) {
    resp.header("Access-Control-Allow-Origin", "*");

    local path = req.path.tolower();    
    server.log("new request to "+path+": "+req.body);

    if (path == "/list" || path == "/list/") {
        resp.send(200, http.jsonencode(packages));
    } else if (path == "/remove" || path == "/remove/") {
        remove(req.body);
        resp.send(200, http.jsonencode(packages));
    } else if (path == "/add" || path == "/add/") {
        add(req.body);
        resp.send(200, http.jsonencode(packages));
    } else {
        resp.send(200, WEBPAGE);
    }
});

// handle device restarts while agent carries on running
device.on("start", function(val) {
    update();
});

// assign the webpage... kinda sloppy, sorry!
prepWebpage();

// handle agent restarts while device carries on running
update();
