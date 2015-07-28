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
    // "RIFF" (0x 52 49 46 46)
    // file size w/o RIFF header (4 bytes)
    // "WAVE" (0x 57 41 56 45)
    // "fmt " (0x 66 6d 74 d0)
    if (chunkID != "RIFF" || format != "WAVE" || buf.readstring(4) != "fmt ") {
        server.error("Incompatible headers");
        return false;
    }
    // get size of wave type format header
    // size of wave type format (2 byte type format + 4 byte sample rate + 
    //     4 byte bytes per sec + 2 byte block alignment + 2 byte bits per sample);
    //     wave type format size typically 16
    local fmtSize = buf.readn('i');
    server.log("format chunk size: "+fmtSize);
    local compressionType = buf.readn('w');
    
    // Check for mono/stereo
    params.numChannels = buf.readn('w');
    if (params.numChannels != 1 && params.numChannels != 2) {
        server.error("Invalid number of channels ("+params.numChannels+")");
        return false;
    }
    server.log("Channels: "+params.numChannels);
    // Check sample rate, skip ByteRate and BlockAlign
    params.sampleRate = buf.readn('i');
    server.log("Sample Rate: "+params.sampleRate);
    buf.seek(buf.tell() + 6);
    // Check # bits per sample
    local bitsPerSample = buf.readn('w');
    server.log("Bits Per Sample: "+bitsPerSample);
    if (bitsPerSample != 16) {
        server.error("Invalid number of bits per sample: "+bitsPerSample+" (must be 16)");
        return false;
    }
    // Examine data section
    // we assume RIFF header is 20 bytes, read format header size from RIFF header
    // we also assume data header comes next (RIFF spec doesn't guarantee chunk order)
    buf.seek(20 + fmtSize);
    server.log(buf.tell());
    if (buf.readstring(4) != "data") { 
        server.error("Failed to find data header");
        return false; 
    }
    params.wavSize = buf.readn('i');
    server.log("Audio portion size: " + params.wavSize);
    if (buf.len() - buf.tell() < params.wavSize) {
        server.error("WAV filesize mismatch");
        return false;
    }
    if (params.wavSize / params.numChannels > maxFileSize) {
        if (maxFileSize == 0) {
            server.error("Device hasn't reported flash size - is it online?");
        } else {
            server.error("WAV file too big to fit on flash");
        }
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
    server.log("Got request");
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
    } else if (req.path == "/formUrl") {
        // Arbitrary limit on the URL length to keep things friendly
        if (req.body.len() > 2048) {
            server.log("Fetch URL too long\n");
            res.send(500, "Fetch URL too long\n");
            return;
        }
        local fetchURL = http.urldecode(req.body).url;
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
        server.log("No path, responding with webpage");
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