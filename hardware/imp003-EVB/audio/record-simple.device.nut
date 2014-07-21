// Minimal recording example

const BUFFERSIZE        = 8192; // size of buffers sent to the agent
RECORD_OPTS             <- A_LAW_COMPRESS | NORMALISE;
const SAMPLERATE        = 8000; // Hz
const RECORD_TIME       = 5.0; // recording length in seconds

// Audio recorder class
class Recorder {
    mic             = null; // microphone pin
    sampleroptions  = null; // e.g. "NORMALISE", "A_LAW_COMPRESS"
    samplerate      = null;
    buffersize      = null;

    constructor(_mic, _sampleroptions, _samplerate, _buffersize) {
        this.mic            = _mic;
        this.sampleroptions = _sampleroptions;
        this.samplerate     = _samplerate;
        this.buffersize     = _buffersize;
    }

    // helper: callback and buffers for the sampler
    function samplesReady(buffer, length) {
        if (length > 0) {
            agent.send("push", buffer);
        } else {
            server.log("Sampler Buffer Overrun");
        }
    }

    // start recording audio
    function start() {
        server.log("Staring Sampler");
        hardware.sampler.configure(mic, samplerate, [blob(buffersize),blob(buffersize),blob(buffersize)],samplesReady.bindenv(this), sampleroptions);
        hardware.sampler.start();
    }

    // stop recording audio
    // the "finish" helper will be called to finish the process when the last buffer is ready
    function stop() {
        hardware.sampler.stop();
        // the sampler will immediately call samplesReady to empty its last buffer
        // following samplesReady, the imp will idle, and finish will be called
        imp.onidle(finish.bindenv(this));
    }

    // helper: clean up after stopping the sampler
    function finish() {        
        // signal to the agent that we're ready to upload this new message
        // the agent will call back with a "pull" request, at which point we'll read the buffer out of flash and upload
        agent.send("done", 0);
        server.log("Sampler Stopped");
    }
}

function recordBtnCallback() {
    // if the button is currently pressed, start a recording
    if (btn.read()) {
        // turn on the green LED
        led_grn.write(0);
        // enable the microphone
        mic_en_l.write(0);
        // start a recording; data is sent to the agent as it is recorded
        recorder.start();
        // schedule the recording to stop after RECORD_TIME seconds
        imp.wakeup(RECORD_TIME, function() {
            led_grn.write(1);
            recorder.stop();
            // disable microphone
            mic_en_l.write(1);
        });
    }
}

/* BEGIN EXECUTION -----------------------------------------------------------*/

server.log("Started. Free memory: "+imp.getmemoryfree());

mic         <- hardware.pinJ;
mic_en_l    <- hardware.pinT;
btn         <- hardware.pinU;
led_grn     <- hardware.pinF;

// configure button to start a recording
btn.configure(DIGITAL_IN, recordBtnCallback);
// configure LED for simple on/off
led_grn.configure(DIGITAL_OUT);
led_grn.write(1);
// mic enable pin
mic_en_l.configure(DIGITAL_OUT);
mic_en_l.write(1);

recorder <- Recorder(mic, RECORD_OPTS, SAMPLERATE, BUFFERSIZE);
