class Pulse {
    _pin = null;
    _buffers = null;
    
    // on beat callback
    _onbeat = null;
    
    // public variables
    BPM = null;
    SampleCounter = null;
    
    // variables for analysis
    _ibi = null;
    _lastBeatTime = null;
    _peak = null;
    _trough = null;
    _threshold = null;
    _amp = null;
    _firstBeat = null;
    _secondBeat = null;
    _rate = null;
    
    _pulse = null;
    
    constructor(pin, onBeat, sampleHz = 1000, bufferSize = 250, numBuffers = 2) {
        // setup sample and buffer
        _buffers = array(numBuffers);
        for(local i = 0; i < numBuffers; i++) _buffers[i]=blob(bufferSize);
        
        hardware.sampler.configure(pin, sampleHz, _buffers, _onBufferFull.bindenv(this));
        
        // setup callback
        _onbeat = onBeat;
        
        //initialize variables for analysis
        BPM = 0.0;
        _ibi = 100.0;
        _pulse = false;
        
        _amp = 100.0;
        SampleCounter = 0;
        _rate = array(10);
        _reset();
    }
    
    function start() {
        _reset();
        hardware.sampler.start();
    }
    
    function stop() {
        hardware.sampler.stop()
    }
    
    function _reset() {
        _threshold = 512.0;
        _peak = 512.0;
        _trough = 512.0;
        _lastBeatTime = SampleCounter;
        _firstBeat = true;
        _secondBeat = false;
    }
    
    function _onBufferFull(samples, length) {
        if (samples == null) return;
        
        local end = SampleCounter + (length / 2);
        
        for(SampleCounter; SampleCounter < end; SampleCounter++) {
            local Signal = samples.readn('w') / 65535.0 * 1024.0;
            local N = SampleCounter - _lastBeatTime;
            
            if(Signal < _threshold && N > (_ibi/5.0)*3.0 && Signal < _trough) {
                _trough = Signal;
            }
            
            if(Signal > _threshold && Signal > _peak){
                _peak = Signal;
            } 
    
            //  NOW IT'S TIME TO LOOK FOR THE HEART BEAT
            // signal surges up in value every time there is a pulse
            if (N > 250){
                if ( (Signal > _threshold) && (_pulse == false) && (N > (_ibi/5)*3) ){        
                    _pulse = true;
                    _ibi = SampleCounter - _lastBeatTime;
                    _lastBeatTime = SampleCounter;
        
                    if(_secondBeat){
                        _secondBeat = false;
                        for(local i=0; i<=9; i++){
                            _rate[i] = _ibi;
                        }
                    }
        
                    if(_firstBeat){
                        _firstBeat = false;
                        _secondBeat = true;
                        continue;
                    }

                    // keep a running total of the last 10 IBI values
                    local runningTotal = 0;
                    
                    for(local i=0; i<=8; i++){
                        _rate[i] = _rate[i+1];
                        runningTotal += _rate[i];
                    }
            
                    _rate[9] = _ibi;
                    runningTotal += _rate[9];
                    runningTotal /= 10.0;
                    BPM = 60000.0 / runningTotal;

                    if(_onbeat != null) {
                        _onbeat();
                    }
                }
                
                if (Signal < _threshold && _pulse == true){
                    _pulse = false;
                    _amp = _peak - _trough;
                    _threshold = _amp/2.0 + _trough;
                    _peak = _threshold;
                    _trough = _threshold;
                }
    
                if (N > 2500) _reset();
            }                       
        }        
    }
}