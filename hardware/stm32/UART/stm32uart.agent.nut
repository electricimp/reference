// STM32 microprocessor firmware updater agent
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------
const BLOCKSIZE = 4096; // size of binary image chunks to send down to device

agent_buffer <- blob(2);
fetch_url <- "";
fw_ptr <- 0;
fw_len <- 0;
filetype <- null;

// FUNCTION AND CLASS DEFINITIONS ----------------------------------------------

function finish_dl() {
    device.send("dl_complete",0);
    server.log("Download complete");
    fetch_url = "";
    fw_ptr = 0;
    fw_len = 0;
    filetype = null;
}

function send_data(dummy) {
    local bytes_left_total = fw_len - fw_ptr;
    local buffersize = bytes_left_total > BLOCKSIZE ? BLOCKSIZE : bytes_left_total;
    
    // check and see if we've finished the download
    if (buffersize == 0) {
        finish_dl();
        return;
    } 
    
    local buffer = blob(buffersize);
    // if we're fetching a remote file in chunks, go get another
    if (fetch_url != "") {
        // download still in progress
        buffer.writestring(http.get(fetch_url, { Range=format("bytes=%u-%u", fw_ptr, fw_ptr + buffersize - 1) }).sendsync().body);
    // we're sending chunks of file from memory
    } else {
        buffer.writeblob(agent_buffer.readblob(buffersize));
    }
    
    device.send("push",buffer);
    fw_ptr += buffersize;
    server.log(format("FW Update: Sent %d/%d bytes",fw_ptr,fw_len));
}

// DEVICE CALLBACKS ------------------------------------------------------------

// Allow the device to inform us of its bootloader version and supported commands
// This agent doesn't use this for anything; this method is here as an example
device.on("set_version", function(data) {
    server.log("Device Bootloader Version: "+data.bootloader_version);
    local supported_cmds_str = ""; 
    foreach (cmd in data.supported_cmds) {
        supported_cmds_str += format("%02x ",cmd);
    }
    server.log("Bootloader supports commands: " + supported_cmds_str);
});

// Allow the device to inform the agent of its product ID (PID)
// This agent doesn't use this for anything; this method is here as an example
device.on("set_id", function(id) {
    // use the GET_ID command to get the PID
    server.log("STM32 PID: "+id);
});

// Serve a buffer of new image data to the device upon request
device.on("pull", send_data);

// HTTP REQUEST HANDLER --------------------------------------------------------

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    
    if (req.path == "/push" || req.path == "/push/") {
        server.log("Agent received new firmware, starting update");
        fw_len = req.body.len();
        agent_buffer = blob(fw_len);
        agent_buffer.writestring(req.body);
        agent_buffer.seek(0,'b');
        device.send("load_fw", fw_len);
        res.send(200, "OK\n");
    } else if (req.path == "/fetch" || req.path == "/fetch/") {
        fw_len = 0;
        if ("url" in req.query) {
            fetch_url = req.query.url;
            fw_ptr = 0;
            // get the content-length header from the remote URL to determine the image size
            local resp =  http.request("HEAD", fetch_url, {}, "").sendsync();
            if ("content-length" in resp.headers) {
                res.send(200, "OK\n");
                fw_len = resp.headers["content-length"].tointeger();
                device.send("load_fw", fw_len);
                server.log(format("Fetching new firmware (%d bytes) from %s",fw_len,fetch_url));
                foreach (key, value in resp.headers) {
                    server.log(key+" : "+value);
                }
            } else {
                res.send(400, "No content-length header from "+fetch_url+"\n");
                return;
            }
        } else {
            res.send(400, "Request must include source url for image file\n");
        }
    } else if (req.path == "/erase" || req.path == "/erase/") {
        res.send(200, "OK\n");
        device.send("erase", 0);
    } else {
        // send a response to prevent request hang
        res.send(200, "OK\n");
    }
});
    
// MAIN ------------------------------------------------------------------------

server.log("Agent Started. Free Memory: "+imp.getmemoryfree());

// in case both device and agent just booted, give device a moment to initialize, then get info
imp.wakeup(0.5, function() {
    device.send("get_version",0);
    device.send("get_id",0);
});