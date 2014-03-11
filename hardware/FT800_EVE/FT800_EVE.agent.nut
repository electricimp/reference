// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const DISPWIDTH     = 480;
const DISPHEIGHT    = 272;

// bitmap header parameters
const BI_BITFIELDS  = 3;
// FT800 bitmap format codes
const ARGB1555      = 0;
const L1            = 1;
const L4            = 2;
const L8            = 3;
const RGB332        = 4;
const ARGB2         = 5;
const ARGB4         = 6;
const RGB565        = 7;
const PALETTED      = 8;

function sendBmp(bmpdata, handle) {
    local bmpheader = {};
    
    // Read the BMP Header
    bmpheader.bmptype       <- format("%c%c",bmpdata.readn('b'),bmpdata.readn('b'));
    bmpheader.filesize      <- bmpdata.readn('i');
    bmpdata.seek(0x0A,'b');
    bmpheader.pxoffset      <- bmpdata.readn('i');
    
    
    // Read the DIB header, which (probably) immediately follows the BMP Header
    local headersize        =  bmpdata.readn('i');
    bmpheader.width         <- bmpdata.readn('i');
    bmpheader.height        <- bmpdata.readn('i');
    bmpheader.colorplanes   <- bmpdata.readn('w');
    bmpheader.bitsperpx     <- bmpdata.readn('w');
    bmpheader.compression   <- bmpdata.readn('i');
    bmpheader.imgsize       <- bmpdata.readn('i');
    if (bmpheader.imgsize == 0) {
        bmpheader.imgsize = ((bmpheader.width * bmpheader.height) * bmpheader.bitsperpx);
    }
    bmpheader.hres          <- bmpdata.readn('i');
    bmpheader.vres          <- bmpdata.readn('i');
    bmpheader.colors        <- bmpdata.readn('i');
    bmpheader.impcolors     <- bmpdata.readn('i');
    if (bmpheader.compression == BI_BITFIELDS) {
        bmpheader.rmask     <- bmpdata.readn('i');
        bmpheader.gmask     <- bmpdata.readn('i');
        bmpheader.bmask     <- bmpdata.readn('i');
        bmpheader.amask     <- bmpdata.readn('i');
        
        server.log(format("rmask: 0x%08x",bmpheader.rmask));
        server.log(format("gmask: 0x%08x",bmpheader.gmask));
        server.log(format("bmask: 0x%08x",bmpheader.bmask));
        server.log(format("amask: 0x%08x",bmpheader.amask));
    }
    
    server.log(format("Bits per px: %d",bmpheader.bitsperpx));
    
    
    // do a couple calcuations here (where it's faster) to simplify things for the device
    // Calculate the linestride (offset between scan lines)
    bmpheader.stride        <- 4 * ((bmpheader.width * (bmpheader.bitsperpx / 8) + 3) / 4);
    // determine the format code word for the FT800
    if (bmpheader.bitsperpx == 1) {
        bmpheader.format <- L1;   
    } else if (bmpheader.bitsperpx == 2) {
        // unsupported
        server.error("Two-byte-per-pixel encoding not supported.");
        return 1;
    } else if (bmpheader.bitsperpx == 4) {
        bmpheader.format <- L4;
    } else if (bmpheader.bitsperpx == 8) {
        if (bmpheader.compression == BI_BITFIELDS) {
            if (bmpheader.amask == 0) {
                bmpheader.format <- RGB332;
            } else {
                bmpheader.format <- ARGB2;
            }
        } else {
            bmpheader.format <- L8;
        }
    } else if (bmpheader.bitsperpx == 16) {
        if (bmpheader.compression == BI_BITFIELDS) {
            if (bmpheader.amask == 0x00) {
                bmpheader.format <- RGB565;
            } else if (bmpheader.amask == 0x8000) {
                bmpheader.format <- ARGB1555;
            } else {
                bmpheader.format <- ARGB4;
            }
        } else {
            bmpheader.format <- RGB565;
        }
    } else if (bmpheader.bitsperpx == 24) {
        server.error("Two-byte-per-pixel encoding not supported.");
        return 1;
    } else { // assume 32 bits per px
        bmpheader.format <- PALETTED;
    }
    
    server.log("header format code: "+bmpheader.format);
   
    // read the pixel field into a separate blob to make things simpler device-side
    // The FT800 appears to be unaware that windows BMPs are drawn upside-down, so 
    // fix that so this is right-side up.
    local imgdata = blob(bmpheader.imgsize);
    local endofdata = bmpheader.pxoffset+bmpheader.imgsize;
    local bytesperrow = (bmpheader.bitsperpx * bmpheader.width)/8;
    local position = endofdata-bytesperrow;
    bmpdata.seek(position,'b');
    for (local i = 0; i < bmpheader.height; i++) {
        imgdata.writeblob(bmpdata.readblob(bytesperrow));
        position -= bytesperrow;
        bmpdata.seek(position,'b');
    }
    
    //bmpdata.seek(bmpheader.pxoffset,'b');
    //local imgdata = bmpdata.readblob(bmpheader.imgsize);

    // Send the parsed header and raw file
    device.send("loadbmp", {"bmpheader":bmpheader,"bmpdata":imgdata,"handle":handle} );

    server.log(format("Parsed BMP, %d x %d px", bmpheader.width, bmpheader.height));
}

function sendJpg(jpgdata, handle) {
    device.send("loadjpg", {"jpgdata":jpgdata,"handle":handle});
}

// get a four-byte string from a blob. Handy for starting a word search in a PNG blob.
function getWord(sourcedata) {
    //server.log("Preloading a word from "+sourcedata.tell());
    local word = "";
    for (local i = 0; i < 4; i++) {
        if (sourcedata.eos()) { 
            server.error("Hit end of PNG data while preparing for a search.");
            return -1; 
        }
        word += format("%c", sourcedata.readn('b'));
    }
    return word;
}

// search for a four-byte string in a blob of data
function findword(targetword, sourcedata) {
    //server.log("Looking for "+targetword);
    local word = getWord(sourcedata);
    //server.log("pointer moved to "+sourcedata.tell());
    
    if (word == -1) { return -1; }
    
    while (word != targetword) {
        if (sourcedata.eos()) {
            server.error("Unable to find chunk in PNG file: "+targetword);
            return -1;
        }
        word = word.slice(1,4);
        word += format("%c", sourcedata.readn('b'));
    }
    
    //server.log("Found "+targetword+" chunk at "+(sourcedata.tell() - 4));
    return sourcedata.tell() - 4;
}

function sendPng(pngdata, handle, format, bitsperpx, width, height) {
    device.send("loadpng", {"pngdata":pngdata,"handle":handle,"format":format,
        "bitsperpx":bitsperpx,"width":width,"height":height});
}

http.onrequest(function(req, resp) {
    try {
        local handle = 0;
        if ("handle" in req.query) {
            handle = req.query["handle"].tointeger();
            server.log("Graphics Handle set to "+handle);
        }
        if ("bmp" in req.query) {
            sendBmp(http.base64decode(req.body),handle);
        } else if ("jpg" in req.query) {
            server.log("Got new JPEG");
            sendJpg(http.base64decode(req.body),handle);
        } else if ("png" in req.query) {
            server.log("Got new PNG");
            local format = req.query["format"].tointeger();
            local bitsperpx = req.query["bitsperpx"].tointeger();
            local width = req.query["width"].tointeger();
            local height = req.query["height"].tointeger();
            sendPng(http.base64decode(req.body),handle,format,bitsperpx,width,height);
            sendPng(http.base64decode(req.body), handle);
        } else if ("text" in req.query) {
            device.send("text",req.query["text"]);
        }
        if ("draw" in req.query) {
            local x = 0;
            local y = 0;
            if ("x" in req.query) {
                x = req.query["x"].tointeger();
            }
            if ("y" in req.query) {
                y = req.query["y"].tointeger();
            }
            device.send("draw",{"handle":handle,"xoffset":x,"yoffset":y});
        }
        resp.send(200,"OK\n");
    } catch (err) {
        server.error("Error parsing new request: "+err);
        resp.send(400, err);
    }
});

server.log("Agent Started.");
