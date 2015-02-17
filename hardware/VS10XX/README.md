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

cs_l.configure(DIGITAL_OUT, 1);
dcs_l.configure(DIGITAL_OUT, 1);
rst_l.configure(DIGITAL_OUT, 1);
dreq_l.configure(DIGITAL_IN);
spi.configure(CLOCK_IDLE_LOW, SPICLK_LOW);

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, requestBuffer);
```

## Usage

### Playing Back Audio
The VS10XX handles the work of parsing, decoding, and playing back an audio file automatically. To play a file, the file (headers included) is loaded into the VS10XX's data FIFO. The VS10XX begins decoding and playing the file immediately and signals when there is room in the FIFO for more data. When the complete file has been sent, one full FIFO (2048 bytes) of 0x00 is loaded through the FIFO to finish playback. 

This driver class further reduces the task of keeping the VS10XX's data FIFO full during playback. An array of buffers (squirrel blob objects) is stored within the VS10XX object and used to automatically keep the VS10XX's data FIFO full. This is essentially required because of the speed with which the VS10XX decodes the data. 

To perform playback, ensure your Samples Consumed Callback is properly configured, then pass the first buffer(s) to the VS10XX object with the "queueData" method. More than one buffer can be queued (this is recommended). Playback will stop automatically when the first buffer underrun occurs (all of the queued buffers are consumed).

### Methods

#### getMode()
Returns the 16-bit contents of the SCI_MODE register as an integer.

```
server.log(format("VS10XX SCI_MODE: 0x%04X",audio.getMode()));
```

#### getStatus()
Returns the 16-bit contents of the SCI_STATUS register as an integer.

```
server.log(format("VS10XX SCI_STATUS: 0x%04X",audio.getStatus()));
```

#### getChipID()
Returns the 32-bit chip ID of the VS10XX (copied from the internal fuses on power-up).

```
server.log(format("VS10XX Chip ID: 0x%08X",audio.getChipID()));
```

#### getVersion()
Returns the 16-bit version number of the VS10XX, stored in RAM.

```
server.log(format("VS10XX Version: 0x%04X",audio.getVersion()));
```

#### getConfig1()
Returns the 16-bit contents of the SCI_CONFIG1 register, which are used to show which formats are enabled or disabled. 

```
server.log(format("VS10XX Config1: 0x%04X",audio.getConfig1()));
```

#### getHDAT0()
Returns the 16-bit contents of the SCI_HDAT0 register. During playback, HDAT0 indicates the bitrate of the file being decoded, divided by 8. HDAT0 bits also indicate the number of channels used, the sample rate, the copyright status, and whether emphasis is used. See page 47 of the [VS10XX datasheet](http://dlnmh9ip6v2uc.cloudfront.net/datasheets/Widgets/vs1063ds.pdf).

```
server.log(format("VS10XX HDAT0: 0x%04X",audio.getHDAT0()));
```

#### getHDAT1()
Returns the 16-bit contents of the SCI_HDAT0 register. During playback, HDAT1 indicates the format of the file being decoded. HDAT1 bits also indicate validity and layer of the data being decoded. See page 47 of the [VS10XX datasheet](http://dlnmh9ip6v2uc.cloudfront.net/datasheets/Widgets/vs1063ds.pdf).

```
server.log(format("VS10XX HDAT1: 0x%04X",audio.getHDAT1()));
```

#### setClockMultiplier(multiplier) 
Sets the internal clock multiplier of the VS10XX. This clock multiplier multiplies the frequency of the crystal attached to the VS10XX to set the core base clock. The multiplier is an integer between 1 and 7, inclusive. Note that the SPI interface can run as fast as (Base clock)/7.

```
// Set the SPI slow enough for the base clock with the default multiplier
spi.configure(CLOCK_IDLE_LOW, 937.5); // SPI running at 0.94 MHz

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, requestBuffer);

// Set the clock multiplier higher
server.log(format("VS10XX Clock Multiplier set to %d",audio.setClockMultiplier(3)));

// If we wish, we can now run the SPI faster
spi.configure(CLOCK_IDLE_LOW, 3750); // SPI running at 3.75 MHz
```

#### setVolume(left_dB, [right_dB])
Sets the playback volume in dB. This should be a negative number. Start around -80.0 dB or lower if using headphones! Separate values for the right and left channel are supported. If only one argument is provided, it will set both channels to the same level. 

```
audio.setVolume(-80.0);
server.log("Volume set to -80.0 dB");
```

#### queueData(blob)
Queues a blob for playback. If playback is not in progress when a buffer is queued, playback will be started. This method can be called multiple times in a row to queue multiple buffers; this is recommended for best throughput (3 to 5 buffers of 4096 to 8192 bytes produces fairly stable results).

```
// queue data from the agent in memory to be fed to the VS10XX
agent.on("push", function(chunk) {
    audio.queueData(chunk);
});
```

## Examples

See the examples folder to see how to use the VS10XX with the [AudioDownloader](../../utility/AudioDownloader) class to play a compressed audio file stored at a remote URL.