// =============================================================================
class LineUART {
    
    _pins = null;
    _buf = null;
    _callback = null;
    _eol_chars = null;
    
    // -------------------------------------------------------------------------
    // Constructor require the hardware.uartXX pins that will be used for communication.
    constructor(pins) {
        _pins = pins;

        setbuffersize();
        seteol();
    }
    
    // -------------------------------------------------------------------------
    // This function accepts the usual uart.configure() parameters. The callback 
    // function must accept a buffer (blob) as a parameter which will contain the 
    // uart data read. 
    function configure(speed, word_size, parity, stop, flags, callback = null) {
        
        _pins.configure(speed, word_size, parity, stop, flags, _read.bindenv(this));
        setcallback(callback)
        
        return this;
    }    

    // -------------------------------------------------------------------------
    // Request a specific buffer size. Clears the current buffer. Default is 100 bytes.
    function setbuffersize(buf_size = 100) {
        _buf = blob(buf_size);
        return this;
    }
    

    // -------------------------------------------------------------------------
    // Request specific EOL characters to detect. Default is a carriage return. 
    // Accepts a character (integer), a string or an array of characters.
    function seteol(eol_chars = '\n') {
        _eol_chars = [];
        if (typeof eol_chars == "integer") {
            _eol_chars.push(eol_chars);
        } else if (typeof eol_chars == "string" || typeof eol_chars == "array") {
            foreach (ch in eol_chars) {
                if (typeof ch == "integer") {
                    _eol_chars.push(ch);
                }
            }
        }
        return this;
    }

    
    // -------------------------------------------------------------------------
    // Assigns a new callback function to handle incoming data
    function setcallback(callback = null) {
        _callback = callback;
        return this;
    }
    
    
    // -------------------------------------------------------------------------
    // Writes the provided buffer (string or blob) to the UART. Optionally,
    // an callback can be provided for returning (only) the next response.
    function write(buf, callback = null) {
        _pins.write(buf);
        
        if (callback) {
            local old_callback = _callback;
            local new_callback = callback;
            _callback = function(buf) {
                _callback = old_callback;
                new_callback(buf);
            }.bindenv(this);
        }
        
        return this;
    }
    
    // -------------------------------------------------------------------------
    // Flushes the output buffer to the UART
    function flush() {
        _pins.flush();
        return this;
    }
    
    // -------------------------------------------------------------------------
    // Disables the UART to conserve power
    function disable() {
        _pins.disable();
        return this;
    }
    
    
    // ================[ Private functions ]================
    
    
    // -------------------------------------------------------------------------
    // When the buffer is full or a EOL character is detected, this cleans up and
    // delivers the resulting buffer.
    function _ready(force_return = false) {
        local len = _buf.tell();
        _buf.seek(0);
        local buf = _buf.readblob(len);
        _buf.seek(0);
        if (_callback && !force_return) {
            if (len > 0) _callback(buf);
        } else {
            return buf;
        }
    }
    
    // -------------------------------------------------------------------------
    // Handles the UART events to drain the input buffer into the local buffer.
    function _read() {
        
        // If the callback function has been removed then don't read the UART.
        if (!_callback) return;
        
        local ch = null;
        do {
            ch = _pins.read();
            if (ch == -1) break;
            if (_eol_chars.find(ch) != null) {
                _ready();
                break;
            }
            _buf.writen(ch, 'b');
        } while (_buf.tell() < _buf.len());
        
        if (_buf.tell() == _buf.len()) {
            _ready();
        }
    }

}
