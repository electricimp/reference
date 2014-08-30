## Waveform Record Class
This this class shows a simple example of how to wrap the [Sampler](http://electricimp.com/docs/api/hardware/sampler/) class to record analog waveforms. 

In this example, every buffer is sent directly to the agent as it appears at the samplesReady callback from the sampler. Note that depending on your hardware design, this method of handling samples can cause noise in the resulting waveform, as operating the WiFi transmitter while recording causes significant [power supply load transients](http://electricimp.com/docs/resources/designing_analog_hw).

The recording can be played directly from the agent by pointing a browser at the agent URL. The agent will finish the recording by writing RIFF WAV headers onto the buffer, then serving it to the browser with the Content-Type header set to audio/x-wav. Most browsers will play the audio direclty in the browser. The audio file can also be downloaded with a generic request:

```
14:46:3-tom@eevee$ curl https://agent.electricimp.com/<your_agent_ID>  >  demo.wav
```

For more information, please see the Electric Imp Developer Center article on the [Sampler and Fixed-Frequency DAC](http://electricimp.com/docs/resources/sampler_ffd/).