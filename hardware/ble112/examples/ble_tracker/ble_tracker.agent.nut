// #include "firebase.agent.nut"

firebase <- Firebase("YOUR FIREBASE", "YOUR API KEY");

device.on("location", function(data) {
    data.agenturl <- http.agenturl();
    firebase.update("/locations/" + data.address, data);
})

device.on("scans", function(scans) {
    foreach (address, scan in scans) {
        if (scan.len() > 0) {
            firebase.update("/scans/" + address, scan);
            firebase.write("/scans/" + address + "/locations/" + scan.location, {rssi=scan.rssi, time=time()});
        }
    }
})

device.on("gatts", function(gatts) {
    foreach (address, gatt in gatts) {
        if (gatt.len() > 0) {
            firebase.update("/scans/" + address, gatt);
        }
    }
})

http.onrequest(function(req, res) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Methods", "GET,POST");
    if (req.method == "OPTIONS") {
        res.send(200, "OK");
    } else if ("discover" in req.query) {
        device.send("discover", req.query.discover);
        res.send(200, "OK");
    } else {
        res.send(404, "Unknown request");
    }
})

server.log("Agent started, URL is " + http.agenturl());


