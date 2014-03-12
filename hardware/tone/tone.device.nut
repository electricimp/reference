// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT


// -------------------------------------------------------------------------
const NOTE_REST = 0
const NOTE_B0 = 31
const NOTE_C1 = 33
const NOTE_CS1 = 35
const NOTE_D1 = 37
const NOTE_DS1 = 39
const NOTE_E1 = 41
const NOTE_F1 = 44
const NOTE_FS1 = 46
const NOTE_G1 = 49
const NOTE_GS1 = 52
const NOTE_A1 = 55
const NOTE_AS1 = 58
const NOTE_B1 = 62
const NOTE_C2 = 65
const NOTE_CS2 = 69
const NOTE_D2 = 73
const NOTE_DS2 = 78
const NOTE_E2 = 82
const NOTE_F2 = 87
const NOTE_FS2 = 93
const NOTE_G2 = 98
const NOTE_GS2 = 104
const NOTE_A2 = 110
const NOTE_AS2 = 117
const NOTE_B2 = 123
const NOTE_C3 = 131
const NOTE_CS3 = 139
const NOTE_D3 = 147
const NOTE_DS3 = 156
const NOTE_E3 = 165
const NOTE_F3 = 175
const NOTE_FS3 = 185
const NOTE_G3 = 196
const NOTE_GS3 = 208
const NOTE_A3 = 220
const NOTE_AS3 = 233
const NOTE_B3 = 247
const NOTE_C4 = 262
const NOTE_CS4 = 277
const NOTE_D4 = 294
const NOTE_DS4 = 311
const NOTE_E4 = 330
const NOTE_F4 = 349
const NOTE_FS4 = 370
const NOTE_G4 = 392
const NOTE_GS4 = 415
const NOTE_A4 = 440
const NOTE_AS4 = 466
const NOTE_B4 = 494
const NOTE_C5 = 523
const NOTE_CS5 = 554
const NOTE_D5 = 587
const NOTE_DS5 = 622
const NOTE_E5 = 659
const NOTE_F5 = 698
const NOTE_FS5 = 740
const NOTE_G5 = 784
const NOTE_GS5 = 831
const NOTE_A5 = 880
const NOTE_AS5 = 932
const NOTE_B5 = 988
const NOTE_C6 = 1047
const NOTE_CS6 = 1109
const NOTE_D6 = 1175
const NOTE_DS6 = 1245
const NOTE_E6 = 1319
const NOTE_F6 = 1397
const NOTE_FS6 = 1480
const NOTE_G6 = 1568
const NOTE_GS6 = 1661
const NOTE_A6 = 1760
const NOTE_AS6 = 1865
const NOTE_B6 = 1976
const NOTE_C7 = 2093
const NOTE_CS7 = 2217
const NOTE_D7 = 2349
const NOTE_DS7 = 2489
const NOTE_E7 = 2637
const NOTE_F7 = 2794
const NOTE_FS7 = 2960
const NOTE_G7 = 3136
const NOTE_GS7 = 3322
const NOTE_A7 = 3520
const NOTE_AS7 = 3729
const NOTE_B7 = 3951
const NOTE_C8 = 4186
const NOTE_CS8 = 4435
const NOTE_D8 = 4699
const NOTE_DS8 = 4978

// -------------------------------------------------------------------------
// This timer class may be out of date. For the latest version see the electricimp/examples github repository.
// 
class timer {

    cancelled = false;
    paused = false;
    running = false;
    callback = null;
    interval = 0;
    params = null;
    send_self = false;
    static timers = [];

    // -------------------------------------------------------------------------
    constructor(_params = null, _send_self = false) {
        params = _params;
        send_self = _send_self;
        timers.push(this); // Prevents scoping death
    }

    // -------------------------------------------------------------------------
    function _cleanup() {
        foreach (k,v in timers) {
            if (v == this) return timers.remove(k);
        }
    }
    
    // -------------------------------------------------------------------------
    function update(_params) {
        params = _params;
        return this;
    }

    // -------------------------------------------------------------------------
    function set(_duration, _callback) {
        assert(running == false);
        callback = _callback;
        running = true;
        imp.wakeup(_duration, alarm.bindenv(this))
        return this;
    }

    // -------------------------------------------------------------------------
    function repeat(_interval, _callback) {
        assert(running == false);
        interval = _interval;
        return set(_interval, _callback);
    }

    // -------------------------------------------------------------------------
    function cancel() {
        cancelled = true;
        return this;
    }

    // -------------------------------------------------------------------------
    function pause() {
        paused = true;
        return this;
    }

    // -------------------------------------------------------------------------
    function unpause() {
        paused = false;
        return this;
    }

    // -------------------------------------------------------------------------
    function alarm() {
        if (interval > 0 && !cancelled) {
            imp.wakeup(interval, alarm.bindenv(this))
        } else {
            running = false;
            _cleanup();
        }

        if (callback && !cancelled && !paused) {
            if (!send_self && params == null) {
                callback();
            } else if (send_self && params == null) {
                callback(this);
            } else if (!send_self && params != null) {
                callback(params);
            } else  if (send_self && params != null) {
                callback(this, params);
            }
        }
    }
}


// -------------------------------------------------------------------------
class Tone {
    pin = null;
    playing = null;
    wakeup = null;

    constructor(_pin) {
        this.pin = _pin;
        this.playing = false;
    }
    
    function isPlaying() {
        return playing;
    }
    
    function play(freq, duration = null) {
        if (playing) stop();
        
        freq *= 1.0;
        pin.configure(PWM_OUT, 1.0/freq, 1.0);
        pin.write(0.5);
        playing = true;
        
        if (duration != null) {
            wakeup = timer().set(duration, stop.bindenv(this));
        }
    }
    
    function stop() {
        if (wakeup != null){
            wakeup.cancel();
            wakeup = null;
        } 
        
        pin.write(0.0);
        playing = false;
    }
}


// -------------------------------------------------------------------------
class Song {
    tone = null;
    song = null;
    
    currentNote = null;
    
    wakeup = null;
    
    constructor(_tone, _song) {
        this.tone = _tone;
        this.song = _song;

        this.currentNote = 0;
    }
    
    // Plays the song frmo the start
    function Restart() {
        Stop();
        Play();
    }
    
    // Plays song from current position
    function Play() {
        if (currentNote < song.len()) {
            tone.play(song[currentNote].note, 1.0/song[currentNote].duration);
            wakeup = timer().set(1.0/song[currentNote].duration + 0.01, Play.bindenv(this));
            currentNote++;
        }
    }
    
    // Stops playing, and saves position
    function Pause() {
        tone.stop();
        if (wakeup != null) {
            wakeup.cancel();
            wakeup = null;
        }
    }
    
    // Stops playing and resets position
    function Stop() {
        Pause();
        currentNote = 0;
    }
}

