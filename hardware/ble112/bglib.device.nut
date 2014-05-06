/*
BGLib for Squirrel
==================

This implements the BGLib library for Bluegiga's BLE112 Bluetooth Smart module.
 
It assumes you have connected from the Imp to the BLE112:
 
- UART (uart1289 is recommended as flow control is important)
- Wake pin (optional depending on BLE112 configuration)
- Reset pin (optional but really helpful as software reset is not always reliable)

The wake control is made available but not fully automated. If you want to control 
the sleep cycles from BGLib then you will need to pull the wake pin high before
sending a command and wait for "hardware_io_port_status" events to indicate the 
BLE112 is awake. After completing the command, sent the pin low again to let the
device go back to sleep when it is ready.

Packet mode should be configured to match the device configuration. If there is 
no flow control you should turn packet mode on.

Some useful references:
 
- [Bluetooth crash course] (http://flyingcarsandstuff.com/projects/bluetooth-low-energy/bluetooth-smartble-crash-course/)
- [Bluetooth specs] (https://developer.bluetooth.org/gatt/Pages/Definition-Browser.aspx)
- [BLE112 v.1.2.2 API Reference] (https://www.bluegiga.com/en-US/download/?file=P84Ulj3ZRiyiFv4TU51uVA)
- [BLE112 Datasheets and App notes] (https://www.bluegiga.com/en-US/products/bluetooth-4.0-modules/ble112-bluetooth--smart-module/documentation/)
- [BGLib/BGAPI explanation] (https://bluegiga.zendesk.com/entries/22412436--REFERENCE-What-is-the-difference-between-BGScript-BGAPI-and-BGLib)
- [BGAPI protocol breakdown] (https://bluegiga.zendesk.com/entries/23791201-BGAPI-how-to-composite-BGAPI-binary-commands)
- [Bluegiga forum] (https://bluegiga.zendesk.com/forums/21316731-Bluetooth-Smarth)
- [Arduino BGLib] (https://github.com/jrowberg/bglib/blob/master/Arduino/BGLib.cpp)

To do list:

- Time-out requests as sometimes things go wrong.

*/

//------------------------------------------------------------------------------


class BGLib {
    
    _uart = null;
    _wake = null;
    _reset_l = null;
    _packet_m = false;
    _baud = null;
    _response_callbacks = null;
    _event_callbacks = null;
    _uart_buffer = null;

    // -------------------------------------------------------------------------
    constructor(uart, wake, reset_l, packet_m = false, baud = 57600) {
        
        init();
        
        _uart = uart;
        _wake = wake;
        _reset_l = reset_l;
        _packet_m = packet_m;
        _baud = baud;

        _response_callbacks = [];
        _event_callbacks = {};
        _uart_buffer = "";
        
        _uart.configure(_baud, 8, PARITY_NONE, 1, 0, read_uart.bindenv(this));
        if (_wake) {
            _wake.configure(DIGITAL_OUT);
            _wake.write(1); // Pull high to keep awake
        }
        if (_reset_l) {
            _reset_l.configure(DIGITAL_OUT);
            _reset_l.write(1); // Pull high to prevent reset
        }
    }
    
    // -------------------------------------------------------------------------
    function init() {

        const BLE_TIMEOUT      = 20;
        const BLE_MAX_PAYLOAD  = 0x7FF;
        const BLE_HEADER_SIZE  = 4;
        const BLE_CONN_BACKOFF = 60;
        const BLE_DUMP_MAX     = 200;

        enum BLE_CLASS_ID {
            SYSTEM     = 0x00, // Provides access to system functions
            PERSISTENT = 0x01, // Provides access the persistence store (parameters)
            ATT_DB     = 0x02, // Provides access to local GATT database
            CONNECTION = 0x03, // Provides access to connection management functions
            ATT_CLIENT = 0x04, // Functions to access remote devices GATT database
            SECURITY   = 0x05, // Bluetooth low energy security functions
            GAP        = 0x06, // GAP functions
            HARDWARE   = 0x07, // Provides access to hardware such as timers and ADC
            TEST       = 0x08, // Not implemented
            DFU        = 0x09  // Provides tools for uploading new programming over USART
        }
                
        enum BLE_MESSAGE_TYPE {
            COMMAND    = 0x00, // Commands and Command Responses
            EVENT      = 0x80  // Event notifications
        }
        
        enum BLE_ERRORS {
            INVALID_PARAMETER = 0x0180,
            DEVICE_IN_WRONG_STATE = 0x0181,
            OUT_OF_MEMORY = 0x0182,
            FEATURE_NOT_IMPLEMENTED = 0x0183,
            COMMAND_NOT_RECOGNIZED = 0x0184,
            TIMEOUT = 0x0185,
            NOT_CONNECTED = 0x0186,
            FLOW = 0x0187,
            USER_ATTRIBUTE = 0x0188,
            INVALID_LICENSE_KEY = 0x0189,
            COMMAND_TOO_LONG = 0x018A,
            OUT_OF_BONDS = 0x018B,
            AUTHENTICATION_FAILURE = 0x0205,
            PIN_OR_KEY_MISSING = 0x0206,
            MEMORY_CAPACITY_EXCEEDED = 0x0207,
            CONNECTION_TIMEOUT = 0x0208,
            CONNECTION_LIMIT_EXCEEDED = 0x0209,
            COMMAND_DISALLOWED = 0x020C,
            INVALID_COMMAND_PARAMETERS = 0x0212,
            REMOTE_USER_TERMINATED_CONNECTION = 0x0213,
            CONNECTION_TERMINATED_BY_LOCAL_HOST = 0x0216,
            LL_RESPONSE_TIMEOUT = 0x0222,
            LL_INSTANT_PASSED = 0x0228,
            CONTROLLER_BUSY = 0x023A,
            UNACCEPTABLE_CONNECTION_INTERVAL = 0x023B,
            DIRECTED_ADVERTISING_TIMEOUT = 0x023C,
            MIC_FAILURE = 0x023D,
            CONNECTION_FAILED_TO_BE_ESTABLISHED = 0x023E,
            PASSKEY_ENTRY_FAILED = 0x0301,
            OOB_DATA_IS_NOT_AVAILABLE = 0x0302,
            AUTHENTICATION_REQUIREMENTS = 0x0303,
            CONFIRM_VALUE_FAILED = 0x0304,
            PAIRING_NOT_SUPPORTED = 0x0305,
            ENCRYPTION_KEY_SIZE = 0x0306,
            COMMAND_NOT_SUPPORTED = 0x0307,
            UNSPECIFIED_REASON = 0x0308,
            REPEATED_ATTEMPTS = 0x0309,
            INVALID_PARAMETERS = 0x030A,
            INVALID_HANDLE = 0x0401,
            READ_NOT_PERMITTED = 0x0402,
            WRITE_NOT_PERMITTED = 0x0403,
            INVALID_PDU = 0x0404,
            INSUFFICIENT_AUTHENTICATION = 0x0405,
            REQUEST_NOT_SUPPORTED = 0x0406,
            INVALID_OFFSET = 0x0407,
            INSUFFICIENT_AUTHORIZATION = 0x0408,
            PREPARE_QUEUE_FULL = 0x0409,
            ATTRIBUTE_NOT_FOUND = 0x040A,
            ATTRIBUTE_NOT_LONG = 0x040B,
            INSUFFICIENT_ENCRYPTION_KEY_SIZE = 0x040C,
            INVALID_ATTRIBUTE_VALUE_LENGTH = 0x040D,
            UNLIKELY_ERROR = 0x040E,
            INSUFFICIENT_ENCRYPTION = 0x040F,
            UNSUPPORTED_GROUP_TYPE = 0x0410,
            INSUFFICIENT_RESOURCES = 0x0411,
            APPLICATION_ERROR_CODES = 0x0480
        }
        
        enum BLE_SYSTEM_ENDPOINTS
        {
            SYSTEM_ENDPOINT_API    = 0,
            SYSTEM_ENDPOINT_TEST   = 1,
            SYSTEM_ENDPOINT_SCRIPT = 2,
            SYSTEM_ENDPOINT_USB    = 3,
            SYSTEM_ENDPOINT_UART0  = 4,
            SYSTEM_ENDPOINT_UART1  = 5
        };
        
        enum BLE_ATTRIBUTES_ATTRIBUTE_CHANGE_REASON
        {
            ATTRIBUTES_ATTRIBUTE_CHANGE_REASON_WRITE_REQUEST      = 0,
            ATTRIBUTES_ATTRIBUTE_CHANGE_REASON_WRITE_COMMAND      = 1,
            ATTRIBUTES_ATTRIBUTE_CHANGE_REASON_WRITE_REQUEST_USER = 2
        };
        
        enum BLE_ATTRIBUTES_ATTRIBUTE_STATUS_FLAG
        {
            ATTRIBUTES_ATTRIBUTE_STATUS_FLAG_NOTIFY   = 1,
            ATTRIBUTES_ATTRIBUTE_STATUS_FLAG_INDICATE = 2
        };
        
        enum BLE_CONNECTION_CONNSTATUS
        {
            CONNECTION_CONNECTED         = 1,
            CONNECTION_ENCRYPTED         = 2,
            CONNECTION_COMPLETED         = 4,
            CONNECTION_PARAMETERS_CHANGE = 8
        };
        
        enum BLE_ATTCLIENT_ATTRIBUTE_VALUE_TYPES
        {
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_READ             = 0,
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_NOTIFY           = 1,
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_INDICATE         = 2,
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_READ_BY_TYPE     = 3,
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_READ_BLOB        = 4,
            ATTCLIENT_ATTRIBUTE_VALUE_TYPE_INDICATE_RSP_REQ = 5
        };
        
        enum BLE_SM_BONDING_KEY
        {
            SM_BONDING_KEY_LTK         = 0X01,
            SM_BONDING_KEY_ADDR_PUBLIC = 0X02,
            SM_BONDING_KEY_ADDR_STATIC = 0X04,
            SM_BONDING_KEY_IRK         = 0X08,
            SM_BONDING_KEY_EDIVRAND    = 0X10,
            SM_BONDING_KEY_CSRK        = 0X20,
            SM_BONDING_KEY_MASTERID    = 0X40
        };
        
        enum BLE_SM_IO_CAPABILITY
        {
            SM_IO_CAPABILITY_DISPLAYONLY     = 0,
            SM_IO_CAPABILITY_DISPLAYYESNO    = 1,
            SM_IO_CAPABILITY_KEYBOARDONLY    = 2,
            SM_IO_CAPABILITY_NOINPUTNOOUTPUT = 3,
            SM_IO_CAPABILITY_KEYBOARDDISPLAY = 4
        };
        
        enum BLE_GAP_ADDRESS_TYPE
        {
            GAP_ADDRESS_TYPE_PUBLIC = 0,
            GAP_ADDRESS_TYPE_RANDOM = 1
        };
        
        enum BLE_GAP_DISCOVERABLE_MODE
        {
            GAP_NON_DISCOVERABLE      = 0,
            GAP_LIMITED_DISCOVERABLE  = 1,
            GAP_GENERAL_DISCOVERABLE  = 2,
            GAP_BROADCAST             = 3,
            GAP_USER_DATA             = 4
        };
        
        enum BLE_GAP_CONNECTABLE_MODE
        {
            GAP_NON_CONNECTABLE        = 0,
            GAP_DIRECTED_CONNECTABLE   = 1,
            GAP_UNDIRECTED_CONNECTABLE = 2,
            GAP_SCANNABLE_CONNECTABLE  = 3
        };
        
        enum BLE_GAP_DISCOVER_MODE
        {
            GAP_DISCOVER_LIMITED     = 0,
            GAP_DISCOVER_GENERIC     = 1,
            GAP_DISCOVER_OBSERVATION = 2
        };
        
        enum BLE_GAP_AD_TYPES
        {
            GAP_AD_TYPE_NONE                 = 0,
            GAP_AD_TYPE_FLAGS                = 1,
            GAP_AD_TYPE_SERVICES_16BIT_MORE  = 2,
            GAP_AD_TYPE_SERVICES_16BIT_ALL   = 3,
            GAP_AD_TYPE_SERVICES_32BIT_MORE  = 4,
            GAP_AD_TYPE_SERVICES_32BIT_ALL   = 5,
            GAP_AD_TYPE_SERVICES_128BIT_MORE = 6,
            GAP_AD_TYPE_SERVICES_128BIT_ALL  = 7,
            GAP_AD_TYPE_LOCALNAME_SHORT      = 8,
            GAP_AD_TYPE_LOCALNAME_COMPLETE   = 9,
            GAP_AD_TYPE_TXPOWER              = 10
        };
        
        enum BLE_GAP_ADVERTISING_POLICY
        {
            GAP_ADV_POLICY_ALL               = 0,
            GAP_ADV_POLICY_WHITELIST_SCAN    = 1,
            GAP_ADV_POLICY_WHITELIST_CONNECT = 2,
            GAP_ADV_POLICY_WHITELIST_ALL     = 3
        };
        
        enum BLE_GAP_SCAN_POLICY
        {
            GAP_SCAN_POLICY_ALL       = 0,
            GAP_SCAN_POLICY_WHITELIST = 1
        };
        
        
        enum BLE_PARAMETER_TYPES
        {
            BLE_MSG_PARAMETER_UINT8      = 2,
            BLE_MSG_PARAMETER_INT8       = 3,
            BLE_MSG_PARAMETER_UINT16     = 4,
            BLE_MSG_PARAMETER_INT16      = 5,
            BLE_MSG_PARAMETER_UINT32     = 6,
            BLE_MSG_PARAMETER_INT32      = 7,
            BLE_MSG_PARAMETER_UINT8ARRAY = 8,
            BLE_MSG_PARAMETER_STRING     = 9,
            BLE_MSG_PARAMETER_HWADDR     = 10
        };        
    }
    
    // -------------------------------------------------------------------------
    function log(type, message) {
        
        if ("log" in _event_callbacks) {
            _event_callbacks.log(type, message);
        } else if (type == "ERR") {
            server.error(format("%s: %s", type, message));
        } else if (type == "SEND" || type == "RECV") {
            server.log(format("%s: %s", type, hexdump(message)));
        } else {
            server.log(format("%s: %s", type, message));
        }
        
    }
    
    // -------------------------------------------------------------------------
    function hexdump(dump, ascii = true) {
        local dbg = "";
        foreach (ch in dump) {
            dbg += format("%02x ", ch)
            if (ch >= 32 && ch <= 126 && ascii) dbg += format("[%c] ", ch);
            if (dbg.len() > BLE_DUMP_MAX) {
                dbg += "... ";
                break;
            }
        }
        return (dbg.len() > 0) ? dbg.slice(0, -1) : "";
    }

    //------------------------------------------------------------------------------------------------------------------------------
    function hex_to_int(str) {
        // Parses a hex string and turns it into an integer
        local hex = 0x0000;
        foreach (ch in str.toupper()) {
            local nibble;
            if (ch >= '0' && ch <= '9') {
                nibble = (ch - '0');
            } else {
                nibble = (ch - 'A' + 10);
            }
            hex = (hex << 4) + nibble;
        }
        return hex;
    }
    
    //------------------------------------------------------------------------------------------------------------------------------
    function string_to_addr(address) {
        assert(address.len() == 17);
        return format("%c%c%c%c%c%c", 
                    hex_to_int(address.slice(15,17)),
                    hex_to_int(address.slice(12,14)),
                    hex_to_int(address.slice( 9,11)),
                    hex_to_int(address.slice( 6, 8)),
                    hex_to_int(address.slice( 3, 5)),
                    hex_to_int(address.slice( 0, 2))
                    );
    }

    //------------------------------------------------------------------------------------------------------------------------------
    function addr_to_string(payload) {
        assert(payload.len() == 6);
        return format("%02x:%02x:%02x:%02x:%02x:%02x", 
                    payload[5],
                    payload[4], 
                    payload[3], 
                    payload[2], 
                    payload[1], 
                    payload[0]);
    }
    
    //------------------------------------------------------------------------------------------------------------------------------
    function addr_type_to_string(addr_type) {
        return (addr_type == 0) ? "public" : "random";
    }
    
    //------------------------------------------------------------------------------------------------------------------------------
    function string_to_addr_type(addr_type) {
        return (addr_type == "public") ? 0 : 1;
    }
    
    // -------------------------------------------------------------------------
    function halt() {
        if (_reset_l) _reset_l.write(0);
    }

    // -------------------------------------------------------------------------
    function reboot() {
        if (_reset_l) {
            _reset_l.write(0); 
            imp.wakeup(0.1, function() {
                _reset_l.write(1);
                _uart_buffer = "";
            }.bindenv(this))
        }
    }
    
    // -------------------------------------------------------------------------
    function wake() {
        if (_wake) _wake.write(1);
    }
    
    // -------------------------------------------------------------------------
    function sleep() {
        if (_wake) _wake.write(0);
    }

    // -------------------------------------------------------------------------
    function fire_response(event) {
        
        // Parse out the result
        local result = "unknown";
        if ("result" in event) {
            switch (event.result) {
                case 0x00:
                    result = "OK";
                    break;
                case "timeout":
                    result = "timeout";
                    break;
                default:
                    if (typeof event.result == "integer") {
                        result = format("Error 0x%04x", event.result);
                    }
                    break;
            }
        }
        
        // Find the original callback in the queue and fire it
        for (local i = 0; i < _response_callbacks.len(); i++) {
            local cb = _response_callbacks[i];
            
            if (cb.cid == event.cid && cb.cmd == event.cmd) {
                imp.cancelwakeup(cb.timer); cb.timer = null;
                _response_callbacks.remove(i);
                
                if (cb.callback != null) {
                    log("LOG", format("resp %s: %s", event.name, result)); 
                    result = null;
                    
                    cb.callback(event);
                }
                break;
            }
        }
        
        if (result != null) {
            log("LOG", format("resp %s: %s (unhandled)", event.name, result))
        }
    }

    // -------------------------------------------------------------------------
    function fire_event(event) {

        if (event.cid == BLE_CLASS_ID.SYSTEM && event.cmd == 0) {
            // After the system_boot event the device has just booted so we
            // have no use for old callbacks. Clear them.
            _response_callbacks.clear();
        }
        
        // Find the event handler registered and fire it
        if (event.name in _event_callbacks) {
            log("LOG", "event " + event.name);
            _event_callbacks[event.name](event);
        } else {
            log("LOG", "event " + event.name + " (unhandled)");
        }
    }
    
    // -------------------------------------------------------------------------
    function send_command(name, cid, cmd, payload, callback = null) {
        
        log("LOG", format("call %s", name));
        
        // Queue the callback, build the packet and send it off
        local command = {name=name, cid=cid, cmd=cmd, callback=callback};
        local timer = imp.wakeup(BLE_TIMEOUT, function() {
            // The timeout has expired. Send an event.
            command.result <- "timeout";
            fire_response(command);
        }.bindenv(this));
        
        command.timer <- timer;
        _response_callbacks.push(command)
        
        local len = payload == null ? 0 : payload.len();
        local header = format("%c%c%c%c", (len >> 8) & 0x07, len & 0xFF, cid, cmd);
        uart_write(header, payload);
    }
    
    // -------------------------------------------------------------------------
    function on(event, callback) {
        if (callback == null) {
            if (event in _event_callbacks) {
                delete _event_callbacks[event];
            }
        } else {
            _event_callbacks[event] <- callback;
        }
    }
    
    
    // -------------------------------------------------------------------------
    function uart_write(header, payload) {
        log("SEND", payload == null ? header : header + payload);
        
        local packet_size = null;
        if (_packet_m) {
            if (payload == null) {
                packet_size = format("%c", header.len(), 0x20);
            } else {
                packet_size = format("%c", header.len() + payload.len(), 0x20);
            }
        }
        
        if (packet_size != null) _uart.write(packet_size);
        _uart.write(header);
        if (payload != null) _uart.write(payload);
        
    }
    
    // -------------------------------------------------------------------------
    function read_uart() {

        // Read the complete UART buffer 
        local ch = null;
        while ((ch = _uart.read()) != -1) {
            _uart_buffer += format("%c", ch);
            
            // We can back off reading more than this many bytes into a buffer as
            // flow control will stop the other side.
            if (_uart_buffer.len() >= 0x7FF + 4) {
                break;
            }
        }
        
        if (_uart_buffer.len() == 0) return;
        while (_uart_buffer.len() >= 4) {
            // If we have at least enough for the header, then try parsing the buffer
            local event = null;
            try {
                event = parse_packet(_uart_buffer);
            } catch (e) {
                log("ERR", "Caught exception while parsing the UART buffer: " + e);
                throw "Caught exception while parsing the UART buffer: " + e;
            }
            
            if (event != null) {
                
                log("RECV", _uart_buffer.slice(0, event.length + 4));
                _uart_buffer = _uart_buffer.slice(event.length + 4)
                
                // We have a workable buffer, send it down the right path
                if (event.msg_type == BLE_MESSAGE_TYPE.COMMAND) {
                    fire_response(event);
                } else {
                    fire_event(event);
                }
            } else {
                // Skipped an incomplete packet. Wait for it to fill up properly.
                // log("RECV", hexdump(_uart_buffer) + " (skipped)");
                break;
            }
        }
    }
    
    // -------------------------------------------------------------------------
    function parse_packet(buffer) {
        
        // Parse the header
        local event = {};
        event.msg_type <- (buffer[0] & 0x80);
        event.tech_type <- (buffer[0] & 0x78) >> 3;
        event.length <- ((buffer[0] & 0x07) << 8) + buffer[1];
        event.cid <- buffer[2];
        event.cmd <- buffer[3];
        event.name <- "unknown";
        event.result <- 0;
        event.payload <- {};
        
        local payload = null;
        if (event.length > 0) {
            if (buffer.len() >= 4 + event.length) {
                payload = buffer.slice(4, 4 + event.length);
            } else {
                // The packet is incomplete
                return null;
            }
        }
        
        // Command responses
        switch (event.msg_type) {
            case BLE_MESSAGE_TYPE.COMMAND:
                
                switch (event.cid) {
                    case BLE_CLASS_ID.SYSTEM:
                        
                        switch (event.cmd) {
                            case 1: // system_hello response
                                event.name <- "system_hello";
                                break;
                                
                            case 2: // system_address_get response
                                event.payload.address <- addr_to_string(payload.slice(0, 6));
                                event.name <- "system_address_get";
                                break;
                            
                            case 3: // system_reg_write response
                                event.name <- "system_reg_write";
                                break;
                            
                            case 4: // system_reg_read response
                                event.name <- "system_reg_read";
                                break;
                            
                            case 5: // system_get_counters response
                                event.payload.txok <- payload[0];
                                event.payload.txretry <- payload[1];
                                event.payload.rxok <- payload[2];
                                event.payload.rxfail <- payload[3];
                                event.payload.mbuf <- payload[4];
                                event.name <- "system_get_connections";
                                break;
        
                            case 6: // system_get_connections response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "system_get_connections";
                                break;
        
                            case 7: // system_read_memory
                                event.name <- "system_read_memory";
                                break;
                                
                            case 8: // system_get_info response
                                event.payload.major <- payload[0] + (payload[1] << 8);
                                event.payload.minor <- payload[2] + (payload[3] << 8);
                                event.payload.patch <- payload[4] + (payload[5] << 8);
                                event.payload.build <- payload[6] + (payload[7] << 8);
                                event.payload.ll_version <- payload[8] + (payload[9] << 8);
                                event.payload.protocol_version <- payload[10];
                                event.payload.hw <- payload[11];
                                event.name <- "system_get_info";
                                break;
        
                            case 9: // system_endpoint_tx response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "system_endpoint_tx";
                                break;
        
                            case 10: // system_whitelist_append response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "system_whitelist_append";
                                break;
        
                            case 11: // system_whitelist_remove response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "system_whitelist_remove";
                                break;
        
                            case 12: // system_whitelist_clear response
                                event.name <- "system_whitelist_clear";
                                break;
        
                            case 13: // system_endpoint_rx response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.data <- payload.slice(3)
                                event.name <- "system_endpoint_rx";
                                break;
        
                            case 14: // system_endpoint_set_watermarks response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "system_endpoint_set_watermarks";
                                break;
                        }
                        break;
                    
                    /*
                    case BLE_CLASS_ID.PERSISTENT:
                        switch (event.cmd) {
                            case 0: // flash_ps_defrag response
                                event.name <- "flash_ps_defrag";
                                break;
                                
                            case 1: // flash_ps_dump response
                                event.name <- "flash_ps_dump";
                                break;
                                
                            case 2: // flash_ps_erase_all response
                                event.name <- "flash_ps_erase_all";
                                break;
                                
                            case 3: // flash_ps_save response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "flash_ps_save";
                                break;
                                
                            case 4: // flash_ps_load response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.value <- payload.slice(3);
                                event.name <- "flash_ps_load";
                                break;
        
                            case 5: // flash_ps_erase response
                                event.name <- "flash_ps_erase";
                                break;
                                
                            case 6: // flash_erase_page response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "flash_erase_page";
                                break;
                                
                            case 7: // flash_write_data response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "flash_write_data";
                                break;
                                
                            case 8: // flash_read_data response
                                event.payload.value <- payload.slice(1);
                                event.name <- "flash_read_data";
                                break;
        
                        }
                        break;
                    */
                    
                    case BLE_CLASS_ID.ATT_DB:
                        switch(event.cmd) {
                            case 0: // attributes_write response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "attributes_write";
                                break;
                                
                            case 1: // attributes_read response
                                event.payload.handle <- payload[0] + (payload[1] << 8);
                                event.payload.offset <- payload[2] + (payload[3] << 8);
                                event.result <- payload[4] + (payload[5] << 8);
                                event.payload.value <- payload.slice(7);
                                event.name <- "attributes_read";
                                break;
                            
                            case 2: // attributes_read_type response
                                event.payload.handle <- payload[0] + (payload[1] << 8);
                                event.result <- payload[2] + (payload[3] << 8);
                                event.payload.value <- payload.slice(5);
                                event.name <- "attributes_read_type";
                                break;
                            
                            case 3: // attributes_user_read_response response
                                event.name <- "attributes_user_read_response";
                                break;
                            
                            case 4: // attributes_user_write_response response
                                event.name <- "attributes_user_write_response";
                                break;
                        }
                        break;
                        
                    case BLE_CLASS_ID.CONNECTION:
                        switch(event.cmd) {
                            case 0: // connection_disconnect response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "connection_disconnect";
                                break;
                            
                            case 1: // connection_get_rssi response
                                event.payload.connection <- payload[0];
                                event.payload.rssi <- payload[1] - 256;
                                event.name <- "connection_get_rssi";
                                break;
                            
                            case 2: // connection_update response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "connection_update";
                                break;
                            
                            case 3: // connection_version_update response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "connection_version_update";
                                break;
                            
                            case 4: // connection_channel_map_get response
                                event.name <- "connection_channel_map_get";
                                break;
                            
                            case 5: // connection_channel_map_set response
                                event.name <- "connection_channel_map_set";
                                break;
                            
                            case 6: // connection_features_get response
                                event.name <- "connection_features_get";
                                break;
                                
                            case 7: // connection_get_status response
                                event.payload.connection <- payload[0];
                                event.name <- "connection_get_status";
                                break;
                                
                            case 8: // connection_raw_tx response
                                event.name <- "connection_raw_tx";
                                break;
                        }
                        break;

                    case BLE_CLASS_ID.ATT_CLIENT:
                        switch(event.cmd) {
                            case 0: // attclient_find_by_type_value response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_find_by_type_value";
                                break;
                                
                            case 1: // attclient_read_by_group_type response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_read_by_group_type";
                                break;
                            
                            case 2: // attclient_read_by_type response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_read_by_type";
                                break;
                                
                            case 3: // attclient_find_information response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_find_information";
                                break;
                                
                            case 4: // attclient_read_by_handle response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_read_by_handle";
                                break;
                            
                            case 5: // attclient_attribute_write response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_attribute_write";
                                break;
                            
                            case 6: // attclient_write_command response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "attclient_write_command";
                                break;
                            
                            case 7: // attclient_indicate_confirm response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "attclient_indicate_confirm";
                                break;
                            
                            case 8: // attclient_read_long response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_read_long";
                                break;
                            
                            case 9: // attclient_prepare_write response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_prepare_write";
                                break;
                            
                            case 10: // attclient_execute_write response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_execute_write";
                                break;
                                
                            case 11: // attclient_read_multiple response
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_read_multiple";
                                break;
                                
                        }
                        break;
                        
                    /*
                    case BLE_CLASS_ID.SECURITY:
                        switch(event.cmd) {
                            case 0: // sm_encrypt_start response
                                event.payload.handle <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "sm_encrypt_start";
                                break;
                                
                            case 1: // sm_set_bondable_mode response
                                event.name <- "sm_set_bondable_mode";
                                break;
                            
                            case 2: // sm_delete_bonding response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "sm_delete_bonding";
                                break;
                            
                            case 3: // sm_set_parameters response
                                event.name <- "sm_set_parameters";
                                break;
                            
                            case 4: // sm_passkey_entry response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "sm_passkey_entry";
                                break;
                            
                            case 5: // sm_get_bonds response
                                event.payload.bonds <- payload[0];
                                event.name <- "sm_get_bonds";
                                break;
                            
                            case 6: // sm_set_oob_data response
                                event.name <- "sm_set_oob_data";
                                break;
                            
                        }
                        break;
                    */
                    
                    case BLE_CLASS_ID.GAP:
                        switch(event.cmd) {
                            case 0: // gap_set_privacy_flags response
                                event.name <- "gap_set_privacy_flags";
                                break;
                                
                            case 1: // gap_set_mode response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_mode";
                                break;
                                
                            case 2: // gap_discover response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_discover";
                                break;
                            
                            case 3: // gap_connect_direct response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.connection_handle <- payload[2];
                                event.name <- "gap_connect_direct";
                                break;
                                
                            case 4: // gap_end_procedure response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_end_procedure";
                                break;
                                
                            case 5: // gap_connect_selective response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.connection_handle <- payload[2];
                                event.name <- "gap_connect_selective";
                                break;
                                
                            case 6: // gap_set_filtering response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_filtering";
                                break;
                                
                            case 7: // gap_set_scan_parameters response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_scan_parameters";
                                break;
                                
                            case 8: // gap_set_adv_parameters response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_adv_parameters";
                                break;
                                
                            case 9: // gap_set_adv_data response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_adv_data";
                                break;
                                
                            case 10: // gap_set_directed_connectable_mode response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "gap_set_directed_connectable_mode";
                                break;
                        }
                        break;
                    
                    /*
                    case BLE_CLASS_ID.HARDWARE:
                        switch(event.cmd) {
                            case 0: // hardware_io_port_config_irq response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_config_irq";
                                break;
                            
                            case 1: // hardware_set_soft_timer response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_set_soft_timer";
                                break;
                            
                            case 2: // hardware_adc_read response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_adc_read";
                                break;
                            
                            case 3: // hardware_io_port_config_direction response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_config_direction";
                                break;
                            
                            case 4: // hardware_io_port_config_function response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_config_function";
                                break;
                            
                            case 5: // hardware_io_port_config_pull response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_config_pull";
                                break;
                            
                            case 6: // hardware_io_port_write response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_write";
                                break;
                            
                            case 7: // hardware_io_port_read response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.port <- payload[2];
                                event.payload.data <- payload[3];
                                event.name <- "hardware_io_port_read";
                                break;
                            
                            case 8: // hardware_spi_config response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_spi_config";
                                break;
                            
                            case 9: // hardware_spi_transfer response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.channel <- payload[2];
                                event.payload.data <- payload.slice(4);
                                event.name <- "hardware_spi_transfer";
                                break;
                                
                            case 10: // hardware_i2c_read response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.data <- payload.slice(3);
                                event.name <- "hardware_i2c_read";
                                break;
                                
                            case 11: // hardware_i2c_write response
                                event.written <- payload[0];
                                event.name <- "hardware_i2c_write";
                                break;
                                
                            case 12: // hardware_set_txpower response
                                event.name <- "hardware_set_txpower";
                                break;
                                
                            case 13: // hardware_timer_comparator response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_timer_comparator";
                                break;
                            
                            case 14: // hardware_io_port_irq_enable response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_irq_enable";
                                break;
                            
                            case 15: // hardware_io_port_irq_direction response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_io_port_irq_direction";
                                break;
                            
                            case 16: // hardware_analog_comparator_enable response
                                event.name <- "hardware_analog_comparator_enable";
                                break;
                                
                            case 17: // hardware_analog_comparator_read response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.payload.output <- payload[2];
                                event.name <- "hardware_analog_comparator_read";
                                break;
                                
                            case 18: // hardware_analog_comparator_config_irq response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "hardware_analog_comparator_config_irq";
                                break;
                                
                        }
                        break;
                    */

                    
                    /*
                    case BLE_CLASS_ID.TEST:
                        // Not implemented
                        break;
                    */

                    
                    /*
                    case BLE_CLASS_ID.DFU:
                        switch(event.cmd) {
                            case 1: // dfu_flash_set_address response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "dfu_flash_set_address";
                                break;
                                
                            case 2: // dfu_flash_upload response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "dfu_flash_upload";
                                break;
                                
                            case 3: // dfu_flash_upload_finish response
                                event.result <- payload[0] + (payload[1] << 8);
                                event.name <- "dfu_flash_upload_finish";
                                break;
                                
                        }
                        break;
                    */
                    
                }
                break;
            
            
            // Events
            case BLE_MESSAGE_TYPE.EVENT:
                switch (event.cid) {
                    
                    case BLE_CLASS_ID.SYSTEM:
                        switch (event.cmd) {
                            case 0: // system_boot event
                                event.payload.major <- payload[0] + (payload[1] << 8);
                                event.payload.minor <- payload[2] + (payload[3] << 8);
                                event.payload.patch <- payload[4] + (payload[5] << 8);
                                event.payload.build <- payload[6] + (payload[7] << 8);
                                event.payload.ll_version  <- payload[8] + (payload[9] << 8);
                                event.payload.protocol_version <- payload[10];
                                event.payload.hw <- payload[11];
                                event.name <- "system_boot";
                                break;
                                
                            case 2: // system_endpoint_watermark_rx event
                                event.payload.endpoint <- payload[0];
                                event.payload.data <- payload[1];
                                event.name <- "system_endpoint_watermark_rx";
                                break;
                                
                            case 3: // system_endpoint_watermark_tx event
                                event.payload.endpoint <- payload[0];
                                event.payload.data <- payload[1];
                                event.name <- "system_endpoint_watermark_tx";
                                break;
                                
                            case 4: // system_script_failure event
                                event.payload.address <- payload[0] + (payload[1] << 8);
                                event.payload.reason <- payload[2] + (payload[3] << 8);
                                event.name <- "system_script_failure";
                                break;
                                
                            case 5: // system_no_license_key event
                                event.name <- "system_no_license_key";
                                break;
                                
                            case 6: // system_protocol_error event
                                event.payload.reason <- payload[0] + (payload[1] << 8);
                                event.name <- "system_protocol_error";
                                break;
                        }
                        break;
                        
                    /*
                    case BLE_CLASS_ID.PERSISTENT:
                        switch (event.cmd) {
                            case 0: // flash_ps_key event
                                event.payload.key <- payload[0] + (payload[1] << 8);
                                event.payload.value <- payload.slice(3);
                                event.name <- "flash_ps_key";
                                break;
                        }
                        break;
                    */
                    
                    case BLE_CLASS_ID.ATT_DB:
                        switch(event.cmd) {
                            case 0: // attributes_value event
                                event.payload.connection <- payload[0];
                                event.payload.reason <- payload[1];
                                event.payload.handle <- payload[2] + (payload[3] << 8);
                                event.payload.offset <- payload[4] + (payload[5] << 8);
                                event.payload.value <- payload.slice(7);
                                event.name <- "attributes_value";
                                break;
                                
                            case 1: // attributes_user_read_request event
                                event.payload.connection <- payload[0];
                                event.payload.handle <- payload[1] + (payload[2] << 8);
                                event.payload.offset <- payload[3] + (payload[4] << 8);
                                event.payload.maxsize <- payload[5];
                                event.name <- "attributes_user_read_request";
                                break;
                                
                            case 2: // attributes_status event
                                event.payload.handle <- payload[0] + (payload[1] << 8);
                                event.payload.flags <- payload[2];
                                event.name <- "attributes_status";
                                break;
                        }
                        break;
                        
                    case BLE_CLASS_ID.CONNECTION:
                        switch(event.cmd) {
                            case 0: // connection_status event
                                event.payload.connection <- payload[0];
                                event.payload.flags <- {};
                                event.payload.flags.connected <- (payload[1] & 0x01) == 0x01;
                                event.payload.flags.encrypted <- (payload[1] & 0x02) == 0x02;
                                event.payload.flags.completed <- (payload[1] & 0x04) == 0x04;
                                event.payload.flags.parameters_change <- (payload[1] & 0x08) == 0x08;
                                event.payload.address <- addr_to_string(payload.slice(2, 8));
                                event.payload.address_type <- addr_type_to_string(payload[8]);
                                event.payload.conn_interval <- (payload[9] + (payload[10] << 8)) * 1.25; // ms
                                event.payload.timeout <- (payload[11] + (payload[12] << 8)) * 10; // ms
                                event.payload.latency <- payload[13] + (payload[14] << 8);
                                event.payload.bonding <- payload[15];
                                event.name <- "connection_status";
                                break;
                                
                            case 1: // connection_version_ind event
                                event.payload.connection <- payload[0];
                                event.payload.reason <- payload[1] + (payload[2] << 8);
                                event.name <- "connection_version_ind";
                                break;
                                
                            case 2: // connection_feature_ind event
                                event.payload.connection <- payload[0];
                                event.payload.vers_nr <- payload[1];
                                event.payload.comp_id <- payload[2] + (payload[3] << 8);
                                event.payload.sub_vers_nr <- payload[4] + (payload[5] << 8);
                                event.name <- "connection_feature_ind";
                                break;
                                
                            case 4: // connection_disconnected event
                                event.payload.connection <- payload[0];
                                event.payload.reason <- payload[1] + (payload[2] << 8);
                                event.name <- "connection_disconnected";
                                break;
                        }
                        break;
                    
                    case BLE_CLASS_ID.ATT_CLIENT:
                        switch(event.cmd) {
                            case 0: // attclient_indicated event
                                event.payload.connection <- payload[0];
                                event.payload.attrhandle <- payload[1] + (payload[2] << 8);
                                event.name <- "attclient_indicated";
                                break;
                                
                            case 1: // attclient_procedure_completed event
                                event.payload.connection <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.payload.chrrhandle <- payload[3] + (payload[4] << 8);
                                event.name <- "attclient_procedure_completed";
                                break;
                                
                            case 2: // attclient_group_found event
                                event.payload.connection <- payload[0];
                                event.payload.start <- payload[1] + (payload[2] << 8);
                                event.payload.end <- payload[3] + (payload[4] << 8);
                                event.payload.uuid <- payload.slice(6);
                                event.name <- "attclient_group_found";
                                break;
                                
                            case 4: // attclient_find_information_found event
                                event.payload.connection <- payload[0];
                                event.payload.chrhandle <- payload[1] + (payload[2] << 8);
                                event.payload.uuid <- payload.slice(4);
                                event.name <- "attclient_find_information_found";
                                break;
                                
                            case 5: // attclient_attribute_value event
                                event.payload.connection <- payload[0];
                                event.payload.atthandle <- payload[1] + (payload[2] << 8);
                                switch (payload[3]) {
                                    case 0: event.payload.type <- "read"; break;
                                    case 1: event.payload.type <- "notify"; break;
                                    case 2: event.payload.type <- "indicate"; break;
                                    case 3: event.payload.type <- "read_by_type"; break;
                                    case 4: event.payload.type <- "read_blob"; break;
                                    case 5: event.payload.type <- "indicate_rsp_req"; break;
                                    default: event.payload.type <- "unknown"; break;
                                }
                                event.payload.value <- payload.slice(5);
                                event.name <- "attclient_attribute_value";
                                break;
                                
                            case 6: // attclient_read_multiple_response event
                                event.payload.connection <- payload[0];
                                event.payload.handles <- payload.slice(2);
                                event.name <- "attclient_read_multiple_response";
                                break;
                                
                        }
                        break;
                        
                    /*
                    case BLE_CLASS_ID.SECURITY:
                        switch(event.cmd) {
                            case 1: // sm_bonding_fail event
                                event.payload.handle <- payload[0];
                                event.result <- payload[1] + (payload[2] << 8);
                                event.name <- "sm_bonding_fail";
                                break;
                            
                            case 2: // sm_passkey_display event
                                event.payload.handle <- payload[0];
                                event.payload.passkey <- payload[1] + (payload[2] << 8) + (payload[3] << 16) + (payload[4] << 24);
                                event.name <- "sm_passkey_display";
                                break;
                            
                            case 3: // sm_passkey_request event
                                event.payload.handle <- payload[0];
                                event.name <- "sm_passkey_request";
                                break;
                            
                            case 4: // sm_bond_status event
                                event.payload.bond <- payload[0];
                                event.payload.keysize <- payload[1];
                                event.payload.mitm <- payload[2];
                                event.payload.keys <- payload[3];
                                event.name <- "sm_bond_status";
                                break;
                            
                        }
                        break;
                    */
                    
                    case BLE_CLASS_ID.GAP:
                        switch(event.cmd) {
                            case 0: // gap_scan_response event
                                event.payload.rssi <- payload[0] - 256;
                                event.payload.packet_type <- payload[1];
                                event.payload.sender <- addr_to_string(payload.slice(2, 8));
                                event.payload.address_type <- addr_type_to_string(payload[8]);
                                event.payload.bond <- payload[9];
                                event.payload.data <- payload.slice(11);
                                event.name <- "gap_scan_response";
                                break;
                        }
                        break;
                    
                    /*
                    case BLE_CLASS_ID.HARDWARE:
                        switch(event.cmd) {
                            case 0: // hardware_soft_timer event
                                event.payload.handle <- payload[0];
                                event.name <- "hardware_soft_timer";
                                break;
                                
                            case 1: // hardware_io_port_status event
                                event.payload.timestamp <- payload[0] + (payload[1] << 8) + (payload[2] << 16) + (payload[3] << 24);
                                event.payload.port <- payload[4];
                                event.payload.irq <- payload[5];
                                event.payload.state <- payload[6];
                                event.name <- "hardware_io_port_status";
                                break;
                            
                            case 2: // hardware_adc_result event
                                event.payload.input <- payload[0];
                                event.payload.value <- payload[1] + (payload[2] << 8); // This is a 2's compliment with the decimation bits in the MSB
                                event.name <- "hardware_adc_result";
                                break;
                            
                            case 3: // hardware_analog_comparator_status event
                                event.payload.timestamp <- payload[0] + (payload[1] << 8) + (payload[2] << 16) + (payload[3] << 24);
                                event.payload.output <- payload[4];
                                event.name <- "hardware_analog_comparator_status";
                                break;
                        }
                        break;
                    */

                    /*
                    case BLE_CLASS_ID.TEST:
                        // Not implemented
                        break;
                    */
                    
                    /*
                    case BLE_CLASS_ID.DFU:
                        switch(event.cmd) {
                            case 0: // dfu_boot event
                                event.payload.version <- payload[0] + (payload[1] << 8) + (payload[2] << 16) + (payload[3] << 24);;
                                event.name <- "dfu_boot";
                                break;
                                
                        }
                        break;
                    */
                }
                break;
        }
        
        return event;
    }
    

    // -------------------------------------------------------------------------

    // BLE_CLASS_ID.SYSTEM - System
    function system_reset(boot_in_dfu = 0) {
        local payload = format("%c", boot_in_dfu);
        return send_command("system_reset", BLE_CLASS_ID.SYSTEM, 0, payload);
    }
    
    function system_hello(callback = null) {
        return send_command("system_hello", BLE_CLASS_ID.SYSTEM, 1, null, callback);
    }
    
    function system_address_get(callback = null) {
        return send_command("system_address_get", BLE_CLASS_ID.SYSTEM, 2, null, callback);
    }
    
    /*
    function system_reg_write(address, value, callback = null) {
        log("ERR", "system_reg_write has been deprecated")
        local payload = format("%c%c%c", 
                                address & 0xFF, (address >> 8) & 0xFF,
                                value & 0xFF);
        return send_command("system_reg_write", BLE_CLASS_ID.SYSTEM, 3, payload, callback);
    }
    
    function system_reg_read(address, callback = null) {
        log("ERR", "system_reg_read has been deprecated")
        local payload = format("%c%c", address & 0xFF, (address >> 8) & 0xFF);
        return send_command("system_reg_read", BLE_CLASS_ID.SYSTEM, 4, payload, callback);
    }
    */
    
    function system_get_counters(callback = null) {
        return send_command("system_get_counters", BLE_CLASS_ID.SYSTEM, 5, null, callback);
    }
    
    function system_get_connections(callback = null) {
        return send_command("system_get_connections", BLE_CLASS_ID.SYSTEM, 6, null, callback);
    }
    
    /*
    function system_read_memory(address, length, callback = null) {
        log("ERR", "system_read_memory has been deprecated")
        local payload = format("%c%c%c%c%c", 
                                address & 0xFF, (address >> 8) & 0xFF, 
                                (address >> 16) & 0xFF, (address >> 24) & 0xFF,
                                length & 0xFF);
        return send_command("system_read_memory", BLE_CLASS_ID.SYSTEM, 7, payload, callback);
    }
    */
    
    function system_get_info(callback = null) {
        return send_command("system_get_info", BLE_CLASS_ID.SYSTEM, 8, null, callback);
    }
    
    function system_endpoint_tx(endpoint, data, callback = null) {
        local payload = format("%c%c", endpoint & 0xFF, data.len() & 0xFF) + data;
        return send_command("system_endpoint_tx", BLE_CLASS_ID.SYSTEM, 9, payload, callback);
    }
    
    function system_whitelist_append(address, address_type, callback = null) {
        local addr = string_to_addr(address);
        local addr_type = string_to_addr_type(address_type);
        local payload = addr + format("%c", addr_type & 0xFF);
        return send_command("system_whitelist_append", BLE_CLASS_ID.SYSTEM, 10, payload, callback);
    }
    
    function system_whitelist_remove(address, address_type, callback = null) {
        local addr = string_to_addr(address);
        local addr_type = string_to_addr_type(address_type);
        local payload = addr + format("%c", addr_type & 0xFF);
        return send_command("system_whitelist_remove", BLE_CLASS_ID.SYSTEM, 11, payload, callback);
    }
    
    function system_whitelist_clear(callback = null) {
        return send_command("system_whitelist_clear", BLE_CLASS_ID.SYSTEM, 12, null, callback);
    }
    
    function system_endpoint_rx(endpoint, size, callback = null) {
        local payload = format("%c%c", endpoint & 0xFF, size & 0xFF);
        return send_command("system_endpoint_rx", BLE_CLASS_ID.SYSTEM, 13, payload, callback);
    }
    
    function system_endpoint_set_watermarks(endpoint, rx, tx, callback = null) {
        local payload = format("%c%c%c", endpoint & 0xFF, rx & 0xFF, tx & 0xFF);
        return send_command("system_endpoint_set_watermarks", BLE_CLASS_ID.SYSTEM, 14, payload, callback);
    }
    
    
    /*
    // BLE_CLASS_ID.PERSISTENT - Persistent flash
    function flash_ps_defrag(callback = null) {
        return send_command("flash_ps_defrag", BLE_CLASS_ID.PERSISTENT, 0, null, callback);
    }
    
    function flash_ps_dump(callback = null) {
        return send_command("flash_ps_dump", BLE_CLASS_ID.PERSISTENT, 1, null, callback);
    }
    
    function flash_ps_erase_all(callback = null) {
        return send_command("ps_erase_all", BLE_CLASS_ID.PERSISTENT, 2, null, callback);
    }
    
    function flash_ps_save(key, value, callback = null) {
        local payload = format("%c%c%c", key & 0xFF, (key >> 8) & 0xFF, value.len() & 0xFF) + value;
        return send_command("flash_ps_save", BLE_CLASS_ID.PERSISTENT, 3, payload, callback);
    }
    
    function flash_ps_load(key, callback = null) {
        local payload = format("%c%c", key & 0xFF, (key >> 8) & 0xFF);
        return send_command("flash_ps_load", BLE_CLASS_ID.PERSISTENT, 4, payload, callback);
    }
    
    function flash_ps_erase(key, callback = null) {
        local payload = format("%c%c", key & 0xFF, (key >> 8) & 0xFF);
        return send_command("flash_ps_erase", BLE_CLASS_ID.PERSISTENT, 5, payload, callback);
    }
    
    function flash_erase_page(page, callback = null) {
        local payload = format("%c", page & 0xFF);
        return send_command("flash_erase_page", BLE_CLASS_ID.PERSISTENT, 6, payload, callback);
    }
    
    function flash_write_data(address, data, callback = null) {
        local payload = format("%c%c%c", address & 0xFF, (address >> 8) & 0xFF, data.len() & 0xFF) + data;
        return send_command("flash_write_data", BLE_CLASS_ID.PERSISTENT, 7, payload, callback);
    }
    
    function flash_read_data(address, length, callback = null) {
        local payload = format("%c%c%c", address & 0xFF, (address >> 8) & 0xFF, length & 0xFF);
        return send_command("flash_read_data", BLE_CLASS_ID.PERSISTENT, 8, payload, callback);
    }
    */
    
    
    // BLE_CLASS_ID.ATT_DB - Attributes
    function attributes_write(handle, offset, value, callback = null) {
        if (typeof value == "integer") {
            if (value <= 0xFF) {
                value = format("%c", value);
            } else {
                value = format("%c%c", value & 0xFF, (value >> 8) & 0xFF);
            }
        }
        local payload = format("%c%c%c%c", 
                                handle & 0xFF, (handle >> 8) & 0xFF,
                                offset & 0xFF, 
                                value.len() & 0xFF) + value;
        return send_command("attributes_write", BLE_CLASS_ID.ATT_DB, 0, payload, callback);
    }
    
    function attributes_read(handle, offset, callback = null) {
        local payload = format("%c%c%c%c", 
                                handle & 0xFF, (handle >> 8) & 0xFF,
                                offset & 0xFF, (offset >> 8) & 0xFF);
        return send_command("attributes_read", BLE_CLASS_ID.ATT_DB, 1, payload, callback);
    }
    
    function attributes_read_type(handle, callback = null) {
        local payload = format("%c%c", handle & 0xFF, (handle >> 8) & 0xFF);
        return send_command("attributes_read_type", BLE_CLASS_ID.ATT_DB, 2, payload, callback);
    }
    
    function attributes_user_read_response(connection, att_error, value, callback = null) {
        local payload = format("%c%c%c", connection & 0xFF, att_error & 0xFF, value.len() & 0xFF) + value;
        return send_command("attributes_user_read_response", BLE_CLASS_ID.ATT_DB, 3, payload, callback);
    }
    
    function attributes_user_write_response(connection, att_error, callback = null) {
        local payload = format("%c%c", connection & 0xFF, att_error & 0xFF);
        return send_command("attributes_user_write_response", BLE_CLASS_ID.ATT_DB, 4, payload, callback);
    }
    
    
    // BLE_CLASS_ID.CONNECTION - Connection
    function connection_disconnect(connection, callback = null) {
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_disconnect", BLE_CLASS_ID.CONNECTION, 0, payload, callback);
    }

    function connection_get_rssi(connection, callback = null) {
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_get_rssi", BLE_CLASS_ID.CONNECTION, 1, payload, callback);
    }

    function connection_update(connection, interval_min, interval_max, latency, timeout, callback = null) {
        local payload = format("%c%c%c%c%c%c%c%c%c", 
                                connection & 0xFF,
                                interval_min & 0xFF, (interval_min >> 8) & 0xFF,
                                interval_max & 0xFF, (interval_max >> 8) & 0xFF,
                                latency & 0xFF, (latency >> 8) & 0xFF,
                                timeout & 0xFF, (timeout >> 8) & 0xFF);
        return send_command("connection_update", BLE_CLASS_ID.CONNECTION, 2, payload, callback);
    }
    
    function connection_version_update(connection, callback = null) {
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_version_update", BLE_CLASS_ID.CONNECTION, 3, payload, callback);
    }

    /*
    function connection_channel_map_get(connection, callback = null) {
        log("ERR", "connection_channel_map_get has been deprecated")
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_channel_map_get, BLE_CLASS_ID.CONNECTION, 4, payload, callback);
    }

    function connection_channel_map_set(connection, map, callback = null) {
        log("ERR", "connection_channel_map_set has been deprecated")
        local payload = format("%c%c", connection & 0xFF, map.len() & 0xFF) + map;
        return send_command("connection_channel_map_set", BLE_CLASS_ID.CONNECTION, 5, payload, callback);
    }
    
    function connection_features_get(connection, callback = null) {
        log("ERR", "connection_features_get has been deprecated")
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_features_get", BLE_CLASS_ID.CONNECTION, 6, payload, callback);
    }
    */

    function connection_get_status(connection, callback = null) {
        local payload = format("%c", connection & 0xFF);
        return send_command("connection_get_status", BLE_CLASS_ID.CONNECTION, 7, payload, callback);
    }

    /*
    function connection_raw_tx(connection, data, callback = null) {
        log("ERR", "connection_raw_tx has been deprecated")
        local payload = format("%c%c", connection & 0xFF, data.len() & 0xFF) + data;
        return send_command("connection_raw_tx", BLE_CLASS_ID.CONNECTION, 8, payload, callback);
    }
    */
    

    // BLE_CLASS_ID.ATT_CLIENT - Attribute client
    function attclient_find_by_type_value(connection, start, end, uuid, value, callback = null) {
        local payload = format("%c%c%c%c%c%c%c", 
                            connection & 0xFF, 
                            start & 0xFF, (start >> 8) & 0xFF,
                            end & 0xFF, (end >> 8) & 0xFF,
                            uuid & 0xFF, (uuid >> 8) & 0xFF,
                            value.len() & 0xFF) + value;
        return send_command("attclient_find_by_type_value", BLE_CLASS_ID.ATT_CLIENT, 0, payload, callback);
    }
    
    function attclient_read_by_group_type(connection, start, end, uuid, callback = null) {
        local payload = format("%c%c%c%c%c%c", 
                            connection & 0xFF, 
                            start & 0xFF, (start >> 8) & 0xFF,
                            end & 0xFF, (end >> 8) & 0xFF,
                            uuid.len() & 0xFF) + uuid;
        return send_command("attclient_read_by_group_type", BLE_CLASS_ID.ATT_CLIENT, 1, payload, callback);
    }
    
    function attclient_read_by_type(connection, start, end, uuid, callback = null) {
        local payload = format("%c%c%c%c%c%c", 
                            connection & 0xFF, 
                            start & 0xFF, (start >> 8) & 0xFF,
                            end & 0xFF, (end >> 8) & 0xFF,
                            uuid.len() & 0xFF) + uuid;
        return send_command("attclient_read_by_type", BLE_CLASS_ID.ATT_CLIENT, 2, payload, callback);
    }
    
    function attclient_find_information(connection, start, end, callback = null) {
        local payload = format("%c%c%c%c%c", 
                            connection & 0xFF, 
                            start & 0xFF, (start >> 8) & 0xFF,
                            end & 0xFF, (end >> 8) & 0xFF);
        return send_command("attclient_find_information", BLE_CLASS_ID.ATT_CLIENT, 3, payload, callback);
    }
    
    function attclient_read_by_handle(connection, chrhandle, callback = null) {
        local payload = format("%c%c%c", 
                            connection & 0xFF, 
                            chrhandle & 0xFF, (chrhandle >> 8) & 0xFF);
        return send_command("attclient_read_by_handle", BLE_CLASS_ID.ATT_CLIENT, 4, payload, callback);
    }
    
    function attclient_attribute_write(connection, atthandle, data, callback = null) {
        local payload = format("%c%c%c%c", 
                            connection & 0xFF, 
                            atthandle & 0xFF, (atthandle >> 8) & 0xFF,
                            data.len() & 0xFF) + data;
        return send_command("attclient_attribute_write", BLE_CLASS_ID.ATT_CLIENT, 5, payload, callback);
    }
    
    function attclient_write_command(connection, atthandle, data, callback = null) {
        local payload = format("%c%c%c%c", 
                            connection & 0xFF, 
                            atthandle & 0xFF, (atthandle >> 8) & 0xFF,
                            data.len() & 0xFF) + data;
        return send_command("attclient_write_command", BLE_CLASS_ID.ATT_CLIENT, 6, payload, callback);
    }
    
    function attclient_indicate_confirm(connection, callback = null) {
        local payload = format("%c", connection & 0xFF);
        return send_command("attclient_indicate_confirm", BLE_CLASS_ID.ATT_CLIENT, 7, payload, callback);
    }

    function attclient_read_long(connection, chrhandle, callback = null) {
        local payload = format("%c%c%c", 
                            connection & 0xFF, 
                            chrhandle & 0xFF, (chrhandle >> 8) & 0xFF);
        return send_command("attclient_read_long", BLE_CLASS_ID.ATT_CLIENT, 8, payload, callback);
    }
    
    function attclient_prepare_write(connection, atthandle, offset, data, callback = null) {
        local payload = format("%c%c%c%c%c%c", 
                            connection & 0xFF, 
                            atthandle & 0xFF, (atthandle >> 8) & 0xFF,
                            offset & 0xFF, (offset >> 8) & 0xFF,
                            data.len() & 0xFF) + data;
        return send_command("attclient_write_command", BLE_CLASS_ID.ATT_CLIENT, 9, payload, callback);
    }
    
    function attclient_execute_write(connection, commit, callback = null) {
        local payload = format("%c%c", connection & 0xFF, commit & 0xFF);
        return send_command("attclient_execute_write", BLE_CLASS_ID.ATT_CLIENT, 10, payload, callback);
    }
    
    function attclient_read_multiple(connection, handles, callback = null) {
        local payload = format("%c%c", connection & 0xFF, handles.len() & 0xFF) + handles;
        return send_command("attclient_read_multiple", BLE_CLASS_ID.ATT_CLIENT, 11, payload, callback);
    }
    

    /*
    // BLE_CLASS_ID.SECURITY - Security
    function sm_encrypt_start(handle, bonding, callback = null) {
        local payload = format("%c%c", handle & 0xFF, bonding & 0xFF);
        return send_command("sm_encrypt_start", BLE_CLASS_ID.SECURITY, 0, payload, callback);
    }
    
    function sm_set_bondable_mode(bondable, callback = null) {
        local payload = format("%c", bondable & 0xFF);
        return send_command("sm_set_bondable_mode", BLE_CLASS_ID.SECURITY, 1, payload, callback);
    }
    
    function sm_delete_bonding(handle, callback = null) {
        local payload = format("%c", handle & 0xFF);
        return send_command("sm_delete_bonding", BLE_CLASS_ID.SECURITY, 2, payload, callback);
    }
    
    function sm_set_parameters(mitm, min_key_size, io_capabilities, callback = null) {
        local payload = format("%c%c%c", mitm & 0xFF, min_key_size & 0xFF, io_capabilities & 0xFF);
        return send_command("sm_set_parameters", BLE_CLASS_ID.SECURITY, 3, payload, callback);
    }
    
    function sm_passkey_entry(handle, passkey, callback = null) {
        local payload = format("%c%c%c%c%c", 
                                handle & 0xFF,
                                passkey & 0xFF, (passkey >> 8) & 0xFF, 
                                (passkey >> 16) & 0xFF, (passkey >> 24) & 0xFF);
        return send_command("sm_passkey_entry", BLE_CLASS_ID.SECURITY, 4, payload, callback);
    }
    
    function sm_get_bonds(callback = null) {
        return send_command("sm_get_bonds", BLE_CLASS_ID.SECURITY, 5, null, callback);
    }
    
    function sm_set_oob_data(oob, callback = null) {
        local payload = format("%c", oob.len() & 0xFF) + oob;
        return send_command("sm_set_oob_data", BLE_CLASS_ID.SECURITY, 6, payload, callback);
    }
    */
    

    // BLE_CLASS_ID.GAP - GAP
    function gap_set_privacy_flags(peripheral_privacy, central_privacy, callback = null) {
        local payload = format("%c%c", peripheral_privacy, central_privacy);
        return send_command("gap_set_privacy_flags", BLE_CLASS_ID.GAP, 0, payload, callback);
    }
    
    function gap_set_mode(discover, connect, callback = null) {
        local payload = format("%c%c", discover, connect);
        return send_command("gap_set_mode", BLE_CLASS_ID.GAP, 1, payload, callback);
    }
    
    function gap_discover(mode, callback = null) {
        local payload = format("%c", mode);
        return send_command("gap_discover", BLE_CLASS_ID.GAP, 2, payload, callback);
    }
    
    function gap_connect_direct(address, address_type, conn_interval_min, conn_interval_max, timeout, latency, callback = null) {
        local addr = string_to_addr(address);
        local addr_type = string_to_addr_type(address_type);
        local payload = addr + format("%c%c%c%c%c%c%c%c%c", 
                                addr_type & 0xFF,
                                conn_interval_min & 0xFF, (conn_interval_min >> 8) & 0xFF,
                                conn_interval_max & 0xFF, (conn_interval_max >> 8) & 0xFF,
                                timeout & 0xFF, (timeout >> 8) & 0xFF,
                                latency & 0xFF, (latency >> 8) & 0xFF);
        return send_command("gap_connect_direct", BLE_CLASS_ID.GAP, 3, payload, callback);
    }
    
    function gap_end_procedure(callback = null) {
        return send_command("gap_end_procedure", BLE_CLASS_ID.GAP, 4, null, callback);
    }
    
    function gap_connect_selective(conn_interval_min, conn_interval_max, timeout, latency, callback = null) {
        local payload = format("%c%c%c%c%c%c%c%c", 
                                conn_interval_min & 0xFF, (conn_interval_min >> 8) & 0xFF,
                                conn_interval_max & 0xFF, (conn_interval_max >> 8) & 0xFF, 
                                timeout & 0xFF, (timeout >> 8) & 0xFF, 
                                latency & 0xFF, (latency >> 8) & 0xFF);
        return send_command("gap_connect_selective", BLE_CLASS_ID.GAP, 5, payload, callback);
    }
    
    function gap_set_filtering(scan_policy, adv_policy, scan_duplicate_filtering, callback = null) {
        local payload = format("%c%c%c", 
                                scan_policy & 0xFF,
                                adv_policy & 0xFF,
                                scan_duplicate_filtering & 0xFF);
        return send_command("gap_set_filtering", BLE_CLASS_ID.GAP, 6, payload, callback);
    }
    
    function gap_set_scan_parameters(scan_interval, scan_window, active, callback = null) {
        local payload = format("%c%c%c%c%c", 
                                scan_interval & 0xFF, (scan_interval >> 8) & 0xFF,
                                scan_window & 0xFF, (scan_window >> 8) & 0xFF, 
                                active & 0xFF);
        return send_command("gap_set_scan_parameters", BLE_CLASS_ID.GAP, 7, payload, callback);
    }
    
    function gap_set_adv_parameters(adv_interval_min, adv_interval_max, adv_channels, callback = null) {
        local payload = format("%c%c%c%c%c", 
                                adv_interval_min & 0xFF, (adv_interval_min >> 8) & 0xFF,
                                adv_interval_max & 0xFF, (adv_interval_max >> 8) & 0xFF, 
                                adv_channels & 0xFF);
        return send_command("gap_set_adv_parameters", BLE_CLASS_ID.GAP, 8, payload, callback);
    }
    
    function gap_set_adv_data(set_scanrsp, advdata, callback = null) {
        local payload = format("%c%c", set_scanrsp & 0xFF, advdata.len() & 0xFF) + advdata;
        return send_command("gap_set_adv_data", BLE_CLASS_ID.GAP, 9, payload, callback);
    }
    
    function gap_set_directed_connectable_mode(address, address_type, callback = null) {
        local addr = string_to_addr(address);
        local addr_type = string_to_addr_type(address_type);
        local payload = addr + format("%c", addr_type & 0xFF);
        return send_command("gap_set_directed_connectable_mode", BLE_CLASS_ID.GAP, 10, payload, callback);
    }

    /*
    // BLE_CLASS_ID.HARDWARE - Hardware
    function hardware_io_port_config_irq(port, enable_bits, falling_edge, callback = null) {
        log("ERR", "hardware_io_port_config_irq has been deprecated")
        local payload = format("%c%c%c", 
                                port & 0xFF,
                                enable_bits & 0xFF,
                                falling_edge & 0xFF);
        return send_command("hardware_io_port_config_irq", BLE_CLASS_ID.HARDWARE, 0, payload, callback);
    }
 
    function hardware_set_soft_timer(time, handle, single_shot, callback = null) {
        local payload = format("%c%c%c%c%c%c", 
                                time & 0xFF, (time >> 8) & 0xFF, (time >> 16) & 0xFF, (time >> 24) & 0xFF,
                                handle & 0xFF,
                                single_shot & 0xFF);
        return send_command("hardware_set_soft_timer", BLE_CLASS_ID.HARDWARE, 1, payload, callback);
    }
    
    function hardware_adc_read(input, decimation, reference_selection, callback = null) {
        local payload = format("%c%c%c", input & 0xFF, decimation & 0xFF, reference_selection & 0xFF);
        return send_command("hardware_adc_read", BLE_CLASS_ID.HARDWARE, 2, payload, callback);
    }
 
    function hardware_io_port_config_direction(port, direction, callback = null) {
        local payload = format("%c%c", port & 0xFF, direction & 0xFF);
        return send_command("hardware_io_port_config_direction", BLE_CLASS_ID.HARDWARE, 3, payload, callback);
    }
 
    function hardware_io_port_config_function(port, _function, callback = null) {
        local payload = format("%c%c", port & 0xFF, _function & 0xFF);
        return send_command("hardware_io_port_config_function", BLE_CLASS_ID.HARDWARE, 4, payload, callback);
    }
 
    function hardware_io_port_config_pull(port, tristate_mask, pull_up, callback = null) {
        local payload = format("%c%c%c", port & 0xFF, tristate_mask & 0xFF, pull_up & 0xFF);
        return send_command("hardware_io_port_config_pull", BLE_CLASS_ID.HARDWARE, 5, payload, callback);
    }
 
    function hardware_io_port_write(port, mask, data, callback = null) {
        local payload = format("%c%c%c", port & 0xFF, mask & 0xFF, data & 0xFF);
        return send_command("hardware_io_port_write", BLE_CLASS_ID.HARDWARE, 6, payload, callback);
    }
 
    function hardware_io_port_read(port, mask, callback = null) {
        local payload = format("%c%c", port & 0xFF, mask & 0xFF);
        return send_command("hardware_io_port_read", BLE_CLASS_ID.HARDWARE, 7, payload, callback);
    }
 
    function hardware_spi_config(channel, polarity, phase, bit_order, baud_e, baud_m, callback = null) {
        local payload = format("%c%c%c%c%c%c", 
                            channel & 0xFF, polarity & 0xFF, phase & 0xFF, 
                            bit_order & 0xFF, baud_e & 0xFF, baud_m & 0xFF);
        return send_command("hardware_spi_config", BLE_CLASS_ID.HARDWARE, 8, payload, callback);
    }
 
    function hardware_spi_transfer(channel, data, callback = null) {
        local payload = format("%c%c", channel & 0xFF, data.len() & 0xFF) + data;
        return send_command("hardware_spi_transfer", BLE_CLASS_ID.HARDWARE, 9, payload, callback);
    }
 
    function hardware_i2c_read(address, stop, length, callback = null) {
        local payload = format("%c%c%c", address & 0xFF, stop & 0xFF, length & 0xFF);
        return send_command("hardware_i2c_read", BLE_CLASS_ID.HARDWARE, 10, payload, callback);
    }
 
    function hardware_i2c_write(address, stop, data, callback = null) {
        local payload = format("%c%c%c", address & 0xFF, stop & 0xFF, data.len() & 0xFF) + data;
        return send_command("hardware_i2c_write", BLE_CLASS_ID.HARDWARE, 11, payload, callback);
    }
 
    function hardware_set_txpower(power, callback = null) {
        local payload = format("%c", power & 0xFF);
        return send_command("hardware_set_txpower", BLE_CLASS_ID.HARDWARE, 12, payload, callback);
    }
 
    function hardware_timer_comparator(timer, channel, mode, comparator_value, callback = null) {
        local payload = format("%c%c%c%c%c", 
                                timer & 0xFF,
                                channel & 0xFF,
                                mode & 0xFF,
                                comparator_value & 0xFF, (comparator_value >> 8) & 0xFF);
        return send_command("hardware_timer_comparator", BLE_CLASS_ID.HARDWARE, 13, payload, callback);
    }
    
    function hardware_io_port_irq_enable(port, enable_bits, callback = null) {
        local payload = format("%c%c", port & 0xFF, enable_bits & 0xFF);
        return send_command("hardware_io_port_irq_enable", BLE_CLASS_ID.HARDWARE, 14, payload, callback);
    }
 
    function hardware_io_port_irq_direction(port, falling_edge, callback = null) {
        local payload = format("%c%c", port & 0xFF, falling_edge & 0xFF);
        return send_command("hardware_io_port_irq_direction", BLE_CLASS_ID.HARDWARE, 15, payload, callback);
    }
 
    function hardware_analog_comparator_enable(enabled, callback = null) {
        local payload = format("%c", enabled ? 0x01 : 0x00);
        return send_command("hardware_analog_comparator_enable", BLE_CLASS_ID.HARDWARE, 16, payload, callback);
    }
 
    function hardware_analog_comparator_read(callback = null) {
        return send_command("hardware_analog_comparator_read", BLE_CLASS_ID.HARDWARE, 17, null, callback);
    }
 
    function hardware_analog_comparator_config_irq(enabled, callback = null) {
        local payload = format("%c", enabled ? 0x01 : 0x00);
        return send_command("hardware_analog_comparator_config_irq", BLE_CLASS_ID.HARDWARE, 18, payload, callback);
    }
    */

    /*
    // BLE_CLASS_ID.DFU - DFU 
    function dfu_reset(dfu, callback = null) {
        local payload = format("%c", dfu & 0xFF);
        return send_command("dfu_reset", BLE_CLASS_ID.DFU, 0, payload, callback);
    }
    
    function dfu_flash_set_address(address, callback = null) {
        local payload = format("%c%c%c%c", 
                                address & 0xFF, (address >> 8) & 0xFF, (address >> 16) & 0xFF, (address >> 24) & 0xFF);
        return send_command("dfu_flash_set_address", BLE_CLASS_ID.DFU, 1, payload, callback);
    }
    
    function dfu_flash_upload(data, callback = null) {
        local payload = format("%c", data.len() & 0xFF) + data;
        return send_command("dfu_flash_upload", BLE_CLASS_ID.DFU, 2, payload, callback);
    }
    
    function dfu_flash_upload_finish(callback = null) {
        return send_command("dfu_flash_upload_finish", BLE_CLASS_ID.DFU, 3, null, callback);
    }
    */
    
}



//-------------------------------[ Example code ]------------------------------------

ble112 <- BGLib(hardware.uart1289, hardware.pinB, hardware.pinA);

//..............................................................................
server.log("Imp booted.");

ble112.reboot();
ble112.on("system_boot", function(event) {

    // Ping the device, make sure we can see it
    ble112.system_hello(function(response) {

        server.log("BLE112 booted.");
        
    })
    
})

