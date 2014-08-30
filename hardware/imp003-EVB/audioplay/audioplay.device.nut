// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Pin allocation
button1     <- hardware.pinU;
button2     <- hardware.pinV;
ledRed      <- hardware.pinE;
ledGreen    <- hardware.pinF;
ledBlue     <- hardware.pinK;
speakerEnable <- hardware.pinS;
speaker       <- hardware.pinC;

const CHUNK_SIZE    = 16384;    // Size of data chunks sent from agent (bytes)
const BUFFER_SIZE   = 8192;     // Size of buffer to read from flash (bytes)
const SECTOR_SIZE   = 4096;     // Size of flash sectors
const COOKIE_HEADER = "WAVE";   // String that indicates valid data on flash
const COOKIE_LENGTH = 0x0C;     // Length of cookie, in bytes

flashSize   <- null;            // Size of attached SPI flash (to send to agent)
params      <- {};
playbackPtr <- null;

buffers     <- [];              // DAC playback buffers
chunkIndex  <- null;
numBuffers  <- null;

validAudio  <- false;

function writeBuffer(buffer) {
    local readSize = (params.wavSize + COOKIE_LENGTH) - playbackPtr;
    if (readSize > BUFFER_SIZE) {
        readSize = BUFFER_SIZE;
    }
    // server.log("reading " + readSize + " from flash");
    buffer.seek(0);
    flash.readintoblob(playbackPtr, buffer, readSize);
    playbackPtr += readSize;
}

// The FFD has consumed a buffer - either refill it or shut down
function bufferEmpty(buffer) {
    // If we still have audio left to play, add a buffer
    if (playbackPtr < params.wavSize + COOKIE_LENGTH) {
        writeBuffer(buffer);
        hardware.fixedfrequencydac.addbuffer(buffer);
    } else {
        if (!buffer) {
            server.log("Null buffer callback.");
        }
        stop();
    }
}

// Configure and start the DAC, then enable the speaker amplifier
function play() {
    playbackPtr = COOKIE_LENGTH;
    // Create the correct number of buffers
    if (numBuffers == 1) {
        buffers = [blob(params.wavSize)];
    } else if (numBuffers == 2) {
        buffers = [blob(BUFFER_SIZE), blob(params.wavSize)];
    } else {
        buffers = [blob(BUFFER_SIZE), blob(BUFFER_SIZE)];
    }
    // Fill the initial buffers
    flash.enable();
    for (local i = 0; i < (numBuffers==1?1:2); i++) {
        buffers[i].seek(0);
        writeBuffer(buffers[i]);
    }
    server.log("Playback started");

    hardware.fixedfrequencydac.configure(speaker, params.sampleRate, buffers, bufferEmpty, AUDIO);
    hardware.fixedfrequencydac.start();
    imp.wakeup(0.1, function() { speakerEnable.write(1); });
}

// Disable speaker amplifier, then stop the DAC
function stop() {
    speakerEnable.write(0);
    hardware.fixedfrequencydac.stop();
}

// Writes a cookie to flash with WAV params to allow for cold boot playback
function writeCookie() {
    local cookie = blob(COOKIE_LENGTH);
    cookie.writestring(COOKIE_HEADER);
    cookie.writen(params.wavSize, 'i');
    cookie.writen(params.sampleRate, 'i');
    if (cookie.len() == COOKIE_LENGTH) {
        server.log("Writing cookie");
        flash.write(0, cookie);
    }
}

// Check the beginning of flash to see if it contains valid WAV data
// If so, then allow playback immediately
function readCookie() {
    server.log("Looking for cookie");
    flash.enable();
    local cookie = flash.read(0, COOKIE_LENGTH);
    flash.disable();
    if (cookie.readstring(4) == "WAVE") {
        params.wavSize <- cookie.readn('i');
        params.sampleRate <- cookie.readn('i');
        ledGreen.write(0);
        validAudio = true;
        server.log(format("Found cookie. size: %d, rate: %d", params.wavSize, params.sampleRate));
    } else {
        server.log("No cookie found.");
    }
}

// Called when agent is ready to send new audio
// - Erase as many flash sectors as necessary to fit the new audio
// - Write a cookie to the beginning of flash to allow for cold boot playback
// - Get the first chunk of audio from the agent
function newAudio(newParams) {
    params = newParams;
    chunkIndex = 0;
    ledGreen.write(1);
    validAudio = false;
    flash.enable();
    // Erase the appropriate number of sectors
    local numSectors = (math.ceil(newParams.wavSize / SECTOR_SIZE.tofloat())).tointeger();
    server.log(format("Erasing %d flash sectors...", numSectors));
    ledRed.write(0);
    for (local i = 0; i < numSectors; i++) {
        flash.erasesector(i*SECTOR_SIZE);
    }
    writeCookie();
    ledRed.write(1);
    // Calculate the number of FFD buffers we'll use on playback
    numBuffers = (math.ceil(params.wavSize / BUFFER_SIZE.tofloat())).tointeger();
    server.log("numBuffers: " + numBuffers);
    ledBlue.write(0);
    agent.send("getChunk", chunkIndex);
}

// Save a chunk of audio to flash
// If it's the last chunk, then turn on the green LED and enable playback
function saveChunk(chunk) {
    local addr = COOKIE_LENGTH + chunkIndex * CHUNK_SIZE;
    if (addr + chunk.len() <= flashSize) {
        flash.write(addr, chunk);
        server.log("Wrote chunk " + chunkIndex++);
        if (addr + chunk.len() < params.wavSize) {
            agent.send("getChunk", chunkIndex);
        } else {
            server.log("Download complete.");
            ledBlue.write(1);
            flash.disable();
            ledGreen.write(0);
            validAudio = true;
        }
    } else {
        server.error("Can't write chunk - out of space");
        ledRed.write(0);
    }
}

// On request, send the flash size and desired chunk size to the agent
function sendConfig(arg) {
    agent.send("config", {
        maxFileSize = this.flashSize + COOKIE_LENGTH,
        chunkSize = CHUNK_SIZE
    });
}

// Agent callbacks
// If agent requests, send flash size
agent.on("getConfig", sendConfig);

// If agent has new audio, write it to flash
agent.on("newAudio", newAudio);
agent.on("chunk", saveChunk);

// Start
flash <- hardware.spiflash;
speakerEnable.configure(DIGITAL_OUT);
ledRed.configure(DIGITAL_OUT_OD, 1);
ledGreen.configure(DIGITAL_OUT_OD, 1);
ledBlue.configure(DIGITAL_OUT_OD, 1);

// Button one plays the audio
button1.configure(DIGITAL_IN_PULLDOWN, function() {
    if (button1.read() == 0 && validAudio) {
        // Start the fixed-frequency DAC
        play();
    }
});
// Button two stops playback
button2.configure(DIGITAL_IN_PULLDOWN, function() {
    if (!button2.read()) {
        stop();
    }
})

server.log("Started with version " + imp.getsoftwareversion());
imp.setpowersave(true);

// Get our flash size and tell the agent
hardware.spiflash.enable();
flashSize = hardware.spiflash.size();
hardware.spiflash.disable();
sendConfig(1);

server.log("Flash size: " + flashSize);
server.log("Free device memory: " + imp.getmemoryfree());

// Check for audio on flash
readCookie();