# VS10XX Audio Encoder/Decoder Example

Author: [Tom Byrne](https://github.com/ersatzavian/)

See the parent directory for information on the VS10XX, hardware setup, and general information on the methods provided by the VS10XX class.

The VS10XX's handling of buffers of audio data during recording or playback mimics the behavior of the imp's native sampler and fixedfrequencydac classes, respectively. Data is passed in or out of the VS10XX in a "bucket brigade" fashion. To understand more about buffers of audio and how data is handled in this class, take a look at the ["Audio Waveforms and the Imp"](http://electricimp.com/docs/resources/sampler_ffd/) Developer Guide in the Electric Imp Dev Center.

### Playing Back Audio

To play a file, place the file at a remote URL and then send that URL to the agent in a POST request to <agent_url>/fetch. Note that the audioDownloader class used to fetch the file does not support chunked transfer encoding; Google Drive, Box, DropBox, and many other file storage services will not work. Try Github.

```bash
14:12:37-tom$ curl -d "www.fakeserver.com/myaudiofile.mp3" https://agent.electricimp.com/myagenturl/fetch
```

The VS10XX handles the work of parsing, decoding, and playing back an audio file automatically. To play a file, the file (headers included) is loaded into the VS10XX's data FIFO. The VS10XX begins decoding and playing the file immediately and signals when there is room in the FIFO for more data. When the complete file has been sent, one full FIFO (2048 bytes) of 0x00 is loaded through the FIFO to finish playback. 

This driver class further reduces the task of keeping the VS10XX's data FIFO full during playback. An array of buffers (squirrel blob objects) is stored within the VS10XX object and used to automatically keep the VS10XX's data FIFO full. This is essentially required because of the speed with which the VS10XX decodes the data. 

During instantiation, a "Samples Consumed" callback is passed into the constructor. This callback will be called whenever decoding/playback is ongoing and a queued buffer is empty:

```Squirrel
function requestBuffer() {
    agent.send("pull", 0);
}

//... later, after pin assignments and configuration ...

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart, requestBuffer, sendBuffer);
```

To start playback, first a buffer (or several buffers, which is recommended) must be queued. Then, playback is started. In this example, the first 5 buffers are queued (by the AudioDownloader class in the agent), by sending them with device.send("push", data). 

On the agent side, inside the HTTP request handler:

```Squirrel
if (req.path == "/fetch") {
    downloader.setDownloadURL(req.body);
    res.send(200, "OK\n");
    downloader.start();
}
```

Inside the downloader's "start" method, we see:

```Squirrel
downloadChunk(function() {
    for (local i = 0; i < QUEUE_DEPTH; i++) {
        sendNextChunk();
    }    
}.bindenv(this));
```

This data arrives at the device and is queued in the VS10XX class with the queueData method:

```Squirrel
// queue data from the agent in memory to be fed to the VS10XX
agent.on("push", function(chunk) {
    audio.queueData(chunk);
});
```

The queueData method will automatically load the first buffer into the VS10XX, starting playback. From here, the process becomes quite automatic: Every time a buffer is consumed, the VS10XX class loads another queued buffer while requesting another from the agent. The agent fetches another buffer from the remote URL and sends it back to the device, which queues it. 

When the device has loaded all of the queued data and the data consumed callback is called, an underrun occurs and the playback is stopped. 

### Recording Audio

To test recording and playback, just build and run this firmware. The device starts a recording 1 second after starting and will record for five seconds. The recording will be A-law encoded (presented as a WAV file) and is automatically sent to the agent. 

Note that currently, the imp cannot acheive high enough combined UART and WiFi throughput to receive higher sample rates, or other encoding types, while sending the data directly to the agent. It is expected that with larger a UART FIFO (coming soon), Ogg Vorbis will be an available option for tests like this that do not involve locally storing the file before sending it to the agent. 

If the file is stored locally (on a Flash, for example), higher data rates and other encoding types may be possible with the existing code. The stored file can then be uploaded while recording is not taking place.

```Squirrel
audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart, requestBuffer, sendBuffer);

// ... later...

imp.wakeup(1.0, record);
```

To play the recorded audio, just open the agent URL in a web browser. The agent sets the Content-Type header so that the audio will play in the browser.

To download the audio, send a request with CURL (or right-click the agent URL in the IDE and "Save Link As...")

```bash
14:12:37-tom$ curl https://agent.electricimp.com/myagent > test.wav
```

The VS10XX includes a microphone pre-amp, ADCs, automatic gain control, and encoder; it can produce a fully-formed audio file, including the appropriate header. This file is received by requesting the VS10XX to transmit the file over UART as it is recorded and encoded.

Just like with playback, data is passed out of the VS10XX in a bucket-brigade fashion, by passing full buffers to the samplesReady callback passed into the constructor:

```Squirrel
function sendBuffer(buffer) {
    agent.send("push", buffer);
}

// ... later ... 

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart, requestBuffer, sendBuffer);
```

Because this example sends the data directly to the agent, throughput is critical; if the device blocks for a long time while trying to place the data in the send buffer, the UART will overrun while the VS10XX sends new audio data to the device. Therefore, the send buffer size on the device must be increased. Note that if your application does something locally with the data, like saving it to flash, this isn't as critical (though still recommended for upload later to acheive best throughput):

```Squirrel
// our callback passes data straight to the agent
// if the TCP buffer is smaller than the buffer to be sent, agent.send will block
// this will cause UART overruns. So we need to increase the send buffer size.
imp.setsendbuffersize(SEND_BUFFER_SIZE);

imp.wakeup(1.0, record);
```

Before starting the recording, the desired recording and encoding parameters must be set. When the recording is started, the VS10XX goes through a soft reset to enter encoding mode. The recording and encoding parameters are loaded at this time.

```Squirrel
function record() {
    // set up VS10XX recording settings
    audio.setSampleRate(SAMPLERATE_HZ);
    audio.setRecordInputMic();
    audio.setChLeft();
    audio.setRecordFormatALaw();
    audio.setRecordAGC(1, MAX_GAIN);
    audio.setUartBaud(UARTBAUD);
    audio.setUartTxEn(1);
    imp.wakeup(RECORD_TIME, function() {
        audio.stopRecording(function() {
            agent.send("recording_done", 0);
        });
    }.bindenv(this));
    server.log("Starting Recording...");
    audio.startRecording();
}
```

The stopRecording function is called with the required callback; after the imp requests that the VS10XX stop recording audio, the imp waits for all remaining data to be transmitted over the UART before calling the callback.

The chunks of audio data are concatenated in agent memory and served when a request arrives at the agent:

```
res.header("Content-Type", "audio/mpeg")
res.send(200, recorded_message);  
```

