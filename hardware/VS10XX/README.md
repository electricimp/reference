# VS10XX Audio Encoder/Decoder

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [VS10XX Family from VLSI](http://www.vlsi.fi/en/support/evaluationboards/vs10xxprotoboard.html) allows easy encoding and decoding of many common compressed audio formats with a simple SPI interface. Some parts in the family also offer a headphone amplifier, micrphone amplifier, and many related analog front-end features. This driver class was written for the [VS1063 Breakout Board, available from Sparkfun](https://www.sparkfun.com/products/11684). The VS1063 can decode Ogg Vorbis/MP3/AAC/WMA audio and encode MP3, IMA ADPCM, and Ogg Vorbis. 

This class is unfinished.

## Hardware Setup

The table below shows how to connect an Electric Imp breakout board to the VS1063 breakout board from Sparkfun

| VS10XX Breakout Pin | Imp Breakout Pin | Notes |
| ----------------- | ---------------- | ----- |
| V<sub>CC</sub> | 3V3 | Power |
| GND | GND |  |
| SO | Imp SPI MISO Pin (Ex: Pin2) | |
| SI | Imp SPI MOSI Pin (Ex: Pin7) | |
| SCLK | Imp SPI SCLK Pin (Ex: Pin5) ||
| CS | Any Imp GPIO | DIGITAL_OUT |
| RST | Any Imp GPIO | DIGITAL_OUT |
| DREQ | Any Imp GPIO | DIGITAL_IN |
| BSYNC | Any Imp GPIO | DIGITAL_OUT (XDCS) |

The debug UART can also be connected to the imp but is not yet implemented in this class

## Instantiation

SPI interface and GPIO pins must be configured before passing to the constructor. 

A Samples Consumed Callback is required to allow the VS10XX object to request more audio data when a buffer is consumed during playback. 

```
function requestBuffer() {
    agent.send("pull", 0);
}

function sendBuffer(buffer) {
    agent.send("push", buffer);
}

cs_l.configure(DIGITAL_OUT, 1);
dcs_l.configure(DIGITAL_OUT, 1);
rst_l.configure(DIGITAL_OUT, 1);
dreq_l.configure(DIGITAL_IN);
spi.configure(CLOCK_IDLE_LOW, SPICLK_LOW);

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, requestBuffer, sendBuffer);
```

## Usage

### Playing Back Audio
The VS10XX handles the work of parsing, decoding, and playing back an audio file automatically. To play a file, the file (headers included) is loaded into the VS10XX's data FIFO. The VS10XX begins decoding and playing the file immediately and signals when there is room in the FIFO for more data. When the complete file has been sent, one full FIFO (2048 bytes) of 0x00 is loaded through the FIFO to finish playback. 

This driver class further reduces the task of keeping the VS10XX's data FIFO full during playback. An array of buffers (squirrel blob objects) is stored within the VS10XX object and used to automatically keep the VS10XX's data FIFO full. This is essentially required because of the speed with which the VS10XX decodes the data. 

To perform playback, ensure your Samples Consumed Callback is properly configured, then pass the first buffer(s) to the VS10XX object with the "queueData" method. More than one buffer can be queued (this is recommended). Playback will stop automatically when the first buffer underrun occurs (all of the queued buffers are consumed).

Please see the examples section for more information on playback.

### Recording Audio
The VS10XX includes a microphone pre-amp, ADCs, automatic gain control, and encoder; it can produce a fully-formed audio file, including the appropriate header. This file can be received from the VS10XX in two different ways: by reading the HDAT registers to fetch the file 16 bytes at a time (not recommended), or by requesting the VS10XX to transmit the file over UART as it is recorded and encoded. If the HDAT registers are used, only very low bit rates are possible; reading the data this way incurs 100% transactional overhead, and it is not possible for the imp to keep up with the encoder for all but very low bit rates. 

Using the UART to receive the data, recording with the VS10XX works very similarly to the operation of the imp's own built-in sampler. Recording parameters are configured, a callback set for full buffers of data, and then recording is stopped. The receive concludes with the last (partial) buffer of data that was being written when recording was stopped. A very wide range of baud rates is supported. 

Resizeable UART Receive FIFOs are required in order to record Ogg Vorbis, as well as other formats at higher data rates. When recording with Ogg Vorbis, the approximately constant-size file header will be generated immediately after beginning recording. This will overrun the imp's UART FIFO at the standard size of 80 bytes regardless of selected Ogg Vorbis bitrate. Resizing the UART FIFO also improves throughput for other data formats. Using the highest possible sample rate and bitrate will exceed the imp's possible WiFi throughput and require that the data be stored on the device side (e.g. in an external flash memory) and uploaded when the recording is complete.

Resizeable UART Receive FIFOs are available in impOS release 32 and later.

Please see the examples section for more information on recording. 

### Methods

#### getMode()
Returns the 16-bit contents of the SCI_MODE register as an integer.

```Squirrel
server.log(format("VS10XX SCI_MODE: 0x%04X",audio.getMode()));
```

#### getStatus()
Returns the 16-bit contents of the SCI_STATUS register as an integer.

```Squirrel
server.log(format("VS10XX SCI_STATUS: 0x%04X",audio.getStatus()));
```

#### getChipID()
Returns the 32-bit chip ID of the VS10XX (copied from the internal fuses on power-up).

```Squirrel
server.log(format("VS10XX Chip ID: 0x%08X",audio.getChipID()));
```

#### getVersion()
Returns the 16-bit version number of the VS10XX, stored in RAM.

```Squirrel
server.log(format("VS10XX Version: 0x%04X",audio.getVersion()));
```

#### getConfig1()
Returns the 16-bit contents of the SCI_CONFIG1 register, which are used to show which formats are enabled or disabled. 

```Squirrel
server.log(format("VS10XX Config1: 0x%04X",audio.getConfig1()));
```

#### getHDAT0()
Returns the 16-bit contents of the SCI_HDAT0 register. During playback, HDAT0 indicates the bitrate of the file being decoded, divided by 8. HDAT0 bits also indicate the number of channels used, the sample rate, the copyright status, and whether emphasis is used. See page 47 of the [VS10XX datasheet](http://dlnmh9ip6v2uc.cloudfront.net/datasheets/Widgets/vs1063ds.pdf).

```Squirrel
server.log(format("VS10XX HDAT0: 0x%04X",audio.getHDAT0()));
```

#### getHDAT1()
Returns the 16-bit contents of the SCI_HDAT0 register. During playback, HDAT1 indicates the format of the file being decoded. HDAT1 bits also indicate validity and layer of the data being decoded. See page 47 of the [VS10XX datasheet](http://dlnmh9ip6v2uc.cloudfront.net/datasheets/Widgets/vs1063ds.pdf).

```Squirrel
server.log(format("VS10XX HDAT1: 0x%04X",audio.getHDAT1()));
```

#### setClockMultiplier(*multiplier*) 
Sets the internal clock multiplier of the VS10XX. This clock multiplier multiplies the frequency of the crystal attached to the VS10XX to set the core base clock. The multiplier is an integer between 1 and 7, inclusive. Note that the SPI interface can run as fast as (Base clock)/7.

```Squirrel
// Set the SPI slow enough for the base clock with the default multiplier
spi.configure(CLOCK_IDLE_LOW, 937.5); // SPI running at 0.94 MHz

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, requestBuffer);

// Set the clock multiplier higher
server.log(format("VS10XX Clock Multiplier set to %d",audio.setClockMultiplier(3)));

// If we wish, we can now run the SPI faster
spi.configure(CLOCK_IDLE_LOW, 3750); // SPI running at 3.75 MHz
```

#### setVolume(*left_dB*, [*right_dB*])
Sets the playback volume in dB. This should be a negative number. Start around -80.0 dB or lower if using headphones! Separate values for the right and left channel are supported. If only one argument is provided, it will set both channels to the same level. 

```Squirrel
audio.setVolume(-80.0);
server.log("Volume set to -80.0 dB");
```

#### queueData(*blob*)
Queues a blob for playback. If playback is not in progress when a buffer is queued, playback will be started. This method can be called multiple times in a row to queue multiple buffers; this is recommended for best throughput (3 to 5 buffers of 4096 to 8192 bytes produces fairly stable results).

```Squirrel
// queue data from the agent in memory to be fed to the VS10XX
agent.on("push", function(chunk) {
    audio.queueData(chunk);
});
```

#### setSampleRate(*samplerate*)
Sets the sample rate for audio recording. Samplerate is given in Hz. Sample rates from 8 kHz to 48 kHz are supported. 

```Squirrel
// set sample rate to 8 kHz
audio.setSampleRate(8000);
```

#### setRecordGain(*gain*)
Set the gain for the microphone preamplifier in Volts/Volt. Values from 1 to 64 V/V are supported. Setting the automatic gain control (AGC) automatically sets the fixed gain to zero.

```Squirrel
// set the gain to 34 V/V
// this is approximately 30.1 dB
// 20 * log<sub>10</sub>(34) = 30.102 dB
audio.setRecordGain(34);
```

#### setRecordAGC(*state*, *max_gain*)
Enable/disable the automatic gain control and set the maximum allowed gain. State is a boolean; set true to enable AGC. Max gain is in V/V and may be any value from 1 to 64 V/V.

```Squirrel
// Enable AGC and set max gain to 30 dB
audio.setRecordAGC(true, 34);
```

#### setRecordInputMic()
Selects the built-in microphone preamplifier as the input source for recording. Note that the microphone preamplifier is on the left channel; this must also be set.

```Squirrel
audio.setRecordInputMic();
audio.setChLeft();
```

#### setRecordInputLine()
Selects the line input as the input source for recording.

```Squirrel
audio.setRecordInputLine();
```

#### setChJointStereo()
Enable recording in joint stereo. In joint stereo, gain is set for both channels at the same time; this is most relevant when using AGC. 

```Squirrel
audio.setChJointStereo();
```

#### setChDual()
Enable recording in dual channel. This is also a stereo recording, but each channel's gain is set independently. Most relevant when using AGC.

```Squirrel
audio.setChDual();
```

#### setChLeft()
Enable recording on the left channel. 

```Squirrel
audio.setChLeft();
```

#### setChRight()
Enable recording on the right channel.

```Squirrel
audio.setChRight();
```

#### setChDownmix()
Enable recording on both channels, down-mixed to a mono track. 

```Squirrel 
audio.setChDownmix();
```

#### setRecordFormatPCM()
Select the PCM WAV format for recorded audio. A RIFF WAV header will be produced. Note that because the length of the file is not known at the start of recording, the length fields for the file and for the data chunk of the file are populated with 0xFFFF FFFF. If necessary (it is often not), these fields can be updated in the resulting file when recording is complete. Please refer to the datasheet for more information.

```Squirrel
audio.setRecordFormatPCM();
```

#### setRecordFormatULaw()
Select [G.711 µ-law compression](http://en.wikipedia.org/wiki/%CE%9C-law_algorithm) for recorded audio. A RIFF WAV header will be produced. File and data chunk length will still be populated with 0xFFFF FFFF. 

```Squirrel
audio.setRecordFormatULaw();
```

#### setRecordFormatALaw()
Select [G.711 A-law compression](http://en.wikipedia.org/wiki/A-law_algorithm) for recorded audio. A RIFF WAV header will be produced. File and data chunk length will still be populated with 0xFFFF FFFF.

```Squirrel
audio.setRecordFormatALaw();
```

#### setRecordFormatOgg()
Select [Ogg Vorbis](http://en.wikipedia.org/wiki/Vorbis) format for recorded audio. This format offers compression rates on the order of MP3 compression without being a licensed format. An Ogg Vorbis header will be produced.

```Squirrel
audio.setRecordFormatOgg();
```

#### setRecordFormatMP3()
Select [MP3](http://en.wikipedia.org/wiki/MP3) format for recorded audio. Note that MP3 is a licensed compression format and that if you encode or decode MP3 in a commercial product you must have a license.

```Squirrel
audio.setRecordFormatMP3();
```

#### setRecordBitrate(*rate_kbps*)
Set the recording bitrate in kilobits per second. 

```Squirrel
// record 128 kbps MP3s
audio.setRecordFormatMP3();
audio.setRecordBitrate(128);
```

#### setUartTxEn()
Enable transmission of encoded data over the UART, instead of having to read the encoded data from the HDAT registers. If your application receives encoded data over UART, do not attempt ot also read the HDAT registers during recording; the resulting file will be corrupted. 

```Squirrel
audio.setUartTxEn();
```

#### startRecording()
Place the VS10XX in encoder mode and begin recording and encoding audio. Note that this call issues a soft reset to the VS10XX to place it in encoding mode. All recording and encoding paremeters are read from their various registers when the VS10XX comes out of reset; this should be the last call made to start recording. 

```Squirrel
function record() {
    audio.setSampleRate(8000);
    audio.setRecordInputMic();
    audio.setChLeft();
    audio.setRecordFormatMP3();
    audio.setRecordAGC(1, 64);
    audio.setUartBaud(UARTBAUD);
    audio.setUartTxEn(1);
    // set bitrate / quality
    audio.setRecordBitrate(64);
    imp.wakeup(RECORD_TIME, function() {
        server.log("Stopping Recording...");
        audio.stopRecording(function() {
            server.log("Recording Stopped");
            agent.send("recording_done", 0);
        });
    }.bindenv(this));
    server.log("Starting Recording...");
    audio.startRecording();
}
```

#### stopRecording(*callback*)
Set the CANCEL bit in the VS10XX's mode register to stop recording and encoding audio. Encoded data may still be waiting to be transmitted over UART or read from the HDAT registers, so this call executes asynchronously; a callback function must be provided. This callback will be called when recording has stopped and all data has been read or received from the VS10XX.

```Squirrel
imp.wakeup(RECORD_TIME, function() {
    server.log("Stopping Recording...");
    audio.stopRecording(function() {
        server.log("Recording Stopped");
        agent.send("recording_done", 0);
    });
}.bindenv(this));
```

## Examples

Refer to the examples folder to see how to use the VS10XX with the [AudioDownloader](../../utility/AudioDownloader) class to play a compressed audio file stored at a remote URL, and how to record an MP3 file and play it back in the browser by sending a request to the Agent URL