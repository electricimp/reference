
const SPICLK_LOW = 937.5;
const SPICLK_HIGH = 3750;
const UARTBAUD = 115200;
const BYTES_PER_DREQ = 32; // number of bytes to feed to the VS10XX when it asserts DREQ
const INITIAL_BYTES = 2048; // number of bytes to load when starting playback (FIFO size 2048)
const DATA_WAIT_TIME = 0.00001;
const VOLUME = -60.0; //dB

audioChunks <- []; // array of chunks sent from agent to be loaded and played
playbackInProgress <- false;

class VS10XX {
    static VS10XX_READ          = 0x03;
    static VS10XX_WRITE         = 0x02;
    static VS10XX_SCI_MODE      = 0x00;
    static VS10XX_SCI_STATUS    = 0x01;
    static VS10XX_SCI_BASS      = 0x02;
    static VS10XX_SCI_CLOCKF    = 0x03;
    static VS10XX_SCI_DECODE_TIME = 0x04;
    static VS10XX_SCI_AUDATA    = 0x05;
    static VS10XX_SCI_WRAM      = 0x06;
    static VS10XX_SCI_WRAMADDR  = 0x07;
    static VS10XX_SCI_HDAT0     = 0x08;
    static VS10XX_SCI_HDAT1     = 0x09;
    static VS10XX_SCI_AIADDR    = 0x0A;
    static VS10XX_SCI_VOL       = 0x0B;
    static VS10XX_SCI_AICTRL0   = 0x0C;
    static VS10XX_SCI_AICTRL1   = 0x0D;
    static VS10XX_SCI_AICTRL2   = 0x0E;
    static VS10XX_SCI_AICTRL3   = 0x0F;
    static ENDFILLBYTE_PADDING  = 2048;
    
    loading = false;
    dreq_cb_set = false;
    endfillbytes_sent = 0;
    
    spi     = null;
    xcs_l   = null;
    xdcs_l  = null;
    dreq    = null;
    rst_l   = null;
    uart    = null;
    dreq_cb = null;
    
    constructor(_spi, _xcs_l, _xdcs_l, _dreq, _rst_l, _uart = null) {
        spi     = _spi;
        xcs_l   = _xcs_l;
        xdcs_l  = _xdcs_l;
        dreq    = _dreq;
        rst_l   = _rst_l;
        uart    = _uart;
        
        init();
    }
    
    function init() {
        rst_l.write(0);
        rst_l.write(1);
        clearDreqCallback();
        dreq.configure(DIGITAL_IN, _callDreqCallback.bindenv(this));
    }
    
    function _getReg(addr) {
        local msg = blob(2);
        msg.writen(VS10XX_READ, 'b');
        msg.writen(addr,'b');
        msg.writen(0x0000,'w');
        xcs_l.write(0);
        local data = spi.writeread(msg);
        xcs_l.write(1);
        data.seek(2, 'b');
        data.swap2();
        return data.readn('w');
    }
    
    // Data is masked to 16 bits, as all SCI registers are 16 bits wide
    function _setReg(addr, data) {
        local msg = blob(4);
        msg.writen(VS10XX_WRITE, 'b');
        msg.writen(addr, 'b');
        msg.writen((data & 0xFF00) >> 8, 'b');
        msg.writen(data & 0x00FF, 'b');
        xcs_l.write(0);
        spi.write(msg);
        xcs_l.write(1);
    }
    
    function _setRegBit(addr, bit, state) {
        local data = _getReg(addr);
        if (state) { data = (data | (0x01 << bit)); }
        else { data = (data & ~(0x01 << bit)); }
        _setReg(addr, data);
    }
    
    function _setRamAddr(addr) {
        addr = addr & 0xFFFF;
        _setReg(VS10XX_SCI_WRAMADDR, addr);
    }
    
    function _getRamAddr() {
        return _getReg(VS10XX_SCI_WRAMADDR);
    }
    
    function _writeRam(addr, data) {
        _setRamAddr(addr);
        data.swap2();
        while(!data.eos()) {
            _setReg(VS10XX_SCI_WRAM, data.readn('w'));
        }
    }
    
    function _readRam(addr, bytes) {
        local data = blob(bytes);
        _setRamAddr(addr);
        while(!data.eos()) {
            data.writen(_getReg(VS10XX_SCI_WRAM), 'w');
        }
        //data.swap2();
        return data;
    }
    
    function _callDreqCallback() {
        if (dreq.read()) { dreq_cb(); }
    }
    
    function setDreqCallback(cb) {
        if (cb) {dreq_cb_set = true;}
        else {dreq_cb_set = false;}
        dreq_cb = cb.bindenv(this);
    }
    
    function clearDreqCallback() {
        dreq_cb = function() { return; }.bindenv(this);
        dreq_cb_set = false;
    }
        
    function dreqCallbackIsSet() {
        return dreq_cb_set;
    }
    
    function canAcceptData() {
        return dreq.read();
    }
    
    function getMode() {
        return _getReg(VS10XX_SCI_MODE);
    }
    
    function getStatus() {
        return _getReg(VS10XX_SCI_STATUS);
    }
    
    function getChipID() {
        local idblob = _readRam(0x1E00, 32);
        return (((idblob[3] << 24) | idblob[2] << 16) | idblob[1]) | idblob[0];
    }
    
    function getVersion() {
        local vblob = _readRam(0x1E02, 16)
        return (vblob[1] << 8) | vblob[0];
    }
    
    function getConfig1() {
        local configblob = _readRam(0x1E03, 16)
        return (configblob[1] << 8) | configblob[0];
    }
    
    function getHDAT0() {
        return _getReg(VS10XX_SCI_HDAT0);
    }
    
    function getHDAT1() {
        return _getReg(VS10XX_SCI_HDAT1);
    }
    
    function setClockMultiplier(mult) {
        local mask = (mult * 2) << 12;
        local clockf_val = _getReg(VS10XX_SCI_CLOCKF);
        _setReg(VS10XX_SCI_CLOCKF, (clockf_val & 0x0FFF) | mask);
        return ((_getReg(VS10XX_SCI_CLOCKF) & 0xF000) >> 12) / 2;
    }
    
    function setVolume(left, right = null) {
        if (right == null) right = left;
        left = (-0.5 * left).tointeger();
        right = (-0.5 * right).tointeger();
        _setReg(VS10XX_SCI_VOL, ((left & 0xFF) << 8) | (right & 0xFF));
    }
    
    function loadData(data) {
        xdcs_l.write(0);
        spi.write(data);
        xdcs_l.write(1);
    }
    
    function sendEndFillBytes() {
        while(audio.canAcceptData() && (endfillbytes_sent < ENDFILLBYTE_PADDING)) {
            loadData("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
            endfillbytes_sent += 32;
        }
        if (endfillbytes_sent < ENDFILLBYTE_PADDING) {
            setDreqCallback(sendEndFillBytes);
        } else {
            clearDreqCallback();
            server.log("Playback Complete");
        }
    }
    
    function finishPlaying() {
        clearDreqCallback();
        endfillbytes_sent = 0;
        sendEndFillBytes();
    }
}

function fillAudioFifo() {
    audio.clearDreqCallback();
    local buffer = null;
    local bytesAvailable = 0;
    local bytesLoaded = 0;
    local bytesToLoad = BYTES_PER_DREQ;
    
    if (audioChunks.len() > 0) {
        buffer = audioChunks.top();
        bytesAvailable = (buffer.len() - buffer.tell());
    } else {
        // done (or buffer underrun)
        playbackInProgress = false;
        audio.finishPlaying();
        return;
    }
    
    try {
        while(audio.canAcceptData() && (bytesLoaded < bytesAvailable)) {
            bytesToLoad = bytesAvailable - bytesLoaded;
            if (bytesToLoad >= BYTES_PER_DREQ) bytesToLoad = BYTES_PER_DREQ;
            audio.loadData(buffer.readblob(bytesToLoad));
            bytesLoaded += bytesToLoad;
            // server.log("Loading..."+audioChunks.top().tell());
            // server.log(format("VS10XX HDAT0: 0x%04X",audio.getHDAT0()));
            // server.log(format("VS10XX HDAT1: 0x%04X",audio.getHDAT1()));
        }
    } catch (err) {
        server.log("Error Loading Data: "+err);
        server.log(format("BytesAvailable at start: %d", bytesAvailable));
        server.log(format("BytesToLoad on last try: %d", bytesToLoad));
        server.log(format("BytesLoaded at error: %d", bytesLoaded));
        server.log(format("buffer ptr: %d",buffer.tell()));
        server.log(format("buffer len: %d",buffer.len()));
    }
    
    //server.log("top buffer: "+audioChunks.top().tell()+" / "+audioChunks.top().len());
    
    if (audioChunks.top().eos()) {
        //server.log("finished buffer");
        audioChunks.pop();
        // bartender!
        agent.send("pull", 0);
    } 
    
    if (audio.canAcceptData()) {
        // we just emptied a buffer; get back to work immediately
        fillAudioFifo();
    } else {
        // we caught up. Yield for a moment so we can get new buffers
        audio.setDreqCallback(fillAudioFifo);
    }
}

agent.on("push", function(chunk) {
    audioChunks.insert(0, chunk);
    //server.log(format("Got buffer (%d buffers ready)",audioChunks.len()));
    if (!playbackInProgress) {
        playbackInProgress = true;
        // just loaded the first chunk (we quit on buffer underrun)
        // load a chunk from our in-memory buffer to start the VS10XX
        audio.loadData(audioChunks.top().readblob(INITIAL_BYTES));
        // start the loop that keeps the data going into the FIFO
        fillAudioFifo();
    }
});

agent.on("dl_done", function(dummy) {
    server.log("Download Done");
});

/* RUNTIME START -------------------------------------------------------------*/

imp.enableblinkup(true);
server.log("Running "+imp.getsoftwareversion());
server.log("Memory Free: "+imp.getmemoryfree());

spi     <- hardware.spi257;
cs_l    <- hardware.pin6;
dcs_l   <- hardware.pinC;
rst_l   <- hardware.pinE;
dreq_l    <- hardware.pinD;
uart    <- hardware.uart1289;

cs_l.configure(DIGITAL_OUT, 1);
dcs_l.configure(DIGITAL_OUT, 1);
rst_l.configure(DIGITAL_OUT, 1);
dreq_l.configure(DIGITAL_IN);
spi.configure(CLOCK_IDLE_LOW, SPICLK_LOW);
uart.configure(UARTBAUD, 8, PARITY_NONE, 1, NO_CTSRTS);

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart);
server.log(format("VS10XX SCI_MODE: 0x%04X",audio.getMode()));
server.log(format("VS10XX SCI_STATUS: 0x%04X",audio.getStatus()));
server.log(format("VS10XX Clock Multiplier set to %d",audio.setClockMultiplier(3)));
spi.configure(CLOCK_IDLE_LOW, SPICLK_HIGH);
server.log(format("Imp SPI Clock set to %0.3f MHz", SPICLK_HIGH / 1000.0));
server.log(format("VS10XX Chip ID: 0x%08X",audio.getChipID()));
server.log(format("VS10XX Version: 0x%04X",audio.getVersion()));
server.log(format("VS10XX Config1: 0x%04X",audio.getConfig1()));
audio.setVolume(VOLUME);
server.log(format("Volume set to %0.1f dB", VOLUME));
