// Modbus RTU Master

class Modbus {

    _uart       = null;
    _charTime   = null;

    _timeout            = null;
    _responseTimer      = null;
    _turnaroundTime     = null;
    
    _receiveBuffer      = null;
    _responseType       = null;
    _deviceAddress      = null;
    _responsePDULength  = null;

    _functionCodes      = null;
    _callbackHandler    = null;
    _genericHandler     = null;
    _errorHandler       = null;

    // uart: preconfigured UART or UART-like object (e.g. RS485 class instance)
    // genericHandler: callback handler to be used when not overriding on a per-function basis
    // errorHandler: callback handler for Modbus exceptions
    constructor(uart, baudRate, dataBits, parity, stopBits, genericHandler, errorHandler, timeout = 1) {
        _uart       = uart;
        _charTime   = 1.0 / baudRate;
        _timeout    = timeout;

        _receiveBuffer  = blob();

        _genericHandler = genericHandler;
        _errorHandler   = errorHandler;

        _init();

        _uart.configure(baudRate, dataBits, parity, stopBits, NO_CTSRTS, _receive.bindenv(this));

    }

    function _init() {

        // Contains the function code and request/response PDU lengths (i.e. not counting address/CRC)
        // null resLen will cause the process function to look for a bytecount field and use that
        _functionCodes = {
            readCoils = {
                fcode   = 0x01,
                reqLen  = 5,
                resLen  = null
            }
            readInputs = {
                fcode   = 0x02,
                reqLen  = 5,
                resLen  = null
            }
            readHoldingRegs = {
                fcode   = 0x03,
                reqLen  = 5,
                resLen  = null
            }
            readInputRegs = {
                fcode   = 0x04,
                reqLen  = 5,
                resLen  = null
            }
            writeSingleCoil = {
                fcode   = 0x05,
                reqLen  = 5,
                resLen  = 5
            }
            writeSingleReg = {
                fcode   = 0x06,
                reqLen  = 5,
                resLen  = 5
            }
            writeMultipleCoils = {
                fcode   = 0x0F,
                reqLen  = function(n) { return 6 + math.ceil(n/8.0); },
                resLen  = 5
            }
            writeMultipleRegs = {
                fcode   = 0x10,
                reqLen  = function(n) { return 6 + n*2; },
                resLen  = 5
            }
        }

        enum MODBUS_EXCEPTION {
            ILLEGAL_FUNCTION    = 0x01,
            ILLEGAL_DATA_ADDR   = 0x02,
            ILLEGAL_DATA_VAL    = 0x03,
            SERVER_DEVICE_FAIL  = 0x04,
            RESPONSE_TIMEOUT    = 0x10,
            INVALID_CRC         = 0x11,
            WAITING_FOR_RESPONSE= 0x12, // Still waiting for a response/timeout from the previous command
            INVALID_ARG_LENGTH  = 0x13, // A write function has been passed an invalid number of data bytes
            INVALID_DEVICE_ADDR = 0x14
        }

        // CRC byte values (used to speed up CRC calculation)
        const CRC_HIGH  = "\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40\x00\xC1\x81\x40\x01\xC0\x80\x41\x00\xC1\x81\x40\x01\xC0\x80\x41\x01\xC0\x80\x41\x00\xC1\x81\x40";
        const CRC_LOW   = "\x00\xC0\xC1\x01\xC3\x03\x02\xC2\xC6\x06\x07\xC7\x05\xC5\xC4\x04\xCC\x0C\x0D\xCD\x0F\xCF\xCE\x0E\x0A\xCA\xCB\x0B\xC9\x09\x08\xC8\xD8\x18\x19\xD9\x1B\xDB\xDA\x1A\x1E\xDE\xDF\x1F\xDD\x1D\x1C\xDC\x14\xD4\xD5\x15\xD7\x17\x16\xD6\xD2\x12\x13\xD3\x11\xD1\xD0\x10\xF0\x30\x31\xF1\x33\xF3\xF2\x32\x36\xF6\xF7\x37\xF5\x35\x34\xF4\x3C\xFC\xFD\x3D\xFF\x3F\x3E\xFE\xFA\x3A\x3B\xFB\x39\xF9\xF8\x38\x28\xE8\xE9\x29\xEB\x2B\x2A\xEA\xEE\x2E\x2F\xEF\x2D\xED\xEC\x2C\xE4\x24\x25\xE5\x27\xE7\xE6\x26\x22\xE2\xE3\x23\xE1\x21\x20\xE0\xA0\x60\x61\xA1\x63\xA3\xA2\x62\x66\xA6\xA7\x67\xA5\x65\x64\xA4\x6C\xAC\xAD\x6D\xAF\x6F\x6E\xAE\xAA\x6A\x6B\xAB\x69\xA9\xA8\x68\x78\xB8\xB9\x79\xBB\x7B\x7A\xBA\xBE\x7E\x7F\xBF\x7D\xBD\xBC\x7C\xB4\x74\x75\xB5\x77\xB7\xB6\x76\x72\xB2\xB3\x73\xB1\x71\x70\xB0\x50\x90\x91\x51\x93\x53\x52\x92\x96\x56\x57\x97\x55\x95\x94\x54\x9C\x5C\x5D\x9D\x5F\x9F\x9E\x5E\x5A\x9A\x9B\x5B\x99\x59\x58\x98\x88\x48\x49\x89\x4B\x8B\x8A\x4A\x4E\x8E\x8F\x4F\x8D\x4D\x4C\x8C\x44\x84\x85\x45\x87\x47\x46\x86\x82\x42\x43\x83\x41\x81\x80\x40";
    }

    //  -----------------  //
    //  Private functions  //
    //  -----------------  //

    // Generate 16-bit CRC using lookup tables
    function _generateCRC(frame) {
        local loByte = 0xFF;
        local hiByte = 0xFF;
        local index;
        foreach(frameByte in frame) {
            index = loByte ^ frameByte;
            loByte = hiByte ^ CRC_HIGH[index];
            hiByte = CRC_LOW[index];
        }
       return (hiByte<<8) | loByte;
    }

    // Verify CRC for a given frame, return boolean
    function _hasValidCRC(frame, length) {
        frame.seek(0);
        local expectedCRC = _generateCRC(frame.readblob(length - 2));
        local receivedCRC = frame.readn('w');
        if (receivedCRC == expectedCRC) {
            return true;
        } else {
            server.log(format("Expected CRC: 0x%04X", expectedCRC));
            server.log(format("Received CRC: 0x%04X", receivedCRC));
            return false;
        }
    }

    // Callback for response timer expiration
    function _responseTimeout() {
        server.error("Response timed out.");
        local functionCode = _responseType;
        _clearPreviousCommand();
        _errorHandler(functionCode, MODBUS_EXCEPTION.RESPONSE_TIMEOUT);
    }

    // Forget everything about the previous command and prepare to send a new one
    function _clearPreviousCommand() {
        if (_responseTimer != null) {
            imp.cancelwakeup(_responseTimer);
            _responseTimer = null;
        }
        _responseType = null;
        _deviceAddress = null;
        _responsePDULength  = null;
        _receiveBuffer.seek(0);
    }

    // Validates the Modbus RTU frame, strips the address/CRC, and passes a Modbus PDU to the callback function
    // We can't detect the end of frame as per the Modbus specification (too small an interval),
    // so we figure out what PDU we're looking for and wait for the correct number of bytes before validating it.
    function _processBuffer() {
        // Use initial pointer position to mark the end of valid data, as the actual blob length may be larger
        local bufferLength = _receiveBuffer.tell();
        _receiveBuffer.seek(0);
        local address = _receiveBuffer.readn('b');
        if (address == _deviceAddress) {
            if (bufferLength >= 5) {
                local functionCode = _receiveBuffer.readn('b');
                // Check exception bit. Is this an exception response? If so, call the exception handler
                if (functionCode & 0x80) {
                    local exceptionCode = _receiveBuffer.readn('b');
                    _clearPreviousCommand();
                    if (_hasValidCRC(_receiveBuffer, bufferLength)) {
                        _errorHandler(functionCode, exceptionCode);
                    } else {
                        _errorHandler(functionCode, MODBUS_EXCEPTION.INVALID_CRC);
                    }
                } else {
                    if (_responsePDULength == null) {
                        _responsePDULength = _receiveBuffer.readn('b') + 2;
                    }
                    // If the frame is the correct length, validate the CRC
                    if (bufferLength >= _responsePDULength+3) {
                        if (_hasValidCRC(_receiveBuffer, bufferLength)) {
                            // reset the timeout and pass the PDU to the callback
                            _receiveBuffer.seek(1);
                            if (functionCode == _responseType) {
                                local PDU = _receiveBuffer.readblob(bufferLength - 3);
                                _clearPreviousCommand();
                                switch (functionCode) {
                                    case _functionCodes.readCoils.fcode:
                                    case _functionCodes.readInputs.fcode:
                                    case _functionCodes.readHoldingRegs.fcode:
                                    case _functionCodes.readInputRegs.fcode:
                                        _readCb(PDU);
                                        break;
                                    case _functionCodes.writeSingleCoil.fcode:
                                    case _functionCodes.writeSingleReg.fcode:
                                        _writeSingleCb(PDU);
                                        break;
                                    case _functionCodes.writeMultipleCoils.fcode:
                                    case _functionCodes.writeMultipleRegs.fcode:
                                        _writeMultipleCb(PDU);
                                        break;
                                }
                            }
                        } else {
                            _clearPreviousCommand();
                            _errorHandler(functionCode, MODBUS_EXCEPTION.INVALID_CRC);
                        }
                    } else {
                        // If we're still waiting for a complete packet, reset the pointer to its original position
                        _receiveBuffer.seek(bufferLength);
                    }
                }
            } else {
                _receiveBuffer.seek(bufferLength);
            }
        } else {
            _receiveBuffer.seek(0);
            server.error("Received reply from unexpected device.");
        }
    }

    // Read UART data into buffer
    function _receive() {
        local byte = _uart.read();
        while ((byte != -1) && (_receiveBuffer.len() < 300)) {
            _receiveBuffer.writen(byte, 'b');
            byte = _uart.read();
        }
        if ((_responseType != null) && (_receiveBuffer.len() > 0)) {
            // Attempt to process the buffer as a complete frame
            _processBuffer();
        }
    }

    // Assemble and transmit a Modbus frame
    // Takes a complete application-level PDU, adds destination address and CRC, then sends
    function _send(deviceAddress, PDU, responseLength, callbackHandler) {
        // Make sure we're not waiting on a response to a previous command
        if (_responseTimer != null) {
            server.error("Error sending PDU: waiting for previous response.");
            throw MODBUS_EXCEPTION.WAITING_FOR_RESPONSE;
        }
        // Clear previous response attributes
        _clearPreviousCommand();

        // If unicast, set expected response attributes
        if (deviceAddress > 0x00) {
            _deviceAddress = deviceAddress;
            _responseType = PDU[0];
            _responsePDULength = responseLength;
            if (callbackHandler != null) {
                _callbackHandler = callbackHandler;
            } else {
                _callbackHandler = _genericHandler;
            }
        }

        // Assemble frame (address + PDU + CRC)
        local frame = blob();
        frame.writen(deviceAddress, 'b');
        frame.writeblob(PDU);
        local CRC = _generateCRC(frame);
        frame.writen(CRC, 'w');

        // Send frame
        _uart.write(frame);

        // If broadcast, block for turnaround time. Otherwise, start response timer.
        if (deviceAddress == 0x00) {
            imp.sleep(_turnaroundTime);
        } else {
            _responseTimer = imp.wakeup(_timeout, _responseTimeout.bindenv(this));
        }
    }

    // _readMulti
    // Used for Read Coils (0x01), Read Discrete Inputs (0x02),
    // Read Holding Registers (0x03), Read Input Registers (0x04)
    function _readMulti(functionCode, deviceAddress, startingAddress, quantity, callbackHandler = null) {
        if ((deviceAddress <= 0x00) || (deviceAddress > 0xFF)) {
            server.error("Invalid device address");
            throw MODBUS_EXCEPTION.INVALID_DEVICE_ADDR;
        }
        // Generate PDU
        local PDU = blob(functionCode.reqLen);
        PDU.writen(functionCode.fcode, 'b');
        PDU.writen(swap2(startingAddress), 'w');
        PDU.writen(swap2(quantity),'w');
        // Generate and send frame
        _send(deviceAddress, PDU, functionCode.resLen, callbackHandler);
    }

    function _readCb(PDU) {
        // Strip the function code and byte count, then pass data blob to callback
        PDU.seek(2);
        _callbackHandler(PDU.readblob(PDU.len() - 2));
    }

    function _writeSingleCb(PDU) {
        // Placeholder for possible future use
    }
    
    function _writeMultipleCb(PDU) {
        // Placeholder for possible future use
    }


    //  ----------------  //
    //  Public functions  //
    //  ----------------  //

    // isBusy() - return true if currently waiting for a response
    function isBusy() {
        return _responseTimer ? true : false;
    }

    // 0x01 - Read Coils
    // Reads status of 1-2000 contiguous coils in a single device
    // Callback arg: blob of length (quantity / 8), rounded up, one coil per bit, LSB->MSB (as per Modbus spec)
    function readCoils(deviceAddress, startingAddress, quantity, callbackHandler = null) {
        server.log(format("Reading %i coils", quantity));
        _readMulti(_functionCodes.readCoils, deviceAddress, startingAddress, quantity, callbackHandler);
    }

    // 0x02 - Read Discrete Inputs
    // Reads status of 1-2000 contiguous inputs in a single device
    // Callback arg: blob of length (quantity / 8), rounded up, one input per bit, LSB->MSB (as per Modbus spec)
    function readInputs(deviceAddress, startingAddress, quantity, callbackHandler = null) {
        server.log(format("Reading %i inputs", quantity));
        _readMulti(_functionCodes.readInputs, deviceAddress, startingAddress, quantity, callbackHandler);
    }

    // 0x03 - Read Holding Registers
    // Read the values of up to 125 contiguous 16-bit holding registers
    // Callback arg: big-endian blob of length (quantity * 2), beginning with the startingAddress register
    function readHoldingRegs(deviceAddress, startingAddress, quantity, callbackHandler = null) {
        server.log(format("Reading %i holding registers", quantity));
        _readMulti(_functionCodes.readHoldingRegs, deviceAddress, startingAddress, quantity, callbackHandler);
    }

    // 0x04 - Read Input Registers
    // Read the values of up to 125 contiguous 16-bit input registers
    // Callback arg: big-endian blob of length (quantity * 2), beginning with the startingAddress register
    function readInputRegs(deviceAddress, startingAddress, quantity, callbackHandler = null) {
        server.log(format("Reading %i input registers", quantity));
        _readMulti(_functionCodes.readInputRegs, deviceAddress, startingAddress, quantity, callbackHandler);
    }

    // 0x05 - Write Single Coil
    // coilValue argument is 0 (off) or 1 (on)
    // (callbackHandler is not implemented)
    function writeSingleCoil(deviceAddress, coilAddress, coilValue, callbackHandler = null) {
        server.log(format("Setting coil 0x%02X to %i", coilAddress, coilValue));
        // Generate PDU
        local PDU = blob(_functionCodes.writeSingleCoil.reqLen);
        PDU.writen(_functionCodes.writeSingleCoil.fcode, 'b');
        PDU.writen(swap2(coilAddress), 'w');
        PDU.writen(coilValue ? 0xFF : 0x00, 'b');
        PDU.writen(0x00, 'b'); 
        // Send
        _send(deviceAddress, PDU, _functionCodes.writeSingleCoil.resLen, callbackHandler);
    }

    // 0x06 - Write Single Register
    // regValue argument is a 16-bit value (anything >16 bits will be truncated to the least sig. 16 bits)
    // (callbackHandler is not implemented)
    function writeSingleReg(deviceAddress, regAddress, regValue, callbackHandler = null) {
        server.log(format("Setting register 0x%02X to 0x%02X", regAddress, regValue));
        // Generate PDU
        local PDU = blob(_functionCodes.writeSingleReg.reqLen);
        PDU.writen(_functionCodes.writeSingleReg.fcode, 'b');
        PDU.writen(swap2(regAddress), 'w');
        PDU.writen(swap2(regValue), 'w');
        // Send
        _send(deviceAddress, PDU, _functionCodes.writeSingleReg.resLen, callbackHandler);
    }

    // 0x0F - Write Multiple Coils
    // coilValues argument should be a blob, startingAddress coil at LSB of first byte
    // the rest, LSB->MSB byte by byte (so total size of coilValues should be ceil(quantity / 8))
    // (callbackHandler is not implemented)
    function writeMultipleCoils(deviceAddress, startingAddress, quantity, coilValues, callbackHandler = null) {
        if ((deviceAddress < 0x00) || (deviceAddress > 0xFF)) {
            server.error("Invalid device address");
            throw MODBUS_EXCEPTION.INVALID_DEVICE_ADDR;
        }
        // Make sure we've been passed the correct length blob
        local numBytes = math.ceil(quantity/8.0);
        if (typeof coilValues != "blob") {
            local val = coilValues;
            coilValues = blob();
            coilValues.writen(val, 'b');
        }
        if (coilValues.len() != numBytes) {
            server.error("coilValues wrong length");
            throw MODBUS_EXCEPTION.INVALID_ARG_LENGTH;
        }
        server.log("Setting " + quantity + " coils");
        // Generate PDU
        local PDU = blob(_functionCodes.writeMultipleCoils.reqLen(quantity));
        PDU.writen(_functionCodes.writeMultipleCoils.fcode, 'b');
        PDU.writen(swap2(startingAddress), 'w');
        PDU.writen(swap2(quantity), 'w');
        PDU.writen(numBytes, 'b');
        PDU.writeblob(coilValues);
        // Send
        _send(deviceAddress, PDU, _functionCodes.writeMultipleCoils.resLen, callbackHandler);
    }

    // 0x10 - Write Multiple Registers
    // regValues argument should be a big-endian blob of length (quantity * 2)
    // and should begin with the 16-bit value of startingAddress
    // (callbackHandler is not implemented)
    function writeMultipleRegs(deviceAddress, startingAddress, quantity, regValues, callbackHandler = null) {
        if ((deviceAddress < 0x00) || (deviceAddress > 0xFF)) {
            server.error("Invalid device address");
            throw MODBUS_EXCEPTION.INVALID_DEVICE_ADDR;
        }
        // Make sure we've been passed the correct length blob
        local numBytes = quantity * 2;
        if (typeof regValues != "blob") {
            local val = regValues;
            regValues = blob();
            regValues.writen(val, 'b');
        }
        if (regValues.len() != numBytes) {
            server.error("regValues wrong length");
            throw MODBUS_EXCEPTION.INVALID_ARG_LENGTH;
        }
        server.log("Writing " + quantity + " registers");
        // Generate PDU
        local PDU = blob(_functionCodes.writeMultipleRegs.reqLen(quantity));
        PDU.writen(_functionCodes.writeMultipleRegs.fcode, 'b');
        PDU.writen(swap2(startingAddress), 'w');
        PDU.writen(swap2(quantity), 'w');
        PDU.writen(numBytes, 'b');
        PDU.writeblob(regValues);
        // Send
        _send(deviceAddress, PDU, _functionCodes.writeMultipleRegs.resLen, callbackHandler);
    }
}

function errorHandler(functionCode, exceptionCode) {
    server.error(format("Function: 0x%02X, Exception: 0x%02X", functionCode, exceptionCode));
    // Handle some errors
}

function callbackHandler(PDU) {
    // Generic handler for callbacks from read functions
}

uart <- hardware.uart12;
// UART pins, baudRate, dataBits, parity, stopBits, callbackHandler, errorHandler, timeout (optional, default=1)
modbus <- Modbus(uart, 19200, 8, PARITY_NONE, 1, callbackHandler, errorHandler);