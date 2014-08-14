ReadSpeaker
===========
The ReadSpeaker class wraps a very basic implementation of the [ReadSpeaker Text-To-Speech (TTS) API](http://www.readspeaker.com).

Usage
=====

Create a ReadSpeaker Object
---------------------------
Instantiate a ReadSpeaker object with your API Key:
```
ttsEngine <- ReadSpeaker("YOUR_READSPEAKER_API_KEY");
```

Get an Audio File
-----------------
Once a ReadSpeaker object has been instantiated, you can get an A-LAW compressed audio file by calling the ```say``` function. The say function requires the text to be spoken, as well as a callback function that will execute when the audio file is returned. 

```
ttsEngine.say("Hello World", function(err, data) {
    if (err != null) {
        server.log(err);
        return;
    }

    // Do something with data
    // data is a blob that contains the A-Law compressed audio file
    device.send("say", data);
});
```

NOTE: The above example does not check whether the imp has sufficent memory to receive the file. A more complete implementation should send the audio file down in chunks, and 'stream' the audio.

