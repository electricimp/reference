// https://cdn.sparkfun.com/assets/parts/1/2/2/8/0/GlobalTop_Titan_X1_Datasheet.pdf
// https://cdn-shop.adafruit.com/datasheets/PMTK_A11.pdf
// https://cdn.sparkfun.com/assets/parts/1/2/2/8/0/GTOP_NMEA_over_I2C_Application_Note.pdf
class MTK333X {

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
    
    static PMTK_SET_BAUD_115200                     = "$PMTK251,115200*1F";
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
    static _VERBOSE = false;

    // pins and hardware
    _uart   = null;

    _uart_baud = null;
    _uart_buffer = "";
    
    // vars
    _last_pos_data = {};
    // TODO: add all keys to the pos data table in init routine so the class caller doesn't have to check if they exist
    
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
    function _sendCmd(cmdStr) {
        // TODO: Calculate checksums directly.
        _uart.write(cmdStr);
        _uart.write("\r\n");
        _uart.flush();
    }   
    
    // -------------------------------------------------------------------------
    // Parse a UTC timestamp from 
    // 064951.000 hhmmss.sss
    // Into
    // 06:09:51.000
    function _parseUTC(ts) {
        local result = "";
        result = result + (ts.slice(0,2)+ ":" + ts.slice(2,4) + ":" + ts.slice(4,ts.len()));
        return result;
    }
    
    // -------------------------------------------------------------------------
    // Parse a lat/lon coordinate from
    // 
    // ddmm.mmmm or dddmm.mmmm
    // returns coodinate in degrees as a floating-point number
    function _parseCoordinate(str) {
      local deg = 0;
      local min = 0;
      
      // degrees aren't justified with leading zeros
      // handle three-digit whole degrees
      if (split(str, ".")[0].len() == 4) {
        deg = str.slice(0,2).tointeger();  
        min = str.slice(2,str.len()).tofloat();
      } else {
        deg = str.slice(0,3).tointeger();
        min = str.slice(3,str.len()).tofloat();
      }
      
      local result = deg + min / 60.0;
      //server.log(str + "->" + deg + " deg, " + min + " min = " + result);
      return result;
    }
    
    // -------------------------------------------------------------------------
    function _uartCallback() {
        //server.log(_uart_buffer);
        _uart_buffer += _uart.readstring(80);
        local packets = split(_uart_buffer,"$");
        for (local i = 0; i < packets.len(); i++) {
            // make sure we can see the end of the packet before trying to parse
            if (packets[i].find("\r\n")) {
                try {
                    local len = packets[i].len()
                    _parse(packets[i]);
                    _uart_buffer = _uart_buffer.slice(len + 1,_uart_buffer.len());
                } catch (err) {
                  _uart_buffer = "";
                  if (_VERBOSE) {
                    log("[GPS] "+err+", Pkt: "+packets[i]);
                  }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    function _parse(packetstr_raw) {
        //server.log(packetstr_raw);
        // "PMTKxxxx" is a system command packet; ignore for now
        if (packetstr_raw.find("PMTK") != null) { return }
        packetstr_raw = split(strip(packetstr_raw),"*");
        local packetstr = packetstr_raw[0];
        //log("Parsing: "+packetstr);
        // TODO: Verify checksum
        local checksum = packetstr_raw[1];
        //server.log(checksum);
        
        // string split swallows repeated split characters, 
        // so workaround with string find for now
        //local fields = split(packetstr,",");
        local fields = [];
        local start = 0;
        local end = 0;
        do {
            end = packetstr.find(",",start);
            if (end != null) {
                fields.push(packetstr.slice(start,end));
                start = end+1;
            }
        } while (end != null);
        fields.push(packetstr.slice(start,packetstr.len()));
        
        local hdr = fields[0];
        switch (hdr) {
            // lots of cases, few commands
            // "GP-" = GPS
            // "GN-" = GLONASS
            // "GL-" = GPS + GLONASS
            case "GPGGA":
                _handleGGA(fields);
                break;
            case "GNGGA": 
                _handleGGA(fields);
                break;
            case "GPGSA":
                _handleGSA(fields);
                break;
            case "GNGSA":
                _handleGSA(fields);
                break;
            case "GLGSA":
                _handleGSA(fields);
                break;
            case "GPGSV":
                _handleGSV(fields);
                break;
            case "GLGSV":
                _handleGSV(fields);
                break;
            case "GNGSV":
                _handleGSV(fields);
                break;
            case "GPRMC":
                _handleRMC(fields);
                break;
            case "GNRMC":
                _handleRMC(fields);
                break;
            case "GPVTG":
                _handleVTG(fields);
                break;
            case "GNVTG":
                _handleVTG(fields);
                break;
            case "PGTOP":
                _handlePGTOP(fields)
                break;
            case "PGACK":
                // command ACK
                // TODO: Allow command callbacks to verify good ACK
                server.log("ACK: "+packetstr);
                break;
            default:
                if (_VERBOSE) {
                  server.log("[GPS] Unrecognized Header: "+packetstr);
                }
        }
    }   
    
    // -------------------------------------------------------------------------
    // Handle GxGGA packet: time, position, and fix data
    // Ex: "$GPGGA,064951.000,2307.1256,N,12016.4438,E,1,8,0.95,39.9,M,17.8,M,,*65 "
    // UTC Time 064951.000 hhmmss.sss
    function _handleGGA(fields) {
      _last_pos_data.time <- _parseUTC(fields[1]);
      // Latitude 2307.1256 ddmm.mmmm
      _last_pos_data.lat <- _parseCoordinate(fields[2]);
      // N/S Indicator N N=north or S=south
      _last_pos_data.ns <- fields[3];
      if (_last_pos_data.ns == "S") {
        _last_pos_data.lat = -1 * _last_pos_data.lat;
      }
      // Longitude 12016.4438 dddmm.mmmm
      _last_pos_data.lon <- _parseCoordinate(fields[4]);
      // E/W Indicator E E=east or W=west
      _last_pos_data.ew <- fields[5];
      if (_last_pos_data.ew == "W") {
        _last_pos_data.lon = -1 * _last_pos_data.lon;
      }
      // Position Fix
      _last_pos_data.fix <- fields[6];
      // Satellites Used 8 Range 0 to 14
      _last_pos_data.sats_used <- fields[7] ? fields[7].tointeger() : null;
      // HDOP 0.95 Horizontal Dilution of Precision
      _last_pos_data.hdop <- fields[8] != "" ? fields[8].tofloat() : null;
      // MSL Altitude 39.9 meters Antenna Altitude above/below mean-sea-level
      _last_pos_data.msl <- fields[9] != "" ? fields[9].tofloat() : null;
      // Units M meters Units of antenna altitude
      _last_pos_data.units_alt <- fields[10];
      // Geoidal Separation 17.8 meters
      _last_pos_data.geoidal_sep <- fields[11] != "" ? fields[11].tofloat() : null;
      // Units M meters Units of geoids separation
      _last_pos_data.units_sep <- fields[12];
      // Age of Diff. Corr. second Null fields when DGPS is not used
      _last_pos_data.diff_corr <- fields[13];
      
      if (_position_update_cb) _position_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxGSA Packet: DOP and Active Satellites Data
    // Ex: "$GPGSA,A,3,29,21,26,15,18,09,06,10,,,,,2.32,0.95,2.11*00 "
    // "M" = manual (forced into 2D or 3D mode)
    // "A" = 2C Automatic, allowed to auto-switch 2D/3D
    function _handleGSA(fields) {
      _last_pos_data.mode1 <- fields[1];
      // "1" = Fix not available
      // "2" = 2D (<4 SVs used)
      // "3" = 3D (>= 4 SVs used)
      _last_pos_data.mode2 <- fields[2];
      // Satellites Used on Channel 1
      _last_pos_data.sats_used_1 <- fields[3] != "" ? fields[3].tointeger() : 0;
      _last_pos_data.sats_used_2 <- fields[4] != "" ? fields[4].tointeger() : 0;
      _last_pos_data.sats_used_3 <- fields[5] != "" ? fields[5].tointeger() : 0;
      _last_pos_data.sats_used_4 <- fields[6] != "" ? fields[6].tointeger() : 0;
      _last_pos_data.sats_used_5 <- fields[7] != "" ? fields[7].tointeger() : 0;
      _last_pos_data.sats_used_6 <- fields[8] != "" ? fields[8].tointeger() : 0;
      _last_pos_data.sats_used_7 <- fields[9] != "" ? fields[9].tointeger() : 0;
      _last_pos_data.sats_used_8 <- fields[10] != "" ? fields[10].tointeger() : 0;
      _last_pos_data.sats_used_9 <- fields[11] != "" ? fields[11].tointeger() : 0;
      _last_pos_data.sats_used_10 <- fields[12] != "" ? fields[12].tointeger() : 0;
      _last_pos_data.sats_used_11 <- fields[13] != "" ? fields[13].tointeger() : 0;
      _last_pos_data.sats_used_12 <- fields[14] != "" ? fields[14].tointeger() : 0;
      // Positional Dilution of Precision
      _last_pos_data.pdop <- fields[15].tofloat();
      // Horizontal Dilution of Precision
      _last_pos_data.hdop <- fields[16].tofloat();
      // Vertical Dilution of Precision
      _last_pos_data.vdop <- fields[17].tofloat();
  
      if (_dop_update_cb) _dop_update_cb(_last_pos_data);      
    }
    
    // -------------------------------------------------------------------------
    // Handle GxGSV Packet: GNSS Satellites in View
    // Ex: "$GPGSV,3,1,09,29,36,029,42,21,46,314,43,26,44,020,43,15,21,321,39*7D"
    // Number of Messages (3)
    function _handleGSV(fields) {
      local num_messages = fields[1].tointeger();
      local message_number = fields[2].tointeger();
      _last_pos_data.sats_in_view <- fields[3].tointeger();
      if ("sats" in _last_pos_data) {
        // hi
      } else {
        _last_pos_data.sats <- [];
      }
      local i = 4; // current index in fields
      while (i < (fields.len() - 4)) {
        local sat = {};
        sat.id <- fields[i] != "" ? fields[i].tointeger() : null;
        sat.elevation <- fields[++i] != "" ? fields[i].tofloat() : null;
        sat.azimuth <- fields[++i] != "" ? fields[i].tofloat() : null;
        sat.snr <- fields[++i] != "" ? fields[i].tofloat() : null;
        if (sat.id != null) {
          local new_sat = true;
          for (sat_idx = 0; sat_idx < _last_pos_data.sats.len(); sat_idx++) {
            if (_last_pos_data.sats[sat_idx].id == sat.id) {
              // we've seen this one before; update the relevant fields
              new_sat = false;
              _last_pos_data.sats[sat_idx].elevation = sat.elevation;
              _last_pos_data.sats[sat_idx].azimuth = sat.azimuth;
              _last_pos_data.sats[sat_idx].snr = sat.snr;
            } 
          }
          if (new_sat) {
            // new bird, add to the list
            _last_pos_data.sats.push(sat);
          }
        }
      }
  
      if (_sats_update_cb) _sats_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxRMC Packet: Minimum Recommended Navigation Information
    // Ex: "$GPRMC,064951.000,A,2307.1256,N,12016.4438,E,0.03,165.48,260406,3.05,W,A*2C "
    // UTC time hhmmss.sss
    function _handleRMC(fields) {
      _last_pos_data.time <- _parseUTC(fields[1]);
      // Status A=Valid V=Not Valid
      _last_pos_data.status <- fields[2];
      // ddmm.mmmm
      _last_pos_data.lat <- _parseCoordinate(fields[3]);
      // N/S Indicator
      _last_pos_data.ns <- fields[4];
      if (_last_pos_data.ns == "S") {
        _last_pos_data.lat = -1 * _last_pos_data.lat;
      }
      // ddmm.mmmm
      _last_pos_data.lon <- _parseCoordinate(fields[5]);
      // E/W Indicator
      _last_pos_data.ew <- fields[6];
        if (_last_pos_data.ew == "W") {
        _last_pos_data.lon = -1 * _last_pos_data.lon;
      }
      // Ground speed in knots
      _last_pos_data.gs_knots <- fields[7].tofloat();
      // Course over Ground, Degrees True
      _last_pos_data.true_course <- fields[8].tofloat();
      // Date, ddmmyy
      _last_pos_data.date <- fields[9];
      // Magnetic Variation (Not available)
      _last_pos_data.mag_var <- fields[10];
      // Mode (A = Autonomous, D = Differential, E = Estimated)
      _last_pos_data.mode <- fields[11];
      
      if (_rmc_update_cb) _rmc_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxVTG Packet: Course and Speed information relative to ground
    // Ex: "$GPVTG,165.48,T,,M,0.03,N,0.06,K,A*37 "
    // Measured Heading, Degrees
    function _handleVTG(fields) {
      _last_pos_data.true_course <- fields[1].tofloat();
      // Course Reference (T = True, M = Magnetic)
      _last_pos_data.course_ref <- fields[2];
      // _last_pos_data.course_2 <- fields[3];
      // _last_pos_data.ref_2 <- fields[4];
      // Ground Speed in Knots
      _last_pos_data.gs_knots <- fields[5].tofloat();
      // Ground Speed Units, N = Knots
      //_last_pos_data.gs_units_1 <- fields[6];
      // Ground Speed in km/hr
      _last_pos_data.gs_kmph <- fields[7].tofloat();
      // Ground Speed Units, K = Km/Hr
      //_last_pos_data.gs_units_2 <- fields[8];
      // Mode (A = Autonomous, D = Differential, E = Estimated)
      _last_pos_data.mode <- fields[9];
  
      if (_vtg_update_cb) _vtg_update_cb(_last_pos_data);
    }

    // -------------------------------------------------------------------------
    // Handle PGTOP Packet: Antenna Status Information
    // Ex: "$PGTOP,11,3 *6F"
    // Function Type (??)
    //_last_pos_data.function_type <- fields[1];
    // Antenna Status
    // 1 = Active Antenna Shorted
    // 2 = Using Internal Antenna
    // 3 = Using Active Antenna
    function _handlePGTOP(fields) {
      _last_pos_data.ant_status <- fields[2].tointeger();
    
      if (_ant_status_update_cb) _ant_status_update_cb(_last_pos_data);
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
    
    function setBaud(baud) {
        if (baud == _uart_baud) return;
        if (baud == 9600) _sendCmd(PMTK_SET_BAUD_9600);
        else if (baud == 57600) _sendCmd(PMTK_SET_BAUD_57600);
        else if (baud == 115200) _sendCmd(PMTK_SET_BAUD_115200);
        else throw format("Unsupported baud (%d); supported rates are 9600, 57600, 115200",baud);
        _uart_baud = baud;
        _uart.configure(_uart_baud, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCallback.bindenv(this));
    }

    // -------------------------------------------------------------------------
    function hasFix() {
        if (!_fix) throw "hasFix called but no Fix Pin provided to GPS constructor" 
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

// // don't need to configure the UART because the MTK333X class will reconfigure it anyway
// fix.configure(DIGITAL_IN);
// en.configure(DIGITAL_OUT,0);

// gps <- MTK333X(uart, en, fix);

// Ex Usage

// server.log("Ready, running "+imp.getsoftwareversion());
// server.log("Mem: "+imp.getmemoryfree());

// imp.wakeup(1, function() {
//     // get less data
//     gps.setModeRMC();
//     // set RMC data callback
//     gps.setRmcCallback(function(data) {
//         server.log(format("At %s UTC: (%s %s, %s %s), making %0.2f Knots at %0.2f True",
//             data.time,
//             data.lat,
//             data.ns,
//             data.lon, 
//             data.ew,
//             data.gs_knots,
//             data.true_course));
//     });
//     // slow down updates
//     gps.setUpdateRate(10.0);
//     gps.setReportingRate(10.0);
// });
