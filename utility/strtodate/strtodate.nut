//
// This function takes a string (in a specific format) and returns a date object.
// To change the expected format, change the regular expressions and ca[] array references.
//
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