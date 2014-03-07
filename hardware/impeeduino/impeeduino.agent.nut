/*
The MIT License (MIT)

Copyright (c) 2014 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/


server.log("Agent started, URL is " + http.agenturl());

const MAX_PROGRAM_SIZE = 0x20000;
const ARDUINO_BLOB_SIZE = 128;
program <- null;


//------------------------------------------------------------------------------------------------------------------------------
html <- @"<HTML>
<BODY>

<form method='POST' enctype='multipart/form-data'>
Program the ATmega328 via the Imp.<br/><br/>
Step 1: Select an Intel HEX file to upload: <input type=file name=hexfile><br/>
Step 2: <input type=submit value=Press> to upload the file.<br/>
Step 3: Check out your impeeduino<br/>
</form>

</BODY>
</HTML>
";



//------------------------------------------------------------------------------------------------------------------------------
// Parses a HTTP POST in multipart/form-data format
function parse_hexpost(req, res) {
    local boundary = req.headers["content-type"].slice(30);
    local bindex = req.body.find(boundary);
    local hstart = bindex + boundary.len();
    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
    local fstart = req.body.find("\r\n\r\n--" + boundary + "--", bstart);
    return req.body.slice(bstart, fstart);
}


//------------------------------------------------------------------------------------------------------------------------------
// Parses a hex string and turns it into an integer
function hextoint(str) {
    local hex = 0x0000;
    foreach (ch in str) {
        local nibble;
        if (ch >= '0' && ch <= '9') {
            nibble = (ch - '0');
        } else {
            nibble = (ch - 'A' + 10);
        }
        hex = (hex << 4) + nibble;
    }
    return hex;
}


//------------------------------------------------------------------------------------------------------------------------------
// Breaks the program into chunks and sends it to the device
function send_program() {
    if (program != null && program.len() > 0) {
        local addr = 0;
        local pline = {};
        local max_addr = program.len();
        
        device.send("burn", {first=true});
        while (addr < max_addr) {
            program.seek(addr);
            pline.data <- program.readblob(ARDUINO_BLOB_SIZE);
            pline.addr <- addr / 2; // Address space is 16-bit
            device.send("burn", pline)
            addr += pline.data.len();
        }
        device.send("burn", {last=true});
    }
}        

//------------------------------------------------------------------------------------------------------------------------------
// Parse the hex into an array of blobs
function parse_hex(hex) {
    
    try {
        
        // Prepare a large buffer for the entire program
        program = blob(MAX_PROGRAM_SIZE);
        for (local i = 0; i < MAX_PROGRAM_SIZE; i++) program.writen(0, 'b');
        
        local max_tell = 0;
        local newhex = split(hex, ": ");
        for (local l = 0; l < newhex.len(); l++) {
            local line = strip(newhex[l]);
            if (line.len() > 10) {
                local len = hextoint(line.slice(0, 2));
                local addr = hextoint(line.slice(2, 6));
                local type = hextoint(line.slice(6, 8));
                local checksum = hextoint(line.slice(-2));
                
                if (type != 0) continue;

                // Grab each of the data bytes
                program.seek(addr);
                for (local i = 8; i < 8+(len*2); i+=2) {
                    local datum = hextoint(line.slice(i, i+2));
                    program.writen(datum, 'b')
                    
                    // Keep track of where we are up to
                    if (program.tell() > max_tell) max_tell = program.tell();
                }
            }
        }

        // All finished, trim it down to size
        program.seek(0);
        program.resize(max_tell);
        
        // Now send it
        send_program();
        
    } catch (e) {
        server.log(e)
    }
    
}


//------------------------------------------------------------------------------------------------------------------------------
// Handle the agent requests
http.onrequest(function (req, res) {
    // return res.send(400, "Bad request");
    // server.log(req.method + " to " + req.path)
    if (req.method == "GET") {
        res.send(200, html);
    } else if (req.method == "POST") {

        if ("content-type" in req.headers) {
            if (req.headers["content-type"].len() >= 19
             && req.headers["content-type"].slice(0, 19) == "multipart/form-data") {
                local hex = parse_hexpost(req, res);
                if (hex == "") {
                    res.header("Location", http.agenturl());
                    res.send(302, "HEX file uploaded");
                } else {
                    device.on("done", function(ready) {
                        res.header("Location", http.agenturl());
                        res.send(302, "HEX file uploaded");                        
                        server.log("Programming completed")
                    })
                    server.log("Programming started")
                    parse_hex(hex);
                }
            } else if (req.headers["content-type"] == "application/json") {
                local json = null;
                try {
                    json = http.jsondecode(req.body);
                } catch (e) {
                    server.log("JSON decoding failed for: " + req.body);
                    return res.send(400, "Invalid JSON data");
                }
                local log = "";
                foreach (k,v in json) {
                    if (typeof v == "array" || typeof v == "table") {
                        foreach (k1,v1 in v) {
                            log += format("%s[%s] => %s, ", k, k1, v1.tostring());
                        }
                    } else {
                        log += format("%s => %s, ", k, v.tostring());
                    }
                }
                server.log(log)
                return res.send(200, "OK");
            } else {
                return res.send(400, "Bad request");
            }
        } else {
            return res.send(400, "Bad request");
        }
    }
})


//------------------------------------------------------------------------------------------------------------------------------
// Handle the device coming online
device.on("ready", function(ready) {
    if (ready) send_program();
});


