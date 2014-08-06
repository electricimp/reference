
agentbuffer <- blob(65536); // 64K buffer

device.on("start", function(dummy) {
    agentbuffer.seek(0,'b');
});

device.on("chunk", function(chunk) {
    server.log("Downloaded: "+((chunk.idx + 1)*chunk.buffer.len()+" bytes"));
    agentbuffer.seek(chunk.idx * chunk.buffer.len());
    agentbuffer.writeblob(chunk.buffer);
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (req.path == "/dl") {
        server.log("Serving Agent Buffer");
        res.send(200, agentbuffer);
    } else if (req.path == "/dump") {
        device.send("dump",0);
        res.send(200, "Dumping EEPROM");
    } else if (req.path == "/program") {
        local img = req.body;
        server.log(format("Sending %d byte image to device",img.len()));
        device.send("program", img);
        res.send(200, "OK");
    } else {
        // send a response to prevent browser hang
        res.send(200, "No Action");
    }
});
