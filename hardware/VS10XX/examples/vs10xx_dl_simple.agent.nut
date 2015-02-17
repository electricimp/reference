// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Description: Example using VS10XX with AudioDownloader Class

/* GLOBALS AND CONSTS --------------------------------------------------------*/

/* FUNCTION AND CLASS DEFS ---------------------------------------------------*/

class AudioDownloader {
    
    static QUEUE_DEPTH  = 5;
    static CHUNK_SIZE   = 8192;
    
    download_url        = "";
    download_offset     = 0;
    download_len        = 0;
    download_done       = 0;
    sent_to_device_offset = 0;
    download_buffer     = null;

    constructor() {
        init();
    }
    
    function init() {
        download_buffer = blob(CHUNK_SIZE);
        // hook up a callback for the device to pull more data from the downloader
        device.on("pull", function(dummy) {
            if (!download_done) sendNextChunk();
        }.bindenv(this));
    }
    
    function setDownloadURL(url) {
        download_url = url;
    }
    
    function getHeaders(url) {
        response <- http.get(url, { Range = "bytes=0-1" }).sendsync();
        return response.headers;
    }
    
    function downloadChunk(cb) {
        local bytes_to_download = download_len - download_offset;
        local bytes_in_chunk = 0;
        
        if (bytes_to_download == 0) {
            // End of file
            download_done = true;
            finish();
            // don't call the callback; we're done.
            return;
        } else if (bytes_to_download >= CHUNK_SIZE) {
            bytes_in_chunk = CHUNK_SIZE;
        } else {
            bytes_in_chunk = bytes_to_download;
        }
        
        //server.log(format("Requesting bytes %d to %d", download_offset, download_offset + bytes_in_chunk - 1));
        local response = http.get(download_url, 
            {Range = format("bytes=%u-%u",download_offset, download_offset + bytes_in_chunk - 1)}
        ).sendsync();
        // overwrite the download buffer with a new chunk from the remote file
        download_buffer.seek(0,'b');
        local receivedLen = response.body.len();
        server.log(format("Fetched %d bytes from %s (%d total)", receivedLen, download_url, download_offset + receivedLen));
        // resize the buffer so we don't have leftover data at the end if this chunk
        // is shorter than the last one
        download_buffer.resize(receivedLen);
        download_buffer.writestring(response.body);
        download_buffer.seek(0,'b');
        download_offset += receivedLen;
        // download buffer refilled; call the callback
        cb();
    }
    
        function sendNextChunk() {
        local leftIndownload_buffer = download_buffer.len() - download_buffer.tell();
        if (leftIndownload_buffer == 0) {
            downloadChunk(sendNextChunk);
        } else if (leftIndownload_buffer < CHUNK_SIZE) {
            device.send("push",download_buffer.readblob(leftIndownload_buffer));
        } else {
            device.send("push",download_buffer.readblob(CHUNK_SIZE));
        }
        //server.log(format("%d bytes sent to device (chunk size %d)",
        //    download_offset + download_buffer.tell(),
        //    leftIndownload_buffer > CHUNK_SIZE ? CHUNK_SIZE : leftIndownload_buffer));
    }
    
    function finish() {
        download_done = true;
        download_offset = 0;
        sent_to_device_offset = 0;
        download_buffer.seek(0,'b');
        download_buffer.resize(CHUNK_SIZE);
        server.log("Finished sending file to device, memory free: "+imp.getmemoryfree());
    }
    
    function start() {
        download_done = false;
        download_offset = 0;
        sent_to_device_offset = 0;
        download_buffer.seek(0,'b');
        download_len = split(getHeaders(download_url)["content-range"],"/")[1].tointeger();
        server.log(format("Will download %d bytes from %s", download_len, download_url));
        downloadChunk(function() {
            for (local i = 0; i < QUEUE_DEPTH; i++) {
                sendNextChunk();
            }    
        }.bindenv(this));
    }
}

/* RUNTIME START -------------------------------------------------------------*/

downloader <- AudioDownloader();

http.onrequest(function(req, res) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    req.path = req.path.tolower();
    if (req.path == "/fetch") {
        downloader.setDownloadURL(req.body);
        res.send(200, "OK\n");
        downloader.start();
    } else {
        res.send(200, "OK\n");
    }
});

server.log("Restarted. Memory Free: "+imp.getmemoryfree());
