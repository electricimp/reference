// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// WIF Import and Conversion for ePaper Displays

const HEIGHT = 96;
const WIDTH = 96;
const DEF_URL = "https://raw.githubusercontent.com/electricimp/reference/master/hardware/Sharp_LSxxxBx/wif_example/doge.wif";

// html code for WIF upload user interface
html <- @"
<html>
    <head>
        <title>Upload WIF file</title>
    </head>
    <body>
        <form method='POST' action='%s/uploadWIF' enctype='multipart/form-data'>
            Select a WIF file to upload:<br />
            <input type=file name=wiffile><br />
            <input type=submit value=Upload>
        </form>
    </body>
</html>";


// Takes WIF file, checks for validity and converts it for display
// Input: WIF file data (blob)
// Return: (none)
function processWIF(imageData) {
    local imageHeight = (imageData[1] << 8) | imageData[0];
    local imageWidth = (imageData[3] << 8) | imageData[2];
    local screenBytes = WIDTH * HEIGHT / 8;
    if (imageWidth == WIDTH && imageHeight == HEIGHT && imageData.len() - 4 == screenBytes) {
        server.log("Received valid WIF.");
        local displayData = blob(screenBytes);
        for (local i = 4; i < imageData.len(); i++) {
            displayData.writen(imageData[i] ^ 0xFF, 'b');
        }
        device.send("displayData", displayData);
    } else {
        throw "WIF Dimensions must match code specifications";
    }
}

// Gets WIF file from url and processes it
// If the url is null it uses a default url
// Input: url that links to a wif file (string)
// Return: (none)
function getWIF(url = null) {
    if (url == null) {
        url = DEF_URL;
    }
    local req = http.get(url).sendsync();
    local imageData = req.body;
    processWIF(imageData);
}

// Parses a HTTP POST in multipart/form-data format
// Input: http request and response (http)
// Return: parsed body (blob)
function parse_hexpost(req, res) {
    local boundary = req.headers["content-type"].slice(30);
    local bindex = req.body.find(boundary);
    local hstart = bindex + boundary.len();
    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
    local fstart = req.body.find(boundary + "--", bstart) - 4;
    return req.body.slice(bstart, fstart);
}

// Http request that handles http user interface requests
// Input: http request and response (http)
// Return: (none)
http.onrequest(function(req, res) {
    res.send(200, format(html, http.agenturl()));
    if (req.method == "GET") {
        res.send(200, html);
    } else if (req.method == "POST") {
        if (req.path == "/uploadWIF" || req.path == "/uploadWIF/") {
            if ("content-type" in req.headers) {
                if (req.headers["content-type"].len() >= 19
                && req.headers["content-type"].slice(0, 19) == "multipart/form-data") {
                    local data = parse_hexpost(req, res);
                    processWIF(data);
                }
            }
        } else if (req.path == "/WIFimage") {
            local data = req.body;
            processWIF(data);
        }
    }
});

device.on("getImage", getWIF);