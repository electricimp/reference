function toHHMMSS (t_seconds) {
    var sec_num = parseInt(t_seconds, 10); // don't forget the second param
    var hours   = Math.floor(sec_num / 3600);
    var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
    var seconds = sec_num - (hours * 3600) - (minutes * 60);

    if (hours   < 10) {hours   = "0"+hours;}
    if (minutes < 10) {minutes = "0"+minutes;}
    if (seconds < 10) {seconds = "0"+seconds;}
    var time    = hours+':'+minutes+':'+seconds;
    return time;
}



function clean_uuid(data) {
	var uuid = data.uuid.replace(/ /g, "")
						.replace(/(........)(....)(....)(....)(............)/, "$1-$2-$3-$4-$5")
			 + ", " + data.major + ", " + data.minor;

	return uuid;
}


// Out of a list of locations, pick the newest signal that isn't weaker than another signal recently after it
function best_location(locations) {

	// Sort the locations by reverse time (newest first)
	var locs = [];
	for (var loc in locations) {
		var rssi = locations[loc].rssi;
		var ts = locations[loc].time;
		locs.push({rssi:rssi, ts:ts, loc:loc});
	}
	locs.sort(function(a, b) { return b.ts - a.ts; });

	// Shortcut if we only have one location
	if (locs.length == 1) return locs[0];

	// For each location, check if there are any other more powerful signals within 60 of it
	var best_loc = locs.shift();
	while (locs.length > 0) {
		var next_loc = locs.shift();
		if (best_loc.ts - next_loc.ts < 60 && best_loc.rssi < next_loc.rssi) {
			best_loc = next_loc;
		}
	}

	return best_loc;
}

