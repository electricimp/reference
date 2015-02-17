# AudioDownloader Class

Author: [Tom Byrne](https://github.com/ersatzavian/)

The AudioDownloader class simplifies the task of "chunking" a large remote (audio) file down to the device. The server hosting the remote file must support byte-ranged GET requests. Note that some very convenient places to publicly host a file (Dropbox, Google Drive, Box) all use chunked transfer encoding, which this class does not yet support.

## Usage
The AudioDownloader communicates with the device via two events, *push* and *pull*. 

On instantiation, the downloader configures a callback handler for *pull* events from the device. During a download, pull events will trigger the downloader to fetch the next chunk of data from the remote URL and send that chunk to the device with a *push* event. 

The *pull* event allows the device to apply some back pressure during a download. At the start of a download, the AudioDownloader will push a pre-set number of chunks to the device (this number is set by QUEUE_DEPTH inside the class). After this, a new chunk will only be fetched and sent on a *pull* event; the device can be configured to send this event only after consuming a complete buffer.

Steps to performing a chunked download: 

1. Instantiate the AudioDownloader
2. Set the URL to download from
3. Call the start method to begin the download. The download will complete automatically when the full file is fetched. 

## Example

```
downloader <- AudioDownloader();

http.onrequest(function(req, res) {
    downloader.setDownloadURL(req.body);
    res.send(200, "OK\n");
    downloader.start();
});
```

For a more complete example, see the examples folder for the [VS10XX Audio Codec IC](../../hardware/VS10XX/examples).