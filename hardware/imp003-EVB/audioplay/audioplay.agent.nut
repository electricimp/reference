// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Static web page for linking / uploading an audio file
const html = @"<!DOCTYPE html>
<html>
<head>
<title>imp003 Audio Playback Example</title>
<!-- <link rel=""stylesheet"" href=""https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css""> -->
<link rel=""stylesheet"" href="""">

</head>
<body>
<form method=""POST"" action=""%s/formUrl"">
Submit the URL of a 16-bit PCM WAV file below:<br>
<input type=""url"" name=""url""><input type=""submit"" value=""Fetch"">
</form>
</body>
</html>
"

// Constants & Globals
const WAV_HEADER_SIZE = 44; // Number of bytes in a WAV file header (for PCM encoding)

maxFileSize <- 0;           // Flash storage size (reported by device)
chunkSize   <- 0;
buf <- null;                // Buffer for user-supplied audio
params <- {
    wavSize     = null,     // Length of audio (bytes)
    numChannels = null,     // Number of channels (we only use one either way)
    sampleRate  = null
}

// Convert signed to unsigned, stereo to mono (if necessary)
// and remove WAV header
function getRawAudio() { 
    server.log("Extracting raw audio...");
    local temp = null;
    local end = WAV_HEADER_SIZE + params.wavSize;
    local stereo = params.numChannels == 2 ? true : false;
    local w = 0;

    for (local r = WAV_HEADER_SIZE; r < end; r += 2) {
        buf.seek(r);                    // Seek to read pointer
        temp = buf.readn('s') + 32768;  // Read sample and convert to unsigned
        // If stereo, scale each channel to 1/2 and sum them
        if (stereo) {
            temp = temp/2 + (buf.readn('s')+32768)/2;
            r += 2;
        }
        buf.seek(w);                    // Seek to write pointer
        buf.writen(temp, 'w');          // Write sample
        w += 2;                         // Increment write pointer
    }

    // Shrink buffer to match size of audio data
    params.wavSize = params.wavSize / params.numChannels;
    buf.resize(params.wavSize);
}

// This function examines the user-submitted file to make sure it is a valid WAV
// It will fail on any discrepancy or unsupported format
// We can play 16-bit PCM 1-2 channel (mono/stereo) audio
// Sample rate is minimum 8KHz, with no upper limit (apart from flash size)
function processWAV(wav) {
    buf = blob(wav.len());
    buf.writestring(wav);
    buf.seek(0);

    local chunkID = buf.readstring(4);
    local filesize = buf.readn('i');
    local format = buf.readstring(4);
    server.log("Total filesize: " + filesize);

    // Check required headers for a PCM WAV
    if (chunkID != "RIFF" || format != "WAVE" || buf.readstring(4) != "fmt "
            || buf.readn('i') != 16 || buf.readn('w') != 1) {
        return false;
    }
    // Check for mono/stereo
    params.numChannels = buf.readn('w');
    if (params.numChannels != 1 && params.numChannels != 2) {
        server.error("Invalid number of channels");
        return false;
    }
    // Check sample rate, skip ByteRate and BlockAlign
    params.sampleRate = buf.readn('i');
    buf.seek(buf.tell() + 6);
    // Check # bits per sample
    if (buf.readn('w') != 16) {
        server.error("Invalid number of bits per sample.");
        return false;
    }
    // Examine data section
    if (buf.readstring(4) != "data") { return false; }
    params.wavSize = buf.readn('i');
    server.log("Audio portion size: " + params.wavSize);
    if (buf.len() - buf.tell() < params.wavSize) {
        server.error("WAV filesize mismatch");
        return false;
    }
    if (params.wavSize / params.numChannels > maxFileSize) {
        server.error("WAV file too big to fit on flash");
        return false;
    }
    // Strip headers, perform necessary conversions, and send to device
    getRawAudio();
    device.send("newAudio", params);
    return true;
}

// Send a chunk of audio to the device
function sendChunk(index) {
    buf.seek(index * chunkSize);
    local bytesRemaining = buf.len() - buf.tell();
    if (bytesRemaining < chunkSize) {
        device.send("chunk", buf.readblob(bytesRemaining));
    } else {
        device.send("chunk", buf.readblob(chunkSize));
    }
}

// Callback for the HEAD request
// Checks the size of the WAV file to be fetched
// If it's not too big, fetches it and hands it off to processWav()
function fetchAudio(url, res, headRes) {
    if ("content-length" in headRes.headers) {
        local size = headRes.headers["content-length"].tointeger();
        server.log("Size of WAV file: " + size);
        if (size < imp.getmemoryfree()*0.9) {
            http.get(url).sendasync(function(getRes) {
                if (processWAV(getRes.body)) {
                    res.send(200, "Fetched valid WAV file\n");
                } else {
                    res.send(500, "Fetch failed: invalid WAV file\n");
                }
            });
        } else {
            res.send(500, "WAV file too large\n");
        }
    } else {
        res.send(500, "Error retrieving WAV file\n");
    }
}

// HTTP request handler
// We allow uploading WAV data directly (/play)
// as well as submitting a URL via curl (/url) or a web form (/formUrl) from which to fetch the WAV
http.onrequest(function(req, res) {
    // Make sure we know the flash size of the device
    if (!maxFileSize || !chunkSize) {
        device.send("getConfig", 1);
    }
    // Receive WAV file directly as POST data
    if (req.path == "/play") {
        if (req.body.len() >= WAV_HEADER_SIZE && processWAV(req.body)) {
            res.send(200, "Received valid WAV file.\n");
        } else {
            res.send(500, "Invalid WAV file!\n");
        }
    // Fetch the WAV from a given URL
    } else if (req.path == "/url" || req.path == "/formUrl") {
        // Arbitrary limit on the URL length to keep things friendly
        if (req.body.len() > 2048) {
            res.send(500, "Fetch URL too long\n");
            return;
        }
        local fetchURL = req.body;
        // If this was a form submission, we need to decode the data
        if (req.path == "/formUrl") {
            fetchURL = http.urldecode(fetchURL).url;
        }
        // First, we get the filesize using a HEAD request to make sure it's not too big
        // And then we handle the response in fetchAudio()
        server.log("Fetching WAV file from " + fetchURL);
        try {
            local headReq = http.request("HEAD", fetchURL, {}, "");
            headReq.sendasync(function(headRes) { fetchAudio(fetchURL, res, headRes); });
        } catch (err) {
            server.error("Error retrieving WAV file: " + err);
            res.send(500, "Error retrieving WAV file");
        }
    } else {
        // Serve the page with the URL-submission form
        res.send(200, format(html, http.agenturl()));
    }
});

// Device callbacks
// Receive filesize parameters
device.on("config", function(config) {
    maxFileSize = config.maxFileSize;
    chunkSize = config.chunkSize;
});
// When requested, send a chunk of audio
device.on("getChunk", sendChunk);

server.log(format("Agent started. Free memory: %d bytes", imp.getmemoryfree()));