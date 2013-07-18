/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* Lala Audio Impee Agent

 Tom Buttner, April 2013
 Electric Imp, inc
 tom@electricimp.com

 * Takes in new audio as POST at <agenturl>/newmsg
 * New messages from device can be downloaded with GET request to <agenturl>/getmsg

 */

/* GLOBAL PARAMETERS AND FLAGS ----------------------------------------------*/

// parameters read from WAV headers on inbound files
inParams <- {
    fmtChunkOffset = null,
    fmtChunkDataSize = null,
    dataChunkOffset = null,
    dataChunkSize = null,
    /* two supported compression codes:
        0x01 = 16-bit PCM
        0x06 = 8-bit ITU G.711 A-Law (yep, the imp does that)
    */
    compressionCode = null,
    /* character to use in blob operations; depends on sample width:
        'b' = 1 byte per sample (A-law)
        'w' = 2 bytes per sample (16-bit PCM)
    */
    width = null,
    // if the inbound file is multi-channel, we send only the first channel to the imp
    channels = null,
    samplerate = null,
    avgBytesPerSec = null,
    blockAlign = null,
    sigBits = null,
}

// parameters to write to the WAV headers in outbound files
// these are provided by the device when it records and uploads a message
outParams <- {
    dataChunkSize = null,
    width = null,
    compressionCode = null, 
    samplerate = null,
}

// global buffer for audio data; we keep this at global scope so that it can be asynchronously
// accessed by device event handlers
wavBlob <- blob(50000);
// new message flag so that we can respond appropriately when polled
newMessage <- false;

// size of chunks to pull from device when fetching new recorded message
CHUNKSIZE <- 8192;

/* GENERAL FUNCTIONS --------------------------------------------------------*/

// find a string in our "wavBlob" buffer
function wavBlobFind(str) {
    //sserver.log("Searching for \""+str+"\" in blob");
    if (wavBlob.len() < str.len()) {
        server.log("Blob too short! ("+wavBlob.len()+" bytes)");
        server.log("Short object was of type "+typeof(wavBlob));
        return -1;
    }
    local startPos = wavBlob.tell();
    wavBlob.seek(0,'b');
    local testString = "";
    for (local i = 0; i < str.len(); i++) {
        testString += format("%c",wavBlob.readn('b'));
    }
    while ((testString != str) && (wavBlob.tell() < (wavBlob.len() - str.len()))) {
        //server.log(testString);
        testString = testString.slice(1);
        testString += format("%c",wavBlob.readn('b'));
    }
    if (testString != str) {
        // failed to find it
        return -1;
    }
    // found it, return its position
    local pos = wavBlob.tell() - str.len();
    // restore the blob handle before returning
    wavBlob.seek(startPos, 'b');
    return pos;
}

// parse the format chunk header on an inbound wav file 
function getFormatData() {
    local startPos = wavBlob.tell();
    wavBlob.seek(inParams.fmtChunkOffset+4,'b');

    inParams.fmtChunkDataSize = wavBlob.readn('i');
    inParams.compressionCode = wavBlob.readn('w');
    if (inParams.compressionCode == 0x01) {
        // 16-bit PCM
        inParams.width = 'w';
    } else if (inParams.compressionCode == 0x06) {
        // A-law
        inParams.width = 'b';
    } else {
        server.log(format("Audio uses unsupported compression code 0x%02x",
            inParams.compressionCode));
        return 1;
    }
    inParams.channels = wavBlob.readn('w');
    inParams.samplerate = wavBlob.readn('i');
    inParams.avgBytesPerSec = wavBlob.readn('i');
    inParams.blockAlign = wavBlob.readn('w');
    inParams.sigBits = wavBlob.readn('w');

    server.log(format("Compression Code: %x", inParams.compressionCode));
    server.log(format("Channels: %d",inParams.channels));
    server.log(format("Sample rate: %d", inParams.samplerate));

    // return the file pointer
    wavBlob.seek(startPos, 'b');

    return 0;
}

// write chunk headers onto an outbound blob of audio data from the device
function writeChunkHeaders() {
    // four essential headers: RIFF type header, format chunk header, fact header, and the data chunk header
    // data will come last, as the data chunk includes the data (concatenated outside this function)
    // RIFF type header goes first
    // RIFF header is 12 bytes, format header is 26 bytes, fact header is 12 bytes, data header is 8 bytes
    local msgBlob = blob(58);
    // Chunk ID is "RIFF"
    msgBlob.writen('R','b');
    msgBlob.writen('I','b');
    msgBlob.writen('F','b');
    msgBlob.writen('F','b');
    // four bytes for chunk data size (file size - 8)
    msgBlob.writen((msgBlob.len()+outParams.dataChunkSize-8), 'i');
    // RIFF type is "WAVE"
    msgBlob.writen('W','b');
    msgBlob.writen('A','b');
    msgBlob.writen('V','b');
    msgBlob.writen('E','b');
    // Done with wave file header

    // FORMAT CHUNK
    // first four bytes are "fmt "
    msgBlob.writen('f','b');
    msgBlob.writen('m','b');
    msgBlob.writen('t','b');
    msgBlob.writen(' ','b');
    // four-byte value here for chunk data size
    msgBlob.writen(18,'i');
    // two bytes for compression code
    msgBlob.writen(outParams.compressionCode, 'w');
    // two bytes for # of channels
    msgBlob.writen(1, 'w');
    // four bytes for sample rate
    msgBlob.writen(outParams.samplerate, 'i');
    // four bytes for average bytes per second
    if (outParams == 'b') {
        msgBlob.writen(outParams.samplerate, 'i');
    } else {
        msgBlob.writen((outParams.samplerate * 2), 'i');
    }
    // two bytes for block align - this is effectively what we use "width" for; nubmer of bytes per sample slide
    if (outParams.width == 'b') {
        msgBlob.writen(1, 'w');
    } else {
        msgBlob.writen(2, 'w');
    }
    // two bytes for significant bits per sample
    // again, this is effectively determined by our "width" parameter
    if (outParams.width == 'b') {
        msgBlob.writen(8, 'w');
    } else {
        msgBlob.writen(16, 'w');
    }
    // two bytes for "extra" data
    msgBlob.writen(0,'w');
    // END OF FORMAT CHUNK

    // FACT CHUNK
    // first four bytes are "fact"
    msgBlob.writen('f','b');
    msgBlob.writen('a','b');
    msgBlob.writen('c','b');
    msgBlob.writen('t','b');
    // fact chunk data size is 4
    msgBlob.writen(4,'i');
    // last four bytes are a vaguely-defined compression data field, currently just number of samples in data chunk
    msgBlob.writen(outParams.dataChunkSize, 'i');
    // END OF FACT CHUNK

    // DATA CHUNK
    // first four bytes are "data"
    msgBlob.writen('d','b');
    msgBlob.writen('a','b');
    msgBlob.writen('t','b');
    msgBlob.writen('a','b');
    // data chunk length - four bytes
    msgBlob.writen(outParams.dataChunkSize, 'i');
    // we return this blob, base-64 encode it, and concatenate with the actual data chunk - we're done 

    return msgBlob;
}

function fetch(url) {
    offset <- 0;
    const LUMP = 4096;
    server.log("Fetching content from "+url);
    do {
        response <- http.get(url, 
            {Range=format("bytes=%u-%u", offset, offset+LUMP-1) }
        ).sendsync();
        got <- response.body.len();
        
        /* Since the response is a string, use string "find" to locate
        chunk offsets before we convert to a blob
        */
        local fmtOffset = response.body.find("fmt ");
        if (fmtOffset) {
            parameters.fmtChunkOffset = fmtOffset + offset;
            server.log("Located format chunk at offset "+parameters.fmtChunkOffset);
        }
        local dataOffset = response.body.find("data");
        if (dataOffset) {
            parameters.dataChunkOffset = dataOffset + offset;
            server.log("Located data chunk at offset "+parameters.dataChunkOffset);
        }
        
        offset += got;
        addToBlob(response.body);
        //server.log(format("Downloading (%d bytes)",offset));
    } while (response.statuscode == 206 && got == LUMP);
    
    server.log("Done, got "+offset+" bytes total");
}

/* AGENT EVENT HANDLERS -----------------------------------------------------*/

// Serve up a chunk of audio data from an inbound wav file when the device signals it is ready to download a chunk
device.on("pull", function(size) {
    local buffer = blob(size);
    // make a "sequence number" out of our position in audioData
    local chunkIndex = ((wavBlob.tell()-inParams.dataChunkOffset) / size)+1;
    server.log("Agent: sending chunk "+chunkIndex+" of "+(inParams.dataChunkSize/size));
    
    // wav data is interlaced
    // skip channels if there are more than one; we'll always take the first
    local max = size;
    local bytesLeft = (inParams.dataChunkSize - (wavBlob.tell() - inParams.dataChunkOffset + 8)) / inParams.channels;
    if (inParams.width == 'w') {
        // if we're A-law encoded, it's 1 byte per sample; if we're 16-bit PCM, it's two
        bytesLeft = bytesLeft * 2;
    }
    if (size > bytesLeft) {
        max = bytesLeft;
    }
    // the data chunk of a wav file is interlaced; the first sample for each channel, then the second for each, etc...
    // grab only the first channel if this is a multi-channel file
    // sending single-channel files is recommended as the agent's memory is constrained
    for (local i = 0; i < max; i += inParams.channels) {
        buffer.writen(wavBlob.readn(inParams.width), inParams.width);
    } 

    // pack up the sequence number and the buffer in a table
    local data = {
        index = chunkIndex,
        chunk = buffer,
    }
    
    // send the data out to the device
    device.send("push", data);
});

// hook for the device to start uploading a new message 
device.on("newMessage", function(newParams) {
    outParams.dataChunkSize = newParams.len;
    // the imp sends its sample width; if it's 'w', the imp is not using compression
    // if the width is 'b', the imp is using A-law compression
    outParams.width = newParams.width;
    if (outParams.width == 'b') {
        outParams.compressionCode = 0x06;
    } else {
        outParams.compressionCode = 0x01;
    }
    outParams.samplerate = newParams.samplerate;
    server.log(format("Agent: device signaled new message ready, length %d, sample rate %d, compression code 0x%02x",
        outParams.dataChunkSize, outParams.samplerate, outParams.compressionCode));
    newMessage = true;
    // prep our buffer to begin writing in chunks from the device
    wavBlob.seek(0,'b');
    // tell the device we're ready to receive data; device will respond with "push" and a blob
    device.send("pull", CHUNKSIZE);
});

// take in chunks of data from the device during upload
device.on("push", function(chunk) {
    local numChunks = (outParams.dataChunkSize / CHUNKSIZE) + 1;
    local index = (wavBlob.tell() / CHUNKSIZE) + 1;
    server.log(format("Agent: got chunk %d of %d, len %d", index, numChunks, chunk.len()));
    wavBlob.writeblob(chunk);
    if (index < numChunks) {
        // there's more file to fetch
        device.send("pull", CHUNKSIZE);
    } else {
        server.log("Agent: Done fetching recorded buffer from device");
    }
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/getmsg") {
        // this path is used to request the latest message from the agent; pack up the file and send it
        if (newMessage) {
            server.log("Agent: Responding with new audio buffer, len "+outParams.dataChunkSize);
            wavBlob.seek(0,'b');
            res.send(200, http.base64encode(writeChunkHeaders())+http.base64encode(wavBlob));
            newMessage = false;
        } else {
            server.log("Agent: Responding with 204 (no new messages)");
            res.send(204, "No new messages");
        }
    } else if (request.path == "/newmsg") {
        // this path is used to post a new message
        server.log("Agent: got a new message");
        server.log("Agent: wavBlob length = "+wavBlob.len()+" bytes");
        wavBlob = http.base64decode(request.body);
        res.send(200, "OK");
        // base64decode returns a blob, so we need to search the blob for chunk header offsets
        server.log("Agent: encoded message length = "+request.body.len()+" bytes");
        server.log("Agent: decoded message length = "+wavBlob.len()+" bytes");
        inParams.fmtChunkOffset = wavBlobFind("fmt ");
        if (inParams.fmtChunkOffset < 0) {
            server.log("Agent: Failed to find format chunk in new message");
            return 1;
        }
        server.log("Located format chunk at offset "+inParams.fmtChunkOffset);
        inParams.dataChunkOffset = wavBlobFind("data");
        if (inParams.dataChunkOffset < 0) {
            server.log("Agent: Failed to find data chunk in new message");
            return 1;
        }
        server.log("Located data chunk at offset "+inParams.dataChunkOffset);

        // blob to hold audio data exists at global scope
        wavBlob.seek(0,'b');
    
        // read in the vital parameters from the file's chunk headers
        if (getFormatData()) {
            server.log("Agent: failed to get audio format data for file");
            return 1;
        }
    
        // seek to the beginning of the audio data chunk
        wavBlob.seek(inParams.dataChunkOffset+4,'b');
        inParams.dataChunkSize = wavBlob.readn('i');
        server.log(format("Agent: at beginning of audio data chunk, length %d", inParams.dataChunkSize));

        // Notifty the device we have audio waiting, and wait for a pull request to serve up data
        device.send("newAudio", inParams);
    } else if (request.path == "/fetch") {
        local fetchURL = request.body;
        server.log("Agent: requested to fetch a new message from "+fetchURL);
        res.send(200, "OK");
    } else {
        // send a generic response to prevent browser hang
        res.send(200, "OK");
        try {
            fetch(fetchURL);
        } catch (err) {
            server.log("Agent: failed to fetch new message");
            return 1;
        }
        server.log("Agent: done fetching message");
    }
});

/* EXECUTION BEGINS HERE ----------------------------------------------------*/

server.log("Lala agent running");
server.log("Agent: free memory: "+imp.getmemoryfree());
