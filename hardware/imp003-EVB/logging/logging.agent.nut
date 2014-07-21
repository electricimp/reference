// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const PLOTLY_USER       = "YOUR_USERNAME_HERE";
const PLOTLY_KEY        = "YOUR_APIKEY_HERE";
// Name your plot
const PLOTLY_FILENAME   = "Electric Imp Graph";
// How much historical data to show in hours (autorange must be disabled)
const GRAPH_WINDOW      = 24;

function updatePlotly(temp, lux) {
    local timestamp = time();
    local query = {
        un=PLOTLY_USER,
        key=PLOTLY_KEY,
        origin="plot",
        platform="electricimp",
        // Data
        args=format(@"[{""x"": %i000, ""y"": %f, ""name"": ""Temperature""}, {""x"": %i000, ""y"": %f, ""name"": ""Light Level (lux)"", ""yaxis"": ""y2""}]", timestamp, temp, timestamp, lux),
        // Formatting options
        kwargs=http.jsonencode({
            filename=PLOTLY_FILENAME
            fileopt="extend"
            world_readable="true"
            layout={
                title="Electric Imp Temperature / Light Level Logger"
                xaxis={
                    title="Date"
                    type="date"
                    // Set autorange to false to use GRAPH_WINDOW setting
                    autorange=false
                    range=[format("%i000", timestamp - (GRAPH_WINDOW * 3600)), format("%i000", timestamp)]
                }
                yaxis={
                    title="Temperature (°F)",
                    side="left",
                    autorange=true,
                }
                yaxis2={
                    title="Illuminance (lux)",
                    side="right",
                    overlaying="y",
                    autorange=true,
                }
            }
        })
    }
    local query_encoded = http.urlencode(query);
    local request = http.post("https://plot.ly/clientresp", {}, query_encoded);
    local response = request.sendsync();
    local reply = http.jsondecode(response.body);
    // Display any responses we get from Plotly
    if (reply["message"] != "") {
        server.log(reply["message"]);
    }
    if (reply["warning"] != "") {
        server.log(reply["warning"]);
    }
    if (reply["error"] != "") {
        server.log(reply["error"]);
    }
    server.log("Graph available at " + reply.url);
}

// When we get data from the device, format it and send it to Plotly
device.on("data", function(data) {
    updatePlotly(data.temp, data.lux);
});
