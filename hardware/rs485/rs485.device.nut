// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class RS485 {

    static ACTIVE_LOW   = 0;
    static ACTIVE_HIGH  = 1;

    _uart   = null;
    _rEn    = null;
    _rPol   = null;
    _wEn    = null;
    _wPol   = null;

    constructor(uart, readEnable = null, writeEnable = null, readPolarity = null, writePolarity = null) {
        _uart   = uart;
        _rEn    = readEnable;
        _rPol   = readPolarity;     // RS485.ACTIVE_LOW or RS485.ACTIVE_HIGH
        _wEn    = writeEnable;
        _wPol   = writePolarity;    // RS485.ACTIVE_LOW or RS485.ACTIVE_HIGH

        // Default polarities
        if (_rPol == null) { _rPol = ACTIVE_LOW; }
        if (_wPol == null) { _wPol = ACTIVE_HIGH; }

        // Assert read enable, clear write enable
        _rEn.configure(DIGITAL_OUT);
        _rEn.write(_rPol);
        _wEn.configure(DIGITAL_OUT);
        _wEn.write(_wPol?0:1);
    }

    function configure(baudRate, dataBits, parity, stopBits, flags, callback) {
        _uart.configure(baudRate, dataBits, parity, stopBits, flags, callback);
    }

    function read() {
        return _uart.read();
    }

    function write(data) {
        // Clear read enable
        if (_rEn != null) {
            _rEn.write(_rPol?0:1);
        }
        // Assert write enable
        if (_wEn != null) {
            _wEn.write(_wPol);
        }
        // Write the data
        _uart.write(data);
        _uart.flush();
        // Clear write enable
        if (_wEn != null) {
            _wEn.write(_wPol?0:1);
        }
        // Assert read enable
        if (_rEn != null) {
            _rEn.write(_rPol);
        }
    }
}

// Usage
// RS485(UART, readEnable, writeEnable, readEnablePolarity, writeEnablePolarity);
rs485   <- RS485(hardware.uart12, hardware.pin7, hardware.pin5, RS485.ACTIVE_LOW, RS485.ACTIVE_HIGH);
// Modbus(UART or RS485, baudRate, dataBits, parity, stopBits, callbackHandler, errorHandler, optional timeout in seconds)
modbus  <- Modbus(rs485, 9200, 8, PARITY_NONE, 1, callbackHandler, errorHandler);
