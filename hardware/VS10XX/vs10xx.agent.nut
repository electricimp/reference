
const QUEUE_DEPTH = 5; // number of packets to send to device without backpressure
const CHUNK_SIZE = 8192;

downloadURL <- "";
downloadOffset <- 0;
downloadLen <- 0;
downloadDone <- false;
sentToDeviceOffset <- 0;
downloadBuffer <- blob(CHUNK_SIZE);

function getHeaders(url) {
    response <- http.get(url, { Range = "bytes=0-1" }).sendsync();
    return response.headers;
}

function downloadChunk(cb) {
    local bytesToDownload = downloadLen - downloadOffset;
    local bytesInChunk = 0;
    
    if (bytesToDownload == 0) {
        // End of file
        downloadDone = true;
        finishDownload();
        // don't call the callback; we're done.
        return;
    } else if (bytesToDownload >= CHUNK_SIZE) {
        bytesInChunk = CHUNK_SIZE;
    } else {
        bytesInChunk = bytesToDownload;
    }
    
    //server.log(format("Requesting bytes %d to %d", downloadOffset, downloadOffset + bytesInChunk - 1));
    local response = http.get(downloadURL, 
        {Range = format("bytes=%u-%u",downloadOffset, downloadOffset + bytesInChunk - 1)}
    ).sendsync();
    // overwrite the download buffer with a new chunk from the remote file
    downloadBuffer.seek(0,'b');
    local receivedLen = response.body.len();
    server.log(format("Fetched %d bytes from %s (%d total)", receivedLen, downloadURL, downloadOffset + receivedLen));
    // resize the buffer so we don't have leftover data at the end if this chunk
    // is shorter than the last one
    downloadBuffer.resize(receivedLen);
    downloadBuffer.writestring(response.body);
    downloadBuffer.seek(0,'b');
    downloadOffset += receivedLen;
    // download buffer refilled; call the callback
    cb();
}

function startDownload() {
    downloadDone = false;
    downloadOffset = 0;
    sentToDeviceOffset = 0;
    downloadBuffer.seek(0,'b');
    downloadLen = split(getHeaders(downloadURL)["content-range"],"/")[1].tointeger();
    server.log(format("Will download %d bytes", downloadLen));
    downloadChunk(function() {
        for (local i = 0; i < QUEUE_DEPTH; i++) {
            sendNextChunk();
        }    
    });
}

function sendNextChunk() {
    local leftInDownloadBuffer = downloadBuffer.len() - downloadBuffer.tell();
    if (leftInDownloadBuffer == 0) {
        downloadChunk(sendNextChunk);
    } else if (leftInDownloadBuffer < CHUNK_SIZE) {
        device.send("push",downloadBuffer.readblob(leftInDownloadBuffer));
    } else {
        device.send("push",downloadBuffer.readblob(CHUNK_SIZE));
    }
    //server.log(format("%d bytes sent to device (chunk size %d)",
    //    downloadOffset + downloadBuffer.tell(),
    //    leftInDownloadBuffer > CHUNK_SIZE ? CHUNK_SIZE : leftInDownloadBuffer));
}

function finishDownload() {
    downloadDone = true;
    device.send("dl_done", 0);
    downloadOffset = 0;
    sentToDeviceOffset = 9;
    downloadBuffer.seek(0,'b');
    downloadBuffer.resize(CHUNK_SIZE);
    server.log("Finished sending file to device, memory free: "+imp.getmemoryfree());
}

device.on("pull", function(dummy) {
    if (!downloadDone) sendNextChunk();
});

http.onrequest(function(req, res) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    req.path = req.path.tolower();
    if (req.path == "/fetch") {
        downloadURL = req.body;
        res.send(200, "OK\n");
        server.log(format("Starting download from %s",downloadURL));
        startDownload();
    } else {
        res.send(200, "OK\n");
    }
});

server.log("Restarted. Memory Free: "+imp.getmemoryfree());
