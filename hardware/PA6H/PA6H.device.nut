// Driver class for the PA6H GPS module
// http://www.adafruit.com/datasheets/GlobalTop-FGPMMOPA6H-Datasheet-V0A.pdf
// Used in V3 of the Adafruit "Ultimate" GPS Breakout
// https://www.adafruit.com/products/746
class PA6H {
    
    // GGA: Time, position and fix type data.
    // GSA: GPS receiver operating mode, active satellites used in the
    //      position solution and DOP values.
    // GSV: The number of GPS satellites in view satellite ID numbers,
    //      elevation, azimuth, and SNR values.
    // RMC: Time, date, position, course and speed data. Recommended
    //      Minimum Navigation Information.
    // VTG: Course and speed information relative to the ground
    
    // different commands to set the update rate from once a second (1 Hz) to 10 times a second (10Hz)
    // Note that these only control the rate at which the position is echoed, to actually speed up the
    // position fix you must also send one of the position fix rate commands below too.
    static PMTK_SET_NMEA_UPDATE_100_MILLIHERTZ      = "$PMTK220,10000*2F"; // Once every 10 seconds, 100 millihertz.
    static PMTK_SET_NMEA_UPDATE_1HZ                 = "$PMTK220,1000*1F";
    static PMTK_SET_NMEA_UPDATE_5HZ                 = "$PMTK220,200*2C";
    static PMTK_SET_NMEA_UPDATE_10HZ                = "$PMTK220,100*2F";
    // Position fix update rate commands.
    static PMTK_API_SET_FIX_CTL_100_MILLIHERTZ      = "$PMTK300,10000,0,0,0,0*2C"; // Once every 10 seconds, 100 millihertz.
    static PMTK_API_SET_FIX_CTL_1HZ                 = "$PMTK300,1000,0,0,0,0*1C";
    static PMTK_API_SET_FIX_CTL_5HZ                 = "$PMTK300,200,0,0,0,0*2F";
    // Can't fix position faster than 5 times a second!
    
    static PMTK_SET_BAUD_57600                      = "$PMTK251,57600*2C";
    static PMTK_SET_BAUD_9600                       = "$PMTK251,9600*17";
    
    // turn on only the second sentence (GPRMC)
    static PMTK_SET_NMEA_OUTPUT_RMCONLY             = "$PMTK314,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*29";
    // turn on GPRMC and GGA
    static PMTK_SET_NMEA_OUTPUT_RMCGGA              = "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    // turn on ALL THE DATA
    static PMTK_SET_NMEA_OUTPUT_ALLDATA             = "$PMTK314,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    // turn off output
    static PMTK_SET_NMEA_OUTPUT_OFF                 = "$PMTK314,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    
    // to generate your own sentences, check out the MTK command datasheet and use a checksum calculator
    // such as the awesome http://www.hhhh.org/wiml/proj/nmeaxor.html
    static PMTK_LOCUS_STARTLOG                      = "$PMTK185,0*22";
    static PMTK_LOCUS_STOPLOG                       = "$PMTK185,1*23";
    static PMTK_LOCUS_STARTSTOPACK                  = "$PMTK001,185,3*3C";
    static PMTK_LOCUS_QUERY_STATUS                  = "$PMTK183*38";
    static PMTK_LOCUS_ERASE_FLASH                   = "$PMTK184,1*22";
    static LOCUS_OVERLAP                            = 0;
    static LOCUS_FULLSTOP                           = 1;
    
    static PMTK_ENABLE_SBAS                         = "$PMTK313,1*2E";
    static PMTK_ENABLE_WAAS                         = "$PMTK301,2*2E";
    
    // standby command & boot successful message
    static PMTK_STANDBY                             = "$PMTK161,0*28";
    static PMTK_STANDBY_SUCCESS                     = "$PMTK001,161,3*36";  // Not needed currently
    static PMTK_AWAKE                               = "$PMTK010,002*2D";
    
    // ask for the release and version
    static PMTK_Q_RELEASE                           = "$PMTK605*31";
    
    // request for updates on antenna status 
    static PGCMD_ANTENNA                            = "$PGCMD,33,1*6C"; 
    static PGCMD_NOANTENNA                          = "$PGCMD,33,0*6D"; 
    
    static DEFAULT_BAUD  = 9600;

    // pins and hardware
    _uart   = null;
    _fix    = null;
    _en     = null;
    
    _uart_baud = null;
    _uart_buffer = "";
    
    // vars
    _last_pos_data = {};
    
    _position_update_cb = null;
    _dop_update_cb      = null;
    _sats_update_cb     = null;
    _rmc_update_cb      = null;
    _vtg_update_cb      = null;
    _ant_status_update_cb = null;
    
    // -------------------------------------------------------------------------
    constructor(uart, en = null, fix = null) {
        _uart   = uart;
        _en     = en;
        _fix    = fix;
        
        _uart_baud = DEFAULT_BAUD;
        _uart.configure(_uart_baud, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCallback.bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    function setBaud(baud) {
        if (baud == _uart_baud) return;
        if ((baud != 9600) && (baud != 57600)) throw format("Unsupported baud (%d); supported rates are 9600 and 57600",baud);
        if (baud == 57600) _sendCmd(PMTK_SET_BAUD_57600);
        else _sendCmd(PMTK_SET_BAUD_9600);
        _uart_baud = baud;
        _uart.configure(_uart_baud, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCallback.bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    function _uartCallback() {
        _uart_buffer += _uart.readstring(80);
        //server.log(_uart_buffer);
        local packets = split(_uart_buffer,"$");
        for (local i = 0; i < packets.len() - 1; i++) {
            try {
                local len = packets[i].len()
                _parse(packets[i]);
                _uart_buffer = _uart_buffer.slice(len,_uart_buffer.len());
            } catch (err) {
                _uart_buffer = "";
                server.error(err+", Pkt: "+packets[i]);
            }
        }
    }
    
    // -------------------------------------------------------------------------
    function _parse(packetstr) {
        //server.log(packetstr);
        // Device is just telling us it just cold-booted and the data is garbage
        if ("PMTK" in packetstr) { return }
        packetstr = strip(packetstr);

        //local fields = split(packetstr,",");
        local fields = [];
        local start = 0;
        local end = 0;
        do {
        	end = packetstr.find(",",start);
        	if (end != null) {
        	    local field = packetstr.slice(start,end);
        	    fields.push(field);
        		start = end+1;
        	}
        } while (end != null);
        local field = packetstr.slice(start,packetstr.len());
        
        // local start = 0;
        // local end = packetstr.find(",");
        // while (end) {
        //     local field = copy.slice(start,end);
        //     fields.push(field);
        //     start = end;
        //     end = copy.find(",",start+1);
        //     server.log(field+" | "+copy);
        // }
        
        local hdr = fields[0];
        switch (hdr) {
            case "GPGGA":
                // time, position, and fix data
                // Ex: "$GPGGA,064951.000,2307.1256,N,12016.4438,E,1,8,0.95,39.9,M,17.8,M,,*65 "
                // UTC Time 064951.000 hhmmss.sss
                _last_pos_data.time <- fields[1];
                // Latitude 2307.1256 ddmm.mmmm
                _last_pos_data.lat <- fields[2];
                // N/S Indicator N N=north or S=south
                _last_pos_data.ns <- fields[3];
                // Longitude 12016.4438 dddmm.mmmm
                _last_pos_data.lon <- fields[4];
                // E/W Indicator E E=east or W=west
                _last_pos_data.ew <- fields[5];
                // Position Fix
                _last_pos_data.fix <- fields[6];
                // Satellites Used 8 Range 0 to 14
                _last_pos_data.sats_used <- fields[7];
                // HDOP 0.95 Horizontal Dilution of Precision
                _last_pos_data.hdop <- fields[8];
                // MSL Altitude 39.9 meters Antenna Altitude above/below mean-sea-level
                _last_pos_data.msl <- fields[9];
                // Units M meters Units of antenna altitude
                _last_pos_data.units_alt <- fields[10];
                // Geoidal Separation 17.8 meters
                _last_pos_data.geoidal_sep <- fields[11];
                // Units M meters Units of geoids separation
                _last_pos_data.units_sep <- fields[12];
                // Age of Diff. Corr. second Null fields when DGPS is not used
                _last_pos_data.diff_corr <- fields[13];
                // Checksum
                local checksum = fields[14];
                if (_position_update_cb) _position_update_cb();
                break;
            case "GPGSA":
                // DOP and Active Satellites Data
                // Ex: "$GPGSA,A,3,29,21,26,15,18,09,06,10,,,,,2.32,0.95,2.11*00 "
                // "M" = manual (forced into 2D or 3D mode)
                // "A" = 2C Automatic, allowed to auto-switch 2D/3D
                _last_pos_data.mode1 <- fields[1];
                // "1" = Fix not available
                // "2" = 2D (<4 SVs used)
                // "3" = 3D (>= 4 SVs used)
                _last_pos_data.mode2 <- fields[2];
                // Satellites Used on Channel 1
                _last_pos_data.sats_used_1 <- fields[3];
                _last_pos_data.sats_used_2 <- fields[4];
                _last_pos_data.sats_used_3 <- fields[5];
                _last_pos_data.sats_used_4 <- fields[6];                
                _last_pos_data.sats_used_5 <- fields[7];
                _last_pos_data.sats_used_6 <- fields[8];                
                _last_pos_data.sats_used_7 <- fields[9];
                _last_pos_data.sats_used_8 <- fields[10];
                _last_pos_data.sats_used_9 <- fields[11];
                _last_pos_data.sats_used_10 <- fields[12];                
                _last_pos_data.sats_used_11 <- fields[13];
                _last_pos_data.sats_used_12 <- fields[14];
                // Positional Dilution of Precision
                _last_pos_data.pdop <- fields[15];
                // Horizontal Dilution of Precision
                _last_pos_data.hdop <- fields[16];
                // Vertical Dilution of Precision
                _last_pos_data.vdop <- fields[17];
                // checksum
                local checksum = fields[18];
                if (_dop_update_cb) _dop_update_cb();
                break;
            case "GPGSV":
                // GNSS Satellites in View
                // Ex: "$GPGSV,3,1,09,29,36,029,42,21,46,314,43,26,44,020,43,15,21,321,39*7D"
                // Number of Messages (3)
                local num_messages = fields[1];
                local message_number = fields[2];
                _last_pos_data.sats_in_view <- fields[3];
                if (!"sats" in _last_pos_data) _last_pos_data.sats <- [];
                local i = 4; // current index in fields
                while (i < (fields.len() - 4)) {
                    local sat = {};
                    sat.id <- fields[i++];
                    sat.elevation <- fields[i++];
                    sat.azimuth <- fields[i++];
                    sat.snr <- fields[i++];
                    _last_pos_data.sats.push(sat);
                }

                if (_sats_update_cb) _sats_update_cb();
                break;
            case "GPRMC":
                // Minimum Recommended Navigation Information
                // Ex: "$GPRMC,064951.000,A,2307.1256,N,12016.4438,E,0.03,165.48,260406,3.05,W,A*2C "
                // UTC time hhmmss.sss
                _last_pos_data.time <- fields[1];
                // Status A=Valid V=Not Valid
                _last_pos_data.status <- fields[2];
                // ddmm.mmmm
                _last_pos_data.lat <- fields[3];
                // N/S Indicator
                _last_pos_data.ns <- fields[4];
                // ddmm.mmmm
                _last_pos_data.lon <- fields[5];
                // E/W Indicator
                _last_pos_data.ew <- fields[6];
                // Ground speed in knots
                _last_pos_data.gs_knots <- fields[7];
                // Course over Ground, Degrees True
                _last_pos_data.true_course <- fields[8];
                // Date, ddmmyy
                _last_pos_data.date <- fields[9];
                // Magnetic Variation (Not available)
                _last_pos_data.mag_var <- fields[10];
                // Mode (A = Autonomous, D = Differential, E = Estimated)
                _last_pos_data.mode <- fields[11];
                
                if (_rmc_update_cb) _rms_update_cb();
                break;
            case "GPVTG":
                // Course and Speed information relative to ground
                // Ex: "$GPVTG,165.48,T,,M,0.03,N,0.06,K,A*37 "
                // Measured Heading, Degrees
                _last_pos_data.true_course <- fields[1];
                // Course Reference (T = True, M = Magnetic)
                _last_pos_data.course_ref <- fields[2];
                // _last_pos_data.course_2 <- fields[3];
                // _last_pos_data.ref_2 <- fields[4];
                // Ground Speed in Knots
                _last_pos_data.gs_knots <- fields[5];
                // Ground Speed Units, N = Knots
                //_last_pos_data.gs_units_1 <- fields[6];
                // Ground Speed in km/hr
                _last_pos_data.gs_kmph <- fields[7];
                // Ground Speed Units, K = Km/Hr
                //_last_pos_data.gs_units_2 <- fields[8];
                // Mode (A = Autonomous, D = Differential, E = Estimated)
                _last_pos_data.mode <- fields[9];
                if (_vtg_update_cb) _vtg_update_cb();
                break;
            case "PGTOP":
                // Antenna Status Information
                // Ex: "$PGTOP,11,3 *6F"
                // Function Type (??)
                //_last_pos_data.function_type <- fields[1];
                // Antenna Status
                // 1 = Active Antenna Shorted
                // 2 = Using Internal Antenna
                // 3 = Using Active Antenna
                _last_pos_data.ant_status <- fields[2];
                
                if (_ant_status_update_cb) _ant_status_update_cb();
                break;
            case "PGSA": 
                // ???
                break;
            case "PGACK":
                // command ACK
                // do nothing ...?
                
                break;
            default:
                throw "Unrecognized Header";
            }
    }   
    
    // -------------------------------------------------------------------------
    function _sendCmd(cmdStr) {
        _uart.write(cmdStr+"\x0D\x0A");
        _uart.flush();
    } 
    
    // -------------------------------------------------------------------------
    function enable() {
        if (_en) _en.write(1);
    }
    
    // -------------------------------------------------------------------------
    function wakeup() {
        _uart.write(" ");
    }
    
    // -------------------------------------------------------------------------
    function standby() {
       _sendCmd(PMTK_STANDBY);
    }
     
    // -------------------------------------------------------------------------
    function disable() {
        if (_en) _en.write(0);
    }
    
    // -------------------------------------------------------------------------
    function hasFix() {
        if (!_fix) throw "hasFix called but no Fix Pin provided to PA6H constructor" 
        return _fix.read();
    }
    
    // -------------------------------------------------------------------------
    function setPositionCallback(cb) {
        _position_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setDopCallback(cb) {
        _dop_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setSatsCallback(cb) {
        _sats_update_cb = cb;
    }    

    // -------------------------------------------------------------------------
    function setRmcCallback(cb) {
        _rmc_update_cb = cb;
    }

    // -------------------------------------------------------------------------
    function setVtgCallback(cb) {
        _vtg_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setAntStatusCallback(cb) {
        _ant_status_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    // Controls how frequently the GPS tells us the latest position solution
    // This does not control the rate at which solutions are generated; use setUpdateRate to change that
    // Max Rate 10 Hz (0.1s per report)
    // Min Rate 100 mHz (10s per report)
    // Input: rateSeconds - the time between position reports from the GPS
    // Return: None
    function setReportingRate(rateSeconds) {
        if (rateSeconds <= 0.1) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_10HZ);
        } else if (rateSeconds <= 0.5) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_5HZ);
        } else if (rateSeconds <= 1) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_1HZ);
        } else {
            _sendCmd(PMTK_SET_NMEA_UPDATE_100_MILLIHERTZ);
        }
    }
    
    // -------------------------------------------------------------------------
    // Controls how frequently the GPS calculates a position solution
    // Max rate 5Hz (0.2s per solution)
    // Min rate 100 mHz (10s per solution)
    // Input: rateSeconds - time between solutions by the GPS
    // Return: None
    function setUpdateRate(rateSeconds) {
        if (rateSeconds <= 0.2) {
            _sendCmd(PMTK_API_SET_FIX_CTL_5HZ);
        } else if (rateSeconds <= 1) {
            _sendCmd(PMTK_API_SET_FIX_CTL_1HZ);
        } else {
            _sendCmd(PMTK_API_SET_FIX_CTL_100_MILLIHERTZ);
        } 
    }
    
    // -------------------------------------------------------------------------
    // Set mode to RMC (rec minimum) and GGA (fix) data, incl altitude
    function setModeRMCGGA() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_RMCGGA);
    }
    
    // -------------------------------------------------------------------------
    // Set mode to RMC (rec minimum) ONLY: best for high update rates
    function setModeRMC() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_RMCONLY);
    }
    
    // -------------------------------------------------------------------------
    // Set mode to ALL. This will produce a lot of output...
    function setModeAll() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_ALLDATA);
    }
    
    // -------------------------------------------------------------------------
    function getPosition() {
        return _last_pos_data;    
    }
}


// Ex Instantiation:
// uart <- hardware.uart57;
// fix <- hardware.pin8;
// en <- hardware.pin9;

// // don't need to configure the UART because the PA6H class will reconfigure it anyway
// fix.configure(DIGITAL_IN);
// en.configure(DIGITAL_OUT,0);

// gps <- PA6H(uart, en, fix);