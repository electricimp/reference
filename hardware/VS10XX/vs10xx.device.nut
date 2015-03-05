// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Description: Driver class for the VS10XX encoder/decoder IC

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
    
    //static VS10XX_CHIP_ID_ADDR  = 0x1E00;
    static VS10XX_CHIP_ID_ADDR = 0xC0C0;
    //static VS10XX_VERSION_ADDR  = 0x1E02;
    static VS10XX_VERSION_ADDR  = 0xC0C2;
    //static VS10XX_CONFIG1_ADDR  = 0x1E03;
    static VS10XX_CONFIG1_ADDR  = 0xC0C3;
    //static VS10XX_TX_UART_DIV_ADDR = 0x1E06;
    static VS10XX_TX_UART_DIV_ADDR = 0xC0C6;
    //static VS10XX_TX_UART_BYTE_SPEED_ADDR = 0x1E2B;
    static VS10XX_TX_UART_BYTE_SPEED_ADDR = 0xC0EB;
    //static VS10XX_TX_PAUSE_GPIO_ADDR = 0x1E2C;
    static VS10XX_TX_PAUSE_GPIO_ADDR = 0xC0EC;
    
    static REC_STOP_TIMEOUT     = 0.5; // seconds
    static UART_BAUD            = 38400;
    static ENDFILLBYTE_PADDING  = 2048;
    static BYTES_PER_DREQ       = 32; // min space available when DREQ asserted
    static INITIAL_BYTES        = 2048; // number of bytes to load when starting playback (FIFO size 2048)
    static RX_WATERMARK    = 4096;
    
    queued_buffers          = []; // array of chunks sent from agent to be loaded and played
    rx_buffer               = null;
    playback_in_progress    = false;
    recording               = true;
    loading                 = false;
    dreq_cb_set             = false;
    endfillbytes_sent       = 0; 
    
    spi     = null;
    xcs_l   = null;
    xdcs_l  = null;
    dreq    = null;
    rst_l   = null;
    uart    = null;
    
    dreq_cb = null;
    buffer_consumed_cb  = null;
    buffer_ready_cb     = null;
    recording_done_cb   = null;
    
    constructor(_spi, _xcs_l, _xdcs_l, _dreq, _rst_l, _uart, _buffer_consumed_cb, _buffer_ready_cb) {
        spi     = _spi;
        xcs_l   = _xcs_l;
        xdcs_l  = _xdcs_l;
        dreq    = _dreq;
        rst_l   = _rst_l;
        uart    = _uart;
        buffer_consumed_cb = _buffer_consumed_cb;
        buffer_ready_cb    = _buffer_ready_cb;
        
        init();
    }
    
    function init() {
        rst_l.write(0);
        rst_l.write(1);
        _clearDreqCallback();
        rx_buffer = blob(2);
        rx_buffer.seek('b');
        dreq.configure(DIGITAL_IN, _callDreqCallback.bindenv(this));
        uart.configure(UART_BAUD, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCb.bindenv(this));
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
    
    function _writeRam(addr, data, words = 1) {
        _setRamAddr(addr);
        if (!dreq.read()) {
            server.log("busy after setting WRAMADDR for first word");
        }
        if (words > 1) {
            _setReg(VS10XX_SCI_WRAM, (data & 0xFFFF0000) >> 16);
            if (!dreq.read()) {
                server.log("busy after writing high byte");
            }
            _setRamAddr(addr + 1);
            if (!dreq.read()) {
                server.log("busy after setting WRAMADDR for second word");
            }
        }
        _setReg(VS10XX_SCI_WRAM, data & 0xFFFF);
    }
    
    function _readRam(addr, words = 1) {
        local data = blob(words * 2);
        _setRamAddr(addr);
        while(!data.eos()) {
            data.writen(_getReg(VS10XX_SCI_WRAM), 'w');
        }
        //data.swap2();
        data.seek(0,'b');
        if (words > 1) {
            // 32 bits is the largest word suppored in VS10XX memory
            return data.readn('i');
        } else {
            return data.readn('w');
        }
    }
    
    function _callDreqCallback() {
        if (dreq.read()) { dreq_cb(); }
    }
    
    function _setDreqCallback(cb) {
        if (cb) {dreq_cb_set = true;}
        else {dreq_cb_set = false;}
        dreq_cb = cb.bindenv(this);
    }
    
    function _clearDreqCallback() {
        dreq_cb = function() { return; }.bindenv(this);
        dreq_cb_set = false;
    }
        
    function _dreqCallbackIsSet() {
        return dreq_cb_set;
    }
    
    function _canAcceptData() {
        return dreq.read();
    }

    function _loadData(data) {
        xdcs_l.write(0);
        spi.write(data);
        xdcs_l.write(1);
    }
    
    function _sendEndFillBytes() {
        while(_canAcceptData() && (endfillbytes_sent < ENDFILLBYTE_PADDING)) {
            _loadData("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
            endfillbytes_sent += 32;
        }
        if (endfillbytes_sent < ENDFILLBYTE_PADDING) {
            _setDreqCallback(sendEndFillBytes);
        } else {
            endfillbytes_sent = 0;
            _clearDreqCallback();
            server.log("Playback Complete");
        }
    }
    
    function _finishPlaying() {
        _clearDreqCallback();
        endfillbytes_sent = 0;
        _sendEndFillBytes();
    }
    
    function _fillAudioFifo() {
        _clearDreqCallback();
        local buffer = null;
        local bytes_available = 0;
        local bytes_loaded = 0;
        local bytes_to_load = BYTES_PER_DREQ;
        
        if (queued_buffers.len() > 0) {
            buffer = queued_buffers.top();
            bytes_available = (buffer.len() - buffer.tell());
        } else {
            // done (or buffer underrun)
            playback_in_progress = false;
            _finishPlaying();
            return;
        }
        
        try {
            while(_canAcceptData() && (bytes_loaded < bytes_available)) {
                bytes_to_load = bytes_available - bytes_loaded;
                if (bytes_to_load >= BYTES_PER_DREQ) bytes_to_load = BYTES_PER_DREQ;
                _loadData(buffer.readblob(bytes_to_load));
                bytes_loaded += bytes_to_load;
                // server.log("Loading..."+audioChunks.top().tell());
                // server.log(format("VS10XX HDAT0: 0x%04X",audio.getHDAT0()));
                // server.log(format("VS10XX HDAT1: 0x%04X",audio.getHDAT1()));
            }
        } catch (err) {
            server.log("Error Loading Data: "+err);
            server.log(format("bytes_available at start: %d", bytes_available));
            server.log(format("bytes_to_load on last try: %d", bytes_to_load));
            server.log(format("bytes_loaded at error: %d", bytes_loaded));
            server.log(format("buffer ptr: %d",buffer.tell()));
            server.log(format("buffer len: %d",buffer.len()));
        }
        
        //server.log("top buffer: "+audioChunks.top().tell()+" / "+audioChunks.top().len());
        
        if (queued_buffers.top().eos()) {
            //server.log("finished buffer");
            queued_buffers.pop();
            // bartender!
            buffer_consumed_cb()
        } 
        
        if (_canAcceptData()) {
            // we just emptied a buffer; get back to work immediately
            _fillAudioFifo();
        } else {
            // we caught up. Yield for a moment so we can get new buffers
            _setDreqCallback(_fillAudioFifo.bindenv(this));
        }
    }
    
    function _uartCb() {
        rx_buffer.writeblob(uart.readblob());
        if (rx_buffer.tell() > RX_WATERMARK) {
            buffer_ready_cb(rx_buffer);
            rx_buffer = blob(RX_WATERMARK);
            rx_buffer.seek(0,'b');
        }
    }
    
    function getMode() {
        return _getReg(VS10XX_SCI_MODE);
    }
    
    function getStatus() {
        return _getReg(VS10XX_SCI_STATUS);
    }
    
    function getChipID() {
        return _readRam(VS10XX_CHIP_ID_ADDR, 2);
    }
    
    function getVersion() {
        return _readRam(VS10XX_VERSION_ADDR);
    }
    
    function getConfig1() {
        return _readRam(VS10XX_CONFIG1_ADDR);
    }
    
    function getHDAT0() {
        return _getReg(VS10XX_SCI_HDAT0);
    }
    
    function getHDAT1() {
        return _getReg(VS10XX_SCI_HDAT1);
    }
    
    function getAICTRL3() {
        return _getReg(VS10XX_SCI_AICTRL3);
    }
    
    function softReset() {
        _setRegBit(VS10XX_SCI_MODE, 2, 1);
        imp.sleep(0.002);
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
    
    function queueData(data) {
        queued_buffers.insert(0, data);
        //server.log(format("Got buffer (%d buffers ready)",audioChunks.len()));
        if (!playback_in_progress) {
            playback_in_progress = true;
            // just loaded the first chunk (we quit on buffer underrun)
            // load a chunk from our in-memory buffer to start the VS10XX
            _loadData(queued_buffers.top().readblob(INITIAL_BYTES));
            // start the loop that keeps the data going into the FIFO
            _fillAudioFifo();
        }
    }
    
    function setSampleRate(samplerate) {
        if (samplerate < 8000) samplerate = 8000;
        if (samplerate > 48000) samplerate = 48000;
        _setReg(VS10XX_SCI_AICTRL0, samplerate & 0xFFFF);
    }
    
    function setRecordGain(gain) {
        if (gain < 1) gain = 1;
        if (gain > 64) gain = 64;
        _setReg(VS10XX_SCI_AICTRL1, (gain * 1024) & 0xFFFF);
    }
    
    function setRecordAGC(state, max) {
        if (state) {
            _setReg(VS10XX_SCI_AICTRL1, 0x0000);
            if (max > 64) max = 64;
            if (max < 1) max = 1;
            _setReg(VS10XX_SCI_AICTRL2, (max * 1024) & 0xFFFF);
        } else {
            setRecordGain(1);
        }
    }
    
    function setRecordInputMic() {
        _setRegBit(VS10XX_SCI_MODE, 14, 0);
    }
    
    function setRecordInputLine() {
        _setRegBit(VS10XX_SCI_MODE, 14, 1);
    }
    
    function setChJointStereo() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // bits 2 to 0 determine the ADC setting
        // 0b000 = joint stereo (shared AGC)
        _setReg(VS10XX_SCI_AICTRL3, val & 0xFFF8);
    }
    
    function setChDual() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b001 = dual (independent AGC)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0001);
    }
    
    function setChLeft() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b010 = left (set to this for Mic)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0002);
    }
    
    function setChRight() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b011 = right (line in only)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0003);
    }
    
    function setChDownmix() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b100 = stereo downmix to mono
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0004);
    }
    
    function setRecordFormatPCM() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // bits 4 to 7 determine the encoding format
        // 0b0001 = PCM
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0010);
    }
    
    function setRecordFormatULaw() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0010 = u-law
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0020);
    }
    
    function setRecordFormatALaw() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0011 = a-law
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0030);
    }
    
    function setRecordFormatOgg() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0101 = Ogg Vorbis
         _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0050);
    }

    function setRecordFormatMP3() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0110 = MP3
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0060);
    }
    
    function setRecordBitrate(rate_kbps) {
        _setReg(VS10XX_SCI_WRAMADDR, (0x6000 | (rate_kbps & 0x01FF)));
    }
    
    function setUartBaud(baud) {
        // set UART clock divider to 0 to use "byte speed" to set UART baud
        _writeRam(VS10XX_TX_UART_DIV_ADDR, 0);
        // "Byte Speed" in the datasheet apparently means "baud / bits (incl start, stop, and parity bits)"
        _writeRam(VS10XX_TX_UART_BYTE_SPEED_ADDR, baud / 10);
        // disable flow control (*shrug*)
        _writeRam(VS10XX_TX_PAUSE_GPIO_ADDR, 2);
        // configure the imp side of this mess
        uart.configure(baud, 8, PARITY_NONE, 2, NO_CTSRTS, _uartCb.bindenv(this));
    }
    
    function setUartTxEn(state) {
        if (state) {
            _setRegBit(VS10XX_SCI_AICTRL3, 13, 1);
        } else {
            _setRegBit(VS10XX_SCI_AICTRL3, 13, 0);
        }
    }
    
    function startRecording() {
        recording = true;
        local val = _getReg(VS10XX_SCI_MODE); 
        // set the Encoding and SW_Reset bits in the same transaction to activate codec mode
        _setReg(VS10XX_SCI_MODE, val | 0x1004);
    }
    
    function stopRecording(cb) {
        // set SM_CANCEL bit
        _setRegBit(VS10XX_SCI_MODE, 3, 1);
        recording = false;
        imp.wakeup(REC_STOP_TIMEOUT, function() {
            rx_buffer.writeblob(uart.readblob());
            buffer_ready_cb(rx_buffer);
            rx_buffer = blob(2);
            rx_buffer.seek(0,'b');
            cb();
        }.bindenv(this));
    }
    
    function recordingIsDone() {
        // Check SM_ENCODE bit to see if we're done encoding
        if (_getReg(VS10XX_SCI_MODE) & 0x1000) return false;
        return true;
    }
}
