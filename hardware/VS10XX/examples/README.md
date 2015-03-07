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

//... later, after pin assignments and configuration

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
The VS10XX includes a microphone pre-amp, ADCs, automatic gain control, and encoder; it can produce a fully-formed audio file, including the appropriate header. This file can be received from the VS10XX in two different ways: by reading the HDAT registers to fetch the file 16 bytes at a time (not recommended), or by requesting the VS10XX to transmit the file over UART as it is recorded and encoded. If the HDAT registers are used, only very low bit rates are possible; reading the data this way incurs 100% transactional overhead, and it is not possible for the imp to keep up with the encoder for all but very low bit rates. 

Using the UART to receive the data, recording with the VS10XX works very similarly to the operation of the imp's own built-in sampler. Recording parameters are configured, a callback set for full buffers of data, and then recording is stopped. The receive concludes with the last (partial) buffer of data that was being written when recording was stopped. A very wide range of baud rates is supported. 
