
var fb_locations = new Firebase(FB_URL + "/locations");
var fb_scans = new Firebase(FB_URL + "/scans");

// *************** [ Draw the signal chart ] ***************

// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

// Set a callback to run when the Google Visualization API is loaded.
google.setOnLoadCallback(function() {
    var options = {
        width: '100%',
        height: 300,
	    chartArea: {top: 10, width: '90%', height: '90%'},
		legend: 'none',
		title: '',
        vAxis: {minValue:-100, maxValue:0},
		hAxis: {textPosition: "none"},
		tooltip: {isHtml: false},
        animation:{
            duration: 1000,
            easing: 'inAndOut',
        },
    };
    var chart = new google.visualization.ColumnChart($('#signals')[0]);
    var chartData = [];
    
    fb_scans.on('child_added', function (snapshot) {
        var address = snapshot.name();
        var scan_data = snapshot.val();
        var locations = scan_data.locations;
		var archived = scan_data.archived == true;
        draw_plot_data(address, locations, archived);
    });
    
    fb_scans.on('child_changed', function (snapshot) {
        var address = snapshot.name();
        var scan_data = snapshot.val();
        var locations = scan_data.locations;
		var archived = scan_data.archived == true;
        draw_plot_data(address, locations, archived);
    });
    
    fb_scans.on('child_removed', function (snapshot) {
        var address = snapshot.name();
        draw_plot_data(address);
    });
    
	$(window).resize(function(){
        draw_plot_data();
	});

    var redraw_timer = null;
    function draw_plot_data(addr, locations, archived) {
        
		// Work out if we are adding or removing a beacon
        var add = true;
		var rem = archived == true || archived == undefined;
        for (var i in chartData) {
            if (chartData[i].addr == addr) {
                if (rem) {
                    delete chartData[i];
                } else {
                    chartData[i].locations = locations;
                }
                add = false;
                break;
            }
        }
        if (add && !rem && addr) {
            chartData.push({addr: addr, locations: locations});
        }
        
        if (redraw_timer) clearTimeout(redraw_timer);
        redraw_timer = setTimeout(function() {
            redraw_timer = null;
            
			// Load the data from the global array into the chart structure
            var data = new google.visualization.DataTable();
            data.addColumn('string', 'N');
            data.addColumn('number', 'RSSI (dBm)');
            data.addColumn({type:"string", role: "style"});
            data.addColumn({type:"string", role: "tooltip", p: {html: true}});

            for (var i in chartData) {

				var addr = chartData[i].addr;
				var loc = best_location(chartData[i].locations);
				if (!loc) continue;
				var location = loc.loc;
				var rssi = loc.rssi;
                var colour = 'grey';

                if (location in location_colours) {
                    colour = location_colours[location];
                } else if (location_colour_list.length > 0) {
                    colour = location_colour_list.shift();
                    location_colours[location] = colour;
                }
                
                var tooltip = addr + " is " + rssi + " dBm from " + location;
                data.addRow([addr, rssi, colour, tooltip]);
            }

			// Finally, draw it
            chart.draw(data, options);
        }, 300);
        
    }    

})
