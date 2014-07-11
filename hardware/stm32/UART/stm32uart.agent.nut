// STM32 microprocessor firmware updater agent
// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// GLOBALS AND CONSTS ----------------------------------------------------------
const BLOCKSIZE = 4096; // size of binary image chunks to send down to device
const DELAY_DONE_NOTIFICATION_BY = 0.1; // pause to let the device write the final chunk before ending download

enum filetypes {
    INTELHEX,
    BIN
}

hex_buffer <- "";
bin_buffer <- blob(2);
fetch_url <- "";
fw_ptr <- 0;
fw_len <- 0;
filetype <- null;
bin_ptr <- 0;
bin_len <- 0;
bytes_sent <- 0;

// FUNCTION AND CLASS DEFINITIONS ----------------------------------------------

// Helper: Parses a hex string and turns it into an integer
// Input: hexidecimal number as a string
// Return: number (integer)
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

// Helper: Compute the 1-byte modular sum of a line of Intel Hex
// Input: Line of Intel Hex (string)
// Return: modular sum (integer, 1-byte)
function modularsum(line) {
    local sum = 0x00
    for (local i = 0; i < line.len(); i+=2) {
        sum += hextoint(line.slice(i,i + 2));
    }
    return ((~sum + 1) & 0xff);
}

// Helper: Parse a buffer of hex into the bin_buffer
// Input: Intel Hex data (string)
// Return: None
//      (writes binary into bin_buffer)
function parse_hexfile(hex) {
    try {
        // line up are start at the point in the bin buffer we've already parsed up to
        bin_buffer.seek(bin_len);
        // make sure we have enough bin buffer to write in all the things we're going to parse
        // for (local i = bin_len; i < BLOCKSIZE; i++) bin_buffer.writen(0xFF, 'b');
        // bin_buffer.seek(bin_len);
        
        local from = 0, to = 0, line = "", offset = 0x00000000;
        do {
            if (to < 0 || to == null || to >= hex.len()) break;
            from = hex.find(":", to);
            
            if (from < 0 || from == null || from + 1 >= hex.len()) break;
            to = hex.find(":", from + 1);
            
            if (to < 0 || to == null || from >= to || to >= hex.len()) break;
            // make sure to strip nasty trailing \r\n
            line = rstrip(hex.slice(from + 1, to));
            //server.log(format("[%d,%d] => %s", from, to, line));
            
            if (line.len() > 10) {
                local len = hextoint(line.slice(0, 2));
                local addr = hextoint(line.slice(2, 6));
                local type = hextoint(line.slice(6, 8));
 
                // Ignore all record types except 00, which is a data record. 
                // Look out for 02 records which set the high order byte of the address space
                if (type == 0) {
                    // Normal data record
                //} else if (type == 4 && len == 2 && addr == 0 && line.len() > 12) {
                } else if (type == 4) {
                    //server.log(format("Type 4 Line, len %d, addr %08x, line len %d", len, addr, line.len()));
                    // Set the offset
                    offset = hextoint(line.slice(8, 12)); // << 16;
                    if (offset != 0) {
                        //server.log(format("Set offset to 0x%08X", offset));
                        //server.log(format("From: %d, To: %d",from,to));
                        // right now, we ignore offset changes and assume the full images will be contiguous!
                    }
                    continue;
                } else {
                    //server.log("Skipped: " + line)
                    continue;
                }
 
                // Read the data from 8 to the end (less the last checksum byte)
                for (local i = 8; i < (8 + (len * 2)); i += 2) {
                    local datum = hextoint(line.slice(i, i + 2));
                    bin_buffer.writen(datum, 'b')
                }
                
                // Checking the checksum would be a good idea but skipped for now
                local read = hextoint(line.slice(line.len() - 2, line.len()));
                local calc = modularsum(line.slice(0,line.len() - 2));
                if (read != calc) {
                    throw format("Hex File Checksum Error: %02x (read) != %02x (calc) [%s]", read, calc, line);
                }
            }
        } while (from != null && to != null && from < to);
        
        // Resize the raw hex buffer so that it starts at the next line we need to parse
        //server.log(format("Resizing Hex Buffer [%d to %d]",from,hex_buffer.len()));
        hex_buffer = hex_buffer.slice(from, hex_buffer.len());
        
        bin_len += (bin_buffer.tell() - bin_len);
        bin_buffer.seek(bin_ptr);
        //server.log(format("Done parsing chunk, %d bytes in bin buffer",bin_len));
        
        //server.log("Free RAM: " + (imp.getmemoryfree()/1024) + " kb")
        return true;
        
    } catch (e) {
        server.log(e)
        return false;
    }
}

function finish_dl() {
    device.send("dl_complete",0);
    server.log("Download complete");
    fetch_url = "";
    fw_ptr = 0;
    fw_len = 0;
    filetype = null;
    // reclaim memory
    hex_buffer = "";
    // intel hex parsing may not have been used, but clean up in case
    bin_ptr = 0;
    bin_len = 0;
    bin_buffer = blob(2);
    bytes_sent = 0;
}

function send_from_intelhex(dummy = 0) {
    if (bin_len > BLOCKSIZE) {
        bin_buffer.seek(bin_ptr,'b');
        // we have more than a full chunk of raw binary data to send to the device, so send it.
        device.send("push", bin_buffer.readblob(BLOCKSIZE));
        bytes_sent += BLOCKSIZE;
        // resize our local buffer of parsed data to contain only unsent data
        local parsed_bytes_left = bin_len - bin_buffer.tell();
        //server.log(format("Sent %d bytes, %d bytes remain in bin_buffer",bin_buffer.tell(),parsed_bytes_left));
        // don't need to seek, as we've just read up to the end of the chunk we sent
        local swap = bin_buffer.readblob(parsed_bytes_left);
        bin_buffer.resize(parsed_bytes_left);
        bin_buffer.seek(0,'b');
        bin_buffer.writeblob(swap);
        bin_buffer.seek(0,'b');
        bin_ptr = 0;
        bin_len = parsed_bytes_left;
        server.log(format("FW Update: Parsed %d/%d bytes, sent %d bytes",fw_ptr,fw_len,bytes_sent));
    } else {
        if (fw_ptr == fw_len) {
            if (bin_ptr == bin_len) {
                // We've already sent the last (partial) chunk; finishe the download
                finish_dl();
            } else {
                // there's nothing left to fetch on the server we're fetching from
                // just send what we have
                device.send("push", bin_buffer);
                bytes_sent += bin_buffer.len();
                server.log(format("FW Update: Parsed %d/%d bytes, sent %d bytes (Final block)",fw_ptr,fw_len,bytes_sent));
                bin_ptr = bin_len;
            }
        } else {
            // fetch more data from the remote server and parse it, then come back here to send it
            local bytes_left_remote = fw_len - fw_ptr;
            local buffersize = bytes_left_remote > BLOCKSIZE ? BLOCKSIZE : bytes_left_remote;
            //server.log(format("Fetching %d-%d",fw_ptr,fw_ptr + buffersize - 1));
            hex_buffer += http.get(fetch_url, { Range=format("bytes=%u-%u", fw_ptr, fw_ptr + buffersize - 1) }).sendsync().body;
            fw_ptr += buffersize;
            // this will parse the string right into bin_buffer
            parse_hexfile(hex_buffer);
            // go around again!
            send_from_intelhex();
        }
    }
}

function send_from_binary(dummy = 0) {
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
        buffer.writeblob(raw_buffer.readblob(buffersize));
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
device.on("pull", function(dummy) {
    if (filetype == filetypes.INTELHEX) {
        send_from_intelhex();
    } else {
        send_from_binary();
    }
});

// HTTP REQUEST HANDLER --------------------------------------------------------

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    
    if ("type" in req.query) {
        if (req.query.type == "hex" || req.query.type == "intel" || req.query.type == "intelhex") {
            filetype = filetypes.INTELHEX;
        } else if (req.query.type == "bin" || req.query.type == "binary") {
            filetype = filetypes.BIN;
        } else {
            res.send(400, "Invalid filetype (?type=[ hex | bin ])\n");
            return;
        }
    } else {
        server.log("No filetype given; defaulting to binary");
        filetype = filetypes.BIN;
    }
    
    if (req.path == "/push" || req.path == "/push/") {
        server.log("Agent received new firmware, starting update");
        fw_len = req.body.len();
        raw_buffer = blob(fw_len);
        raw_buffer.writestring(req.body);
        raw_buffer.seek(0,'b');
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