## Audio Playback
This example demonstrates how to use the imp003's [Fixed-Frequency DAC](http://electricimp.com/docs/api/hardware/fixedfrequencydac/) to play audio.

### Getting audio to the agent

The agent code processes a **16-bit, PCM-encoded WAV file** and converts it into raw audio data before sending it to the device. There are three different ways to load the audio into the agent:
#### 1. Upload the data directly

```
curl --data-binary @<your_audio_file>.wav https://agent.electricimp.com/<your_agent_ID>/play
```

#### 2. Upload a URL that points to a WAV file

```
curl --data-urlencode url=<URL of wav file> https://agent.electricimp.com/<your_agent_ID>/url
```

#### 3. Submit a URL using the agent-hosted web form

Simply visit `https://agent.electricimp.com/<your_agent_ID>`, enter the URL of the WAV file into the form, then click 'Fetch'

### Playing the audio

After you send audio to the agent, the device will perform a sequence of tasks, displaying the current status by lighting an LED:

1. **Red** - Erasing enough flash sectors to fit the new audio
2. **Blue** - Downloading the raw audio data and saving it to the flash
3. **Green** - Ready to play audio

Once the green light turns on, press Button 1 to begin playback! After audio data has been written to flash, the device will be able to play it back even from cold boot. Any time the LED is green, audio data is valid and able to be played.

For more information, please see the Electric Imp Developer Center article on the [Sampler and Fixed-Frequency DAC](http://electricimp.com/docs/resources/sampler_ffd/).
