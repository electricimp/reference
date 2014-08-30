// Lala Audio Impee Agent
// New audio is sent to the device by sending the URL of the message to <agenturl>/fetch
// or by sending a POST containing the message to <agenturl>/newmsg
// New messages from device can be downloaded with GET request to <agenturl>/getmsg

/* CONSTs and GLOBALS -------------------------------------------------------*/

const AGENT_BUFFER_SIZE     = 80000; // more than enough for 10s of audio at 16 kHz
const COMPRESSION_CODE      = 0x0006; // 0x06 = 8-bit ITU G.711 A-Law 
const SAMPLERATE            = 8000;
const HEADER_CHUNK_SIZE     = 58; // 58 bytes for format and data WAV headers

// global buffer for audio data; we keep this at global scope so that it can be asynchronously
// accessed by device event handlers
agent_buffer    <- blob(AGENT_BUFFER_SIZE);
recording       <- false;
message_ready   <- false;
message_len     <- 0;

// write chunk headers onto an outbound blob of audio data from the device
// this is included so that you can fetch your example audio and immediately play it on your computer
function writeChunkHeaders(buffer, data_chunk_len) {
    // four essential headers: RIFF type header, format chunk header, fact header, and the data chunk header
    // data will come last, as the data chunk includes the data (concatenated outside this function)
    // RIFF type header goes first
    // RIFF header is 12 bytes, format header is 26 bytes, fact header is 12 bytes, data header is 8 bytes
    //local header = blob(58);
    buffer.seek(0,'b');
    
    // Chunk ID is "RIFF"
    buffer.writestring("RIFF");
    // four bytes for chunk data size (file size - 8)
    buffer.writen((data_chunk_len + HEADER_CHUNK_SIZE - 8), 'i');
    // RIFF type is "WAVE"
    buffer.writestring("WAVE");
    // FORMAT CHUNK
    // first four bytes are "fmt "
    buffer.writestring("fmt ");
    // four-byte value here for chunk data size
    buffer.writen(18,'i');
    // two bytes for compression code
    // 0x06 = 8-bit ITU G.711 A-Law
    buffer.writen(COMPRESSION_CODE, 'w');
    // two bytes for # of channels
    buffer.writen(1, 'w');
    // four bytes for sample rate
    buffer.writen(SAMPLERATE, 'i');
    // four bytes for average bytes per second
    buffer.writen(SAMPLERATE, 'i');
    // two bytes for block align - this is effectively what we use "width" for; nubmer of bytes per sample slide
    buffer.writen(1, 'w');
    // two bytes for significant bits per sample
    // again, this is effectively determined by our "width" parameter
    buffer.writen(8, 'w');
    // two bytes for "extra" data
    buffer.writen(0,'w');
    // END OF FORMAT CHUNK

    // FACT CHUNK
    // first four bytes are "fact"
    buffer.writestring("fact");
    // fact chunk data size is 4
    buffer.writen(4,'i');
    // last four bytes are a vaguely-defined compression data field, currently just number of samples in data chunk
    buffer.writen(data_chunk_len, 'i');
    // END OF FACT CHUNK

    // DATA CHUNK
    // first four bytes are "data"
    buffer.writestring("data");
    buffer.writen(data_chunk_len, 'i');
    // we return this blob and concatenate with the actual data chunk - we're done 

    return buffer;
}

/* DEVICE EVENT HANDLERS -----------------------------------------------------*/

// take in chunks of data from the device during upload
device.on("push", function(buffer) {
    if (!recording) {
        recording = true;
        // reset to the beginning of the agent buffer
        // pre-allocate some space so we don't have to resize the buffer later for short messages
        agent_buffer = blob(AGENT_BUFFER_SIZE);
        agent_buffer.seek(HEADER_CHUNK_SIZE,'b');
    }
    
    message_len += buffer.len();
    agent_buffer.writeblob(buffer);
});

// reset when the device indicates it is done recording
device.on("done", function(dummy) {
    message_ready = true;
    recording = false;
    // we now have the whole message and can write WAV headers at the beginning of the buffer
    writeChunkHeaders(agent_buffer, message_len);
    message_len = 0;
    agent_buffer.seek(0);
});

/* HTTP EVENT HANDLER ------------------------------------------------------*/

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    server.log("Request received for latest recorded message.");
    if (message_ready) {
        server.log("Serving Audio Buffer, len "+agent_buffer.len());
        // set content-type header so audio will play in the browser
        res.header("Content-Type","audio/x-wav");
        res.send(200, agent_buffer);
    } else {
        res.send(200, "No new messages");
    }
});

/* EXECUTION BEGINS HERE ----------------------------------------------------*/

server.log("Started. Free memory: "+imp.getmemoryfree());