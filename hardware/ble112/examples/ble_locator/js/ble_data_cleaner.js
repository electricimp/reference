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


function map_beacon(beacon_address, lat, lng, colour) {
	if (!(beacon_address in beacons_geodata)) {
		// Create a marker on the map
		beacons_geodata[beacon_address] = {};
		beacons_geodata[beacon_address].lat = lat;
		beacons_geodata[beacon_address].lng = lng;
		beacons_geodata[beacon_address].marker = new google.maps.Marker({
			position: new google.maps.LatLng(lat, lng),
			animation: google.maps.Animation.DROP,
			title: beacon_address,
			icon: {
			    path: google.maps.SymbolPath.CIRCLE,
			    fillColor: colour ? colour : 'blue',
			    fillOpacity: .4,
			    scale: 4.5,
			    strokeColor: 'blue',
			    strokeWeight: 1
			}
		});
		beacons_geodata[beacon_address].marker.setMap(map);
	} else {
		// Update the existing marker
		beacons_geodata[beacon_address].lat = lat;
		beacons_geodata[beacon_address].lng = lng;
		beacons_geodata[beacon_address].marker.setPosition(new google.maps.LatLng(lat, lng));
	}
}

const POWER_FACTOR = 0.55;
function rssi_to_distance(rssi, txpower) {
	var distance = (txpower - rssi) * POWER_FACTOR + 1.0; // The 1.0 is the calibration point
	return Math.max(distance, 0.1);
}

// Given two locations and a txpower, interpolate linearly between them
function interpolate_rssi(location0, location1, txpower, beacon_address) {
	var location0_geodata = location0.address ? locations_geodata[location0.address] : location0;
	var location1_geodata = location1.address ? locations_geodata[location1.address] : location1;
	var d0 = rssi_to_distance(location0.rssi, txpower);
	var d1 = rssi_to_distance(location1.rssi, txpower);
	var ratio = d0 / (d0 + d1);
	var lat = (location0_geodata.lat * (1.0 - ratio)) + (location1_geodata.lat * (ratio));
	var lng = (location0_geodata.lng * (1.0 - ratio)) + (location1_geodata.lng * (ratio));
	var avg_rssi = (location0.rssi + location1.rssi) / 2.0;
	// console.log(beacon_address, location0.address, location0.rssi, txpower, d0.toFixed(4), " <=> ", location1.address, location1.rssi, txpower, d1.toFixed(4))
	return { lat: lat, lng: lng, rssi: avg_rssi }
}



// Trilaterate the location of the device from the RSSI values of the listening stations that can see it
function trilaterate(beacon_address, txpower, colour, locations_visible) {

	var now = parseInt((new Date()).getTime() / 1000);

	// Break out the recent locations into an array sorted by the rssi
	var recent_locations = [];
	for (var location_address in locations_visible) {
		var beacon = locations_visible[location_address];
		if (now - beacon.time < 60) {
			beacon.address = location_address;
			recent_locations.push(beacon)
		}
	}
	recent_locations.sort(function _reverse_rssi(a,b) {
		if (a.rssi < b.rssi) return 1;
		if (a.rssi > b.rssi) return -1;
		return 0;
	});

	if (recent_locations.length == 1) {
		// With only one visible location, we have no idea which direction to go, so drop it on the location
		map_beacon(beacon_address, locations_geodata[recent_locations[0].address].lat, locations_geodata[recent_locations[0].address].lng, colour);
	} else if (recent_locations.length == 2) {
		// With two, we can linearly interpolate between the two locations
		var int01 = interpolate_rssi(recent_locations[0], recent_locations[1], txpower, beacon_address);
		map_beacon(beacon_address, int01.lat, int01.lng, colour);
	} else if (recent_locations.length >= 3) {
		// With three, we interpolate between the two weekest and then between there and the strongest
		var int12 = interpolate_rssi(recent_locations[1], recent_locations[2], txpower, beacon_address);
		var int03 = interpolate_rssi(recent_locations[0], int12, txpower, beacon_address);
		map_beacon(beacon_address, int03.lat, int03.lng, colour);

	}

		
	// Sort the beacons alphanumerically
	var sorted_locations = [];
	for (var beacon in locations_visible) {
		sorted_locations.push(beacon);
	}
	sorted_locations.sort();

	// Output a text version of all the visible beacons
	best_loc = "";
	for (var i in sorted_locations) {
		var beacon = sorted_locations[i];
		best_loc += beacon + " = " + (locations_visible[beacon].total / locations_visible[beacon].samples).toFixed(2) + "<br/>";
	}

	return best_loc;
}

