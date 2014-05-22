firebase <- Firebase("imp-beacons");

device.on("location", function(location) {
    firebase.update("/locations/" + location.address, location);
})

device.on("scans", function(scans) {
    foreach (beaconid, data in scans) {
        firebase.update("/beacons/" + beaconid + "/rssi", data.rssi);
        delete data.rssi;
        firebase.update("/beacons/" + beaconid, data);
    }
})

server.log("Agent started, URL is " + http.agenturl());


