// STM32 microprocessor firmware updater agent
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------

agent_buffer <- blob(2);
fetch_url <- "";
fetch_ptr <- 0;

// DEVICE CALLBACKS ------------------------------------------------------------

device.on("pull", function(buffersize) {
    if (fetch_url != "") {
        local buffer = blob(buffersize);
        buffer.writestring(http.get(fetch_url, { Range=format("bytes=%u-%u", fetch_ptr, fetch_ptr + buffersize) }).sendsync().body);
        device.send("push", buffer);
    } else {
        server.log(format("Device requested %d bytes",buffersize));
        device.send("push", agent_buffer.readblob(buffersize));
    }
});

device.on("fw_update_complete", function(success) {
    if (success) {
        server.log("FW Update Successfully Completed.");
    } else {
        server.log("FW Update Failed.");
    }
});

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

// HTTP REQUEST HANDLER --------------------------------------------------------

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    
    if (req.path == "/push" || req.path == "/push/") {
        server.log("Agent received new firmware, starting update");
        server.log(req.body.len());
        agent_buffer = blob(req.body.len());
        agent_buffer.writestring(req.body);
        agent_buffer.seek(0,'b');
        device.send("load_fw", agent_buffer.len());
        res.send(200, "OK");
    } else if (req.path == "/fetch" || req.path == "/fetch/") {
        local fw_len = 0;
        if ("url" in req.query) {
            fetch_url = req.query.url;
            fetch_ptr = 0;
        } else {
            res.send(400, "Request must include source url for image file");
        }
        // get the content-length header from the remote URL to determine the image size
        local resp = http.get(fetch_url, { Range=format("bytes=0-0") }).sendsync();
        foreach (key, value in resp.headers) {
            server.log(key+" : "+value);
        }
        if ("content-length" in resp.headers) {
            fw_len = split(resp.headers["content-range"],"/")[1].tointeger();
            server.log(format("Fetching new firmware (%d bytes) from %s",fw_len,fetch_url));
            device.send("load_fw", fw_len);
            res.send(200, "OK");
        } else {
            res.send(400, "No content-length header from "+fetch_url);
            return;
        }
    } else {
        // send a response to prevent request hang
        res.send(200, "OK");
    }
});
    
// MAIN ------------------------------------------------------------------------

server.log("Agent Started. Free Memory: "+imp.getmemoryfree());

// in case both device and agent just booted, give device a moment to initialize, then get info
imp.wakeup(0.5, function() {
    device.send("get_version",0);
    device.send("get_id",0);
});