/*
The MIT License (MIT)

Copyright (c) 2013 Electric Imp

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


//------------------------------------------------------------------------------------------------------------------------------
hex <- "";
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
    /*
    server.log("Boundary = " + boundary);
    server.log("Headers start at = " + hstart);
    server.log("Body start at = " + bstart);
    server.log("Body finished at = " + fstart);
    */
    
    return req.body.slice(bstart, fstart);
}


//------------------------------------------------------------------------------------------------------------------------------
// Parses a hex string and turns it into an integer
function hextoint(str) {

    if (typeof str == "integer") {
        if (str >= '0' && str <= '9') {
            return (str - '0');
        } else {
            return (str - 'A' + 10);
        }
    } else {
        switch (str.len()) {
            case 2:
                return (hextoint(str[0]) << 4) + hextoint(str[1]);
            case 4:
                return (hextoint(str[0]) << 12) + (hextoint(str[1]) << 8) + (hextoint(str[2]) << 4) + hextoint(str[3]);
        }
    }
}


//------------------------------------------------------------------------------------------------------------------------------
// Parse the hex into an array of blobs
function program(hex) {
    
    try {
        local program = [];
        local program_line = null;
        local data = blob(128);
    
        local newhex = split(hex, ": ");
        for (local l = 0; l < newhex.len(); l++) {
            local line = strip(newhex[l]);
            if (line.len() > 10) {
                local len = hextoint(line.slice(0, 2));
                local addr = hextoint(line.slice(2, 6)) / 2; // Address space is 16-bit
                local type = hextoint(line.slice(6, 8));
                if (type != 0) continue;
                for (local i = 8; i < 8+(len*2); i+=2) {
                    local datum = hextoint(line.slice(i, i+2));
                    data.writen(datum, 'b')
                }
                local checksum = hextoint(line.slice(-2));
                
                // server.log(format("%s => %04X", line.slice(2, 6), addr))
                local tell = data.tell();
                
                data.seek(0)
                if (program_line == null) {
                    program_line = {};
                    program_line.len <- tell;
                    program_line.addr <- addr;
                    program_line.data <- data.readblob(tell);
                } else {
                    program_line.len = tell;
                    program_line.data = data.readblob(tell);
                }
                
                if (tell == data.len()) {
                    program.push(program_line);
                    program_line = null;
                    data.seek(0);
                }
            }
        }
        
        // Add whatever is left
        if (program_line != null) {
            program.push(program_line);
            program_line = null;
            data.seek(0);
        }
        
        device.send("burn", program)
        
    } catch (e) {
        server.log(e)
        return "";
    }
    
}


//------------------------------------------------------------------------------------------------------------------------------
// Handle the agent requests
http.onrequest(function (req, res) {
    // server.log(req.method + " to " + req.path)
    if (req.method == "GET") {
        res.send(200, html);
    } else if (req.method == "POST") {

        if ("content-type" in req.headers) {
            if (req.headers["content-type"].slice(0, 19) == "multipart/form-data") {
                hex = parse_hexpost(req, res);
                if (hex == "") {
                    res.header("Location", http.agenturl());
                    res.send(302, "HEX file uploaded");
                } else {
                    device.on("done", function(ready) {
                        res.header("Location", http.agenturl());
                        res.send(302, "HEX file uploaded");                        
                        server.log("Programming completed")
                        hex = "";
                    })
                    server.log("Programming started")
                    program(hex);
                }
            }
        }
    }
})


//------------------------------------------------------------------------------------------------------------------------------
// Handle the device coming online
device.on("ready", function(ready) {
    if (ready && hex != "") {
        program(hex);
    }
});


//------------------------------------------------------------------------------------------------------------------------------
// Handle the device finishing
device.on("done", function(done) {
    if (done) {
        hex = "";
    }
});
