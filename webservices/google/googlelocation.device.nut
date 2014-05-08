
// Responds to a request for a wifi scan with the results of the wifi scan. Note its blocking.
const WIFI_SCAN_KW = "wifiscan";
agent.on(WIFI_SCAN_KW, function(topic) {
    agent.send(topic, imp.scanwifinetworks())
});
