$(function() {

	var fb_locations = new Firebase(FB_URL + "/locations");
	var fb_scans = new Firebase(FB_URL + "/scans");

	// *************** [ Redraw all branches ] ***************

	setInterval(function() {
		$("#location_count").html($('#locations_table tr').length-1);
		$("#active_count").html($('#beacons_table tr').length-1);
		$("#new_count").html($('#scans_table tr').length-1);
	}, 1000)

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
		var address_type = scan_data.addr_type;

		if (scan_data.archived) {

			$("#beacons_table tr." + address_class).remove();
			$("#scans_table tr." + address_class).remove();
			if ($("tr." + address_class).length == 0) {
				var row = "<tr class='" + address_class + " expired'>" +
								"<td class='blabel'></td>" + 
								"<td class='location'></td>" + 
								"<td class='commands'>" +
								"   <a class='delete' href=#><span class='glyphicon glyphicon-trash'></span></a>" +
								"</td>" +
							"</tr>";

				$("#archives_table > tbody:last").after(row);
			}

		} else if ("label" in scan_data && scan_data.label != "") {

			$("#archives_table tr." + address_class).remove();
			$("#scans_table tr." + address_class).remove();
			if ($("tr." + address_class).length == 0) {
				var row = "<tr class='" + address_class + " expired'>" +
								"<td class='blabel'></td>" + 
								"<td class='location'></td>" + 
								"<td class='rssi'></td>" + 
								"<td class='duration'></td>" + 
								"<td class='commands'>" +
								"	<a class='discover' href=#><span class='glyphicon glyphicon-info-sign'></span></a>" +
								"	<a class='rename' href=#><span class='glyphicon glyphicon-cog'></span></a>" +
								"   <a class='archive' href=#><span class='glyphicon glyphicon-trash'></span></a>" +
								"</td>" +
							"</tr>";
				$("#beacons_table > tbody:last").after(row);
			}

		} else {

			$("#beacons_table tr." + address_class).remove();
			$("#archives_table tr." + address_class).remove();
			if ($("tr." + address_class).length == 0) {
				var row = "<tr class='" + address_class + "'>" +
								"<td class='blabel'></td>" + 
								"<td class='location'></td>" + 
								"<td class='rssi'></td>" + 
								"<td class='duration'></td>" + 
								"<td class='commands'>" +
								"	<a class='discover' href=#><span class='glyphicon glyphicon-info-sign'></span></a>" +
								"	<a class='activate' href=#><span class='glyphicon glyphicon-heart'></span></a>" +
								"	<a class='archive' href=#><span class='glyphicon glyphicon-trash'></span></a>" +
								"</td>" +
							"</tr>";

				$("#scans_table > tbody:last").after(row);
			}

		}


		// Replace the label
		var description = address;
		if (address_type == "random") description += " (random)";
		var label = scan_data.label;
		if (label != "" && label != null) description = label;
		if ("uuid" in scan_data) description += "<br/><span class='subtext'>UUID: " + clean_uuid(scan_data) + "</span>";
		if ("localname" in scan_data) description += "<br/><span class='subtext'>Localname: " + scan_data.localname + "</span>";
		if ("name" in scan_data && scan_data.name != "") description += "<br/><span class='subtext'>Name: " + scan_data.name + "</span>";
		if ("manufacturer" in scan_data) description += "<br/><span class='subtext'>Manufacturer: " + scan_data.manufacturer + "</span>";
		if ("model" in scan_data) description += "<br/><span class='subtext'>Model: " + scan_data.model + "</span>";
		if ("serial" in scan_data) description += "<br/><span class='subtext'>Serial: " + scan_data.serial + "</span>";
		if ("battery" in scan_data) description += "<br/><span class='subtext'>Battery: " + scan_data.battery + "</span>";
		$("tr." + address_class + " td.blabel").html(description).attr('title', address);

		// Replace the location and rssi
		var location = null; // scan_data.location;
		var rssi = null; // scan_data.rssi;
		if ("locations" in scan_data) {
			var loc = best_location(scan_data.locations);
			location = loc.loc;
			rssi = loc.rssi;
		}
		if (location) {
			var location_class = location.replace(/:/g, "_");
			$("tr." + address_class + " td.location").removeClass().addClass("location").addClass(location_class).html(location).attr('title', location);
		}

		// Replace the RSSI
		$("tr." + address_class + " td.rssi").html(rssi ? (rssi + " dBm") : "");

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

		// Update the table row entries
		$("#locations_table tr." + address_class + " td.blabel").html(location_data.label || "Unknown");
		$("#locations_table tr." + address_class + " td.mac").html(location_data.mac || "Unknown");
		
		// Now redraw the screen
		redraw_locations();
	});

	// We have a location thats being unwatched
	fb_locations.on('child_removed', function(snapshot) {
		var location = snapshot.name();
		var location_class = location.replace(/:/g, "_");

		// Nobody else can use this data
		$(".location." + location_class).html(location);

		// Remove the row and stop listening for changes
		$("#locations_table tr." + location_class).remove();

		// Now redraw the screen
		redraw_locations();
	});


	// *************** [ Watch the /scans branch ] ***************

	// We have a new watched scan
	fb_scans.on('child_added', function(snapshot) {
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
			fb_scans.child(address + "/location").once('value', function(snapshot) {
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
				fb_scans.child(address).update({"label": label});

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
				fb_scans.child(address).update({"label": label});
			}

			return false;
		})


		$("table").on('click', "tr." + address_class + " td.commands a.delete", function() {
			// Mark this beacon as archived
			fb_scans.child(address).remove();

			return false;
		})	

		$("table").on('click', "tr." + address_class + " td.commands a.archive", function() {
			// Mark this beacon as archived
			fb_scans.child(address).update({"archived": true});

			return false;
		})	
	})

	// We have a beacon that has been edited
	fb_scans.on('child_changed', function(snapshot) {
		var address = snapshot.name();
		var scan_data = snapshot.val();

		// Now make sure we only show it in the correct table
		add_to_table(address, scan_data)

		redraw_locations()
	});

	// We have a beacon thats being unwatched
	fb_scans.on('child_removed', function(snapshot) {
		var address = snapshot.name();
		var address_class = address.replace(/:/g, "_");

		// Remove the row from all tables and stop listening for changes
		$("tr." + address_class).remove();
	});

})
