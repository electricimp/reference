$(function() {

	var fb_locations = new Firebase(FB_URL + "/locations");
	var fb_beacons = new Firebase(FB_URL + "/beacons");

	// *************** [ Redraw all branches ] ***************

	function redraw_locations() {

		// Read all the /locations data and update the display
		fb_locations.once('value', function(snapshots) {
			snapshots.forEach(function(snapshot) {
				var location = snapshot.name();
				var location_data = snapshot.val();
				var location_class = location.replace(/:/g, "_");

				// Update the table tow entries
				var label = location;
				if (location_data != null && location_data.label != "") {
					label = location_data.label;
				}

				var colour = 'grey';
                if (location in location_colours) {
                    colour = location_colours[location];
                } else if (location_colour_list.length > 0) {
                    colour = location_colour_list.shift();
                    location_colours[location] = colour;
                }

				$(".location." + location_class).html(label).attr('title', location).css('color', colour);
			})
		})

	}

	function add_to_table(address, scan_data) {

		var address_class = address.replace(/:/g, "_");

		if ($("tr." + address_class).length == 0) {
			var row = "<tr class='" + address_class + " expired'>" +
							"<td class='blabel'></td>" + 
							"<td class='location'></td>" + 
							"<td class='commands'>" +
							"	<a class='discover' href=#><span class='glyphicon glyphicon-info-sign'></span></a>" +
							"	<a class='rename' href=#><span class='glyphicon glyphicon-cog'></span></a>" +
							"   <a class='archive' href=#><span class='glyphicon glyphicon-trash'></span></a>" +
							"</td>" +
						"</tr>";
			$("#beacons_table > tbody:last").after(row);
		}

		// Replace the label
		var description = clean_uuid(scan_data);
		$("tr." + address_class + " td.blabel").html(description);

		// Replace the location and rssi
		if ("rssi" in scan_data) {
			var location = trilaterate(address, scan_data.power, scan_data.colour, scan_data.rssi);
			var beacons = "";
			for (var beacon in scan_data.rssi) {
				beacons += (beacon + " = " + scan_data.rssi[beacon].rssi + "\n");
			}
			$("tr." + address_class + " td.location").html(location).attr('title', beacons);
		}

		// Set the colour based on the status
		var now = parseInt((new Date()).getTime() / 1000);
		if (scan_data.last_seen == undefined) {
			$("tr." + address_class).addClass('expired').removeClass('recent');
			$("tr." + address_class + " td.duration").html("");
		} else if (scan_data.old || (now - scan_data.last_seen > 60)) {
			$("tr." + address_class).addClass('expired').removeClass('recent');
			$("tr." + address_class + " td.duration").html(toHHMMSS(now - scan_data.last_seen) + " ago");
		} else if (scan_data.new) {
			$("tr." + address_class).removeClass('expired').addClass('recent');
			$("tr." + address_class + " td.duration").html(toHHMMSS(scan_data.last_seen - scan_data.first_seen));
		} else {
			$("tr." + address_class).removeClass('expired').removeClass('recent');
			$("tr." + address_class + " td.duration").html(toHHMMSS(scan_data.last_seen - scan_data.first_seen));
		}
	}



	// *************** [ Watch the /locations branch ] ***************

	// We have a new watched location
	fb_locations.on('child_added', function(snapshot) {
		// Create a new row in the table for this beacon
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");
		var location_data = snapshot.val();

		locations_geodata[address] = {};
		locations_geodata[address].lat = parseFloat(location_data.lat);
		locations_geodata[address].lng = parseFloat(location_data.lng);
		locations_geodata[address].marker = new google.maps.Marker({
			position: new google.maps.LatLng(location_data.lat, location_data.lng),
			// animation: google.maps.Animation.DROP,	
			title: address,
			icon: {
			    path: google.maps.SymbolPath.CIRCLE,
			    fillColor: 'cyan',
			    fillOpacity: .4,
			    scale: 4.5,
			    strokeColor: 'blue',
			    strokeWeight: 1
			}
		});
		locations_geodata[address].marker.setMap(map);

		var row = "<tr class='" + address_class + "'>" +
						"<td class='address'>" + address + "</td>" + 
						"<td class='blabel location " + address_class + "'>" + (location_data.label || "Unknown") + "</td>" + 
						"<td class='mac'>" + (location_data.mac || "Unknown") + "</td>" + 
						"<td class='commands'>" +
						"	<a class='rename' href=#><span class='glyphicon glyphicon-cog'></span></a>" +
						"	<a class='delete' href=#><span class='glyphicon glyphicon-trash'></span></a>" +
						"</td>" +
					"</tr>";
		$("#locations_table > tbody:last").after(row);

		// Now redraw the screen
		redraw_locations();

		// Attach the command handlers
		$("table").on('click', "#locations_table tr." + address_class + " td.commands a.delete", function() {

			// Remove the entry from the locations branch
			fb_locations.child(address).remove();

			// Now redraw the screen
			redraw_locations();

			return false;
		})	

		$("table").on('click', "#locations_table tr." + address_class + " td.commands a.rename", function() {
			var oldlabel = $("#locations_table tr." + address_class + " td.blabel").html();
			var label = prompt("Give the location a label", oldlabel);
			if (label) {

				// Add the entry to the locations branch
				fb_locations.child(address).update({"label": label});

				// Now redraw the screen
				redraw_locations();
			}
			return false;
		})
	});

	// We have a location thats being updated
	fb_locations.on('child_changed', function(snapshot) {
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");
		var location_data = snapshot.val();

		locations_geodata[address].lat = location_data.lat;
		locations_geodata[address].lng = location_data.lng;
		locations_geodata[address].marker.setPosition(new google.maps.LatLng(location_data.lat, location_data.lng));

		// Update the table row entries
		$("#locations_table tr." + address_class + " td.blabel").html(location_data.label || "Unknown");
		$("#locations_table tr." + address_class + " td.mac").html(location_data.mac || "Unknown");
		
		// Now redraw the screen
		redraw_locations();
	});

	// We have a location thats being unwatched
	fb_locations.on('child_removed', function(snapshot) {
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");

		locations_geodata[address].marker.setMap(null);
		delete locations_geodata[address];

		// Nobody else can use this data
		$(".location." + location_class).html(address);

		// Remove the row and stop listening for changes
		$("#locations_table tr." + address_class).remove();

		// Now redraw the screen
		redraw_locations();
	});


	// *************** [ Watch the /beacons branch ] ***************

	// We have a new watched scan
	fb_beacons.on('child_added', function(snapshot) {
		// Create a new row in the table for this beacon
		var scan_data = snapshot.val();
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");

		// Draw the data in the correct table
		add_to_table(address, scan_data);
		redraw_locations()

		// Attach the command handlers
		$("table").on('click', "tr." + address_class + " td.commands a.discover", function() {

			// Extract the location and POST a discover request to it
			fb_beacons.child(address + "/location").once('value', function(snapshot) {
				var location = snapshot.val();
				if (location == null) return;
				fb_locations.child(location + "/agenturl").once('value', function(snapshot) {
					var agenturl = snapshot.val();
					if (agenturl == null) return;
					$.ajax({ url: agenturl + "?discover=" + address });
				})
			})

			return false;
		})

		$("table").on('click', "tr." + address_class + " td.commands a.activate", function() {
			var label = prompt("Give the beacon a label", address);
			if (label) {
				fb_beacons.child(address).update({"label": label});

				// Now redraw the screen
				redraw_locations();
			}
			return false;
		})

		$("table").on('click', "tr." + address_class + " td.commands a.rename", function() {
			var oldlabel = $("tr." + address_class + " td.blabel").html();
			var label = prompt("Give the beacon a label", oldlabel);
			if (label) {
				// Add the entry to the bracons branch
				fb_beacons.child(address).update({"label": label});
			}

			return false;
		})


		$("table").on('click', "tr." + address_class + " td.commands a.delete", function() {
			// Mark this beacon as archived
			fb_beacons.child(address).remove();

			return false;
		})	

		$("table").on('click', "tr." + address_class + " td.commands a.archive", function() {
			// Mark this beacon as archived
			fb_beacons.child(address).update({"archived": true});

			return false;
		})	
	})

	// We have a beacon that has been edited
	fb_beacons.on('child_changed', function(snapshot) {
		var address = snapshot.name();
		var scan_data = snapshot.val();

		// Now make sure we only show it in the correct table
		add_to_table(address, scan_data)
		redraw_locations()

	});

	// We have a beacon thats being unwatched
	fb_beacons.on('child_removed', function(snapshot) {
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");

		beacons_geodata[address].marker.setMap(null);
		delete beacons_geodata[address];

		// Remove the row from all tables and stop listening for changes
		$("tr." + address_class).remove();
	});


})
