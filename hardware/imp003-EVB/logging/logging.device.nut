// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Temperature/light polling period (seconds)

const POLLING_PERIOD = 30;

led_red <- hardware.pinE;
led_green <- hardware.pinF;
led_blur <- hardware.pinK;
led_white <- hardware.pinM;

class TMP102 
{
    // static values (address offsets)
    
    static TEMP_REG = 0x00;
    static CONF_REG = 0x01;
    static T_LOW_REG = 0x02;
    static T_HIGH_REG = 0x03;
    
    // Send this value on general-call address (0x00) to reset device
    
    static RESET_VAL = 0x06;
    
    // ADC resolution in degrees C
    
    static DEG_PER_COUNT = 0.0625;

    // i2c address
    
    addr = null;
    
    // i2c bus (passed into constructor)
    
    i2c = null;
    
    // interrupt pin (configurable)
    
    int_pin = null;
    
    // configuration register value
    
    conf = null;

    // Default temp thresholds
    
    T_LOW = 75; // Celsius
    T_HIGH = 80;

    // Default mode
    
    EXTENDEDMODE = false;
    SHUTDOWN = false;

    // conversion ready flag
    
    CONV_READY = false;

    // interrupt state - some pins require us to poll the interrupt pin
    
    LAST_INT_STATE = null;
    POLL_INTERVAL = null;
    INT_CALLBACK = null;

    // generic temp interrupt
    
    function tmp102_int(state) 
    {
        server.log("Device: TMP102 Interrupt Occurred. State = " + state);
    }

    /*
     * Class Constructor. Takes 3 to 5 arguments:
     *      _i2c:                   Pre-configured I2C Bus
     *      _addr:                  I2C Slave Address for device. 8-bit address.
     *      _int_pin:               Pin to which ALERT line is connected
     *      _alert_poll_interval:   Interval (in seconds) at which to poll the ALERT pin (optional)
     *      _alert_callback:        Callback to call on ALERT pin state changes (optional)
     */
    
    constructor(_i2c, _addr, _int_pin, _alert_poll_interval = 1, _alert_callback = null) 
    {
        this.addr = _addr;
        this.i2c = _i2c;
        this.int_pin = _int_pin;

        /*
         * Top-level program should pass in Pre-configured I2C bus.
         * This is done to allow multiple devices to be constructed on the bus
         * without reconfiguring the bus with each instantiation and causing conflict.
         */
         
        this.int_pin.configure(DIGITAL_IN);
        LAST_INT_STATE = this.int_pin.read();
        POLL_INTERVAL = _alert_poll_interval;
        
        if (_alert_callback) 
        {
            INT_CALLBACK = _alert_callback;
        } 
        else 
        {
            INT_CALLBACK = this.tmp102_int;
        }
        
        read_conf();
    }

    /*
     * Check for state changes on the ALERT pin.
     *
     * Not all imp pins allow state-change callbacks, so ALERT pin interrupts are implemented with polling
     *
     */
     
    function poll_interrupt() 
    {
        imp.wakeup(POLL_INTERVAL, poll_interrupt);
        local int_state = int_pin.read();
        if (int_state != LAST_INT_STATE) 
        {
            LAST_INT_STATE = int_state;
            INT_CALLBACK(state);
        }
    }

    /*
     * Take the 2's complement of a value
     *
     * Required for Temp Registers
     *
     * Input:
     *      value: number to take the 2's complement of
     *      mask:  mask to select which bits should be complemented
     *
     * Return:
     *      The 2's complement of the original value masked with the mask
     */
     
    function twos_comp(value, mask) 
    {
        value = ~(value & mask) + 1;
        return value & mask;
    }

    /*
     * General-call Reset.
     * Note that this may reset other devices on an i2c bus.
     *
     * Logging is included to prevent this from silently affecting other devices
     */
     
    function reset() 
    {
        server.log("TMP102 Class issuing General-Call Reset on I2C Bus.");
        i2c.write(0x00, format("%c", RESET_VAL));
        
        // update the configuration register
        
        read_conf();
        
        // reset the thresholds
        
        T_LOW = 75;
        T_HIGH = 80;
    }

    /*
     * Read the TMP102 Configuration Register
     * This updates several class variables:
     *  - EXTENDEDMODE (determines if the device is in 13-bit extended mode)
     *  - SHUTDOWN     (determines if the device is in low power shutdown mode / one-shot mode)
     *  - CONV_READY   (determines if the device is done with last conversion, if in one-shot mode)
     */
     
    function read_conf() 
    {
        conf = i2c.read(addr, format("%c",CONF_REG), 2);
        
        // Extended Mode
        
        if (conf[1] & 0x10) 
        {
            EXTENDEDMODE = true;
        } 
        else 
        {
            EXTENDEDMODE = false;
        }
        
        if (conf[0] & 0x01) 
        {
            SHUTDOWN = true;
        } 
        else 
        {
            SHUTDOWN = false;
        }
        
        if (conf[1] & 0x80) 
        {
            CONV_READY = true;
        } 
        else 
        {
            CONV_READY = false;
        }
    }

    /*
     * Read, parse and log the current state of each field in the configuration register
     *
     */
     
    function print_conf() 
    {
        conf = i2c.read(addr, format("%c",CONF_REG), 2);
        server.log(format("TMP102 Conf Reg at 0x%02x: %02x%02x",addr,conf[0],conf[1]));

        // Extended Mode
        
        if (conf[1] & 0x10) 
        {
            server.log("TMP102 Extended Mode Enabled.");
        } 
        else 
        {
            server.log("TMP102 Extended Mode Disabled.");
        }

        // Shutdown Mode
        
        if (conf[0] & 0x01) 
        {
            server.log("TMP102 Shutdown Enabled.");
        }
        else 
        {
            server.log("TMP102 Shutdown Disabled.");
        }

        // One-shot Bit (Only care in shutdown mode)
        
        if (conf[0] & 0x80) 
        {
            server.log("TMP102 One-shot Bit Set.");
        } 
        else 
        {
            server.log("TMP102 One-shot Bit Not Set.");
        }

        // Thermostat or Comparator Mode
        
        if (conf[0] & 0x02) 
        {
            server.log("TMP102 in Interrupt Mode.");
        } 
        else 
        {
            server.log("TMP102 in Comparator Mode.");
        }

        // Alert Polarity
        
        if (conf[0] & 0x04) 
        {
            server.log("TMP102 Alert Pin Polarity Active-High.");
        } 
        else 
        {
            server.log("TMP102 Alert Pin Polarity Active-Low.");
        }

        // Alert Pin
        
        if (int_pin.read()) 
        {
            if (conf[0] & 0x04) 
            {
                server.log("TMP102 Alert Pin Asserted.");
            } 
            else 
            {
                server.log("TMP102 Alert Pin Not Asserted.");
            }
        } 
        else 
        {
            if (conf[0] & 0x04) 
            {
                server.log("TMP102 Alert Pin Not Asserted.");
            } 
            else 
            {
                server.log("TMP102 Alert Pin Asserted.");
            }
        }

        // Alert Bit
        
        if (conf[1] & 0x20) 
        {
            server.log("TMP102 Alert Bit  1");
        } 
        else 
        {
            server.log("TMP102 Alert Bit: 0");
        }

        // Conversion Rate
        
        local cr = (conf[1] & 0xC0) >> 6;
        
        switch (cr) 
        {
            case 0:
                server.log("TMP102 Conversion Rate Set to 0.25 Hz.");
                break;
            case 1:
                server.log("TMP102 Conversion Rate Set to 1 Hz.");
                break;
            case 2:
                server.log("TMP102 Conversion Rate Set to 4 Hz.");
                break;
            case 3:
                server.log("TMP102 Conversion Rate Set to 8 Hz.");
                break;
            default:
                server.error("TMP102 Conversion Rate Invalid: "+format("0x%02x",cr));
        }

        // Fault Queue
        
        local fq = (conf[0] & 0x18) >> 3;
        server.log(format("TMP102 Fault Queue shows %d Consecutive Fault(s).", fq));
    }

    /*
     * Enter or exit low-power shutdown mode
     * In shutdown mode, device does one-shot conversions
     *
     * Device comes up with shutdown disabled by default (in continuous-conversion/thermostat mode)
     *
     * Input:
     *      State (bool): true to enable shutdown/one-shot mode.
     */
     
    function shutdown(state) 
    {
        read_conf();
        local new_conf = 0;
        
        if (state) 
        {
            new_conf = ((conf[0] | 0x01) << 8) + conf[1];
        } 
        else 
        {
            new_conf = ((conf[0] & 0xFE) << 8) + conf[1];
        }
        
        i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
        
        // read_conf() updates the variables for shutdown and extended modes
        
        read_conf();
    }

    /*
     * Enter or exit 13-bit extended mode
     *
     * Input:
     *      State (bool): true to enable 13-bit extended mode
     */
     
    function set_extendedmode(state) 
    {
        read_conf();
        local new_conf = 0;
        
        if (state) 
        {
            new_conf = ((conf[0] << 8) + (conf[1] | 0x10));
        } 
        else 
        {
            new_conf = ((conf[0] << 8) + (conf[1] & 0xEF));
        }
        
        i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
        read_conf();
    }

    /*
     * Set the T_low threshold register
     * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
     *
     * Input:
     *      t_low: new threshold register value in degrees Celsius
     *
     */
     
    function set_t_low(t_low) 
    {
        t_low = (t_low / DEG_PER_COUNT).tointeger();
        local mask = 0x0FFF;
        
        if (EXTENDEDMODE) 
        {
            mask = 0x1FFF;
            
            if (t_low < 0) twos_comp(t_low, mask);
            t_low = (t_low & mask) << 3;
        } 
        else 
        {
            if (t_low < 0) twos_comp(t_low, mask);
            t_low = (t_low & mask) << 4;
        }
        
        server.log(format("set_t_low setting register to 0x%04x (%d)",t_low,t_low));
        i2c.write(addr, format("%c%c%c",T_LOW_REG,(t_low & 0xFF00) >> 8, (t_low & 0xFF)));
        T_LOW = t_low;
    }

    /*
     * Set the T_high threshold register
     * This value is used to determine the state of the ALERT pin when the device is in thermostat mode
     *
     * Input:
     *      t_high: new threshold register value in degrees Celsius
     *
     */
     
    function set_t_high(t_high) 
    {
        t_high = (t_high / DEG_PER_COUNT).tointeger();
        local mask = 0x0FFF;
        
        if (EXTENDEDMODE) 
        {
            mask = 0x1FFF;
            
            if (t_high < 0) twos_comp(t_high, mask);
            t_high = (t_high & mask) << 3;
        } 
        else 
        {
            if (t_high < 0) twos_comp(t_high, mask);
            t_high = (t_high & mask) << 4;
        }
        server.log(format("set_t_high setting register to 0x%04x (%d)",t_high,t_high));
        i2c.write(addr, format("%c%c%c",T_HIGH_REG,(t_high & 0xFF00) >> 8, (t_high & 0xFF)));
        T_HIGH = t_high;
    }

    /*
     * Read the current value of the T_low threshold register
     *
     * Return: value of register in degrees Celsius
     */
     
    function get_t_low() 
    {
        local result = i2c.read(addr, format("%c",T_LOW_REG), 2);
        local t_low = (result[0] << 8) + result[1];
        //server.log(format("get_t_low got: 0x%04x (%d)",t_low,t_low));
        local mask = 0x0FFF;
        local sign_mask = 0x0800;
        local offset = 4;
        
        if (EXTENDEDMODE) 
        {
            //server.log("get_t_low: TMP102 in extended mode.")
            sign_mask = 0x1000;
            mask = 0x1FFF;
            offset = 3;
        }
        
        t_low = (t_low >> offset) & mask;
        
        if (t_low & sign_mask) 
        {
            //server.log("get_t_low: Tlow is negative.");
            t_low = -1.0 * (twos_comp(t_low,mask));
        }
        
        //server.log(format("get_t_low: raw value is 0x%04x (%d)",t_low,t_low));
        T_LOW = (t_low.tofloat() * DEG_PER_COUNT);
        return T_LOW;
    }

    /*
     * Read the current value of the T_high threshold register
     *
     * Return: value of register in degrees Celsius
     */
     
    function get_t_high() 
    {
        local result = i2c.read(addr, format("%c",T_HIGH_REG), 2);
        local t_high = (result[0] << 8) + result[1];
        local mask = 0x0FFF;
        local sign_mask = 0x0800;
        local offset = 4;
        
        if (EXTENDEDMODE) 
        {
            sign_mask = 0x1000;
            mask = 0x1FFF;
            offset = 3;
        }
        
        t_high = (t_high >> offset) & mask;
        if (t_high & sign_mask) t_high = -1.0 * (twos_comp(t_high,mask));
        T_HIGH = (t_high.tofloat() * DEG_PER_COUNT);
        return T_HIGH;
    }

    /*
     * If the TMP102 is in shutdown mode, write the one-shot bit in the configuration register
     * This starts a conversion.
     * Conversions are done in 26 ms (typ.)
     *
     */
     
    function start_conversion() 
    {
        read_conf();
        local new_conf = 0;
        new_conf = ((conf[0] | 0x80) << 8) + conf[1];
        i2c.write(addr, format("%c%c%c",CONF_REG,(new_conf & 0xFF00) >> 8,(new_conf & 0xFF)));
    }

    /*
     * Read the temperature from the TMP102 Sensor
     *
     * Returns: current temperature in degrees Celsius
     */
     
    function read_c() 
    {
        if (SHUTDOWN) 
        {
            start_conversion();
            CONV_READY = false;
            local timeout = 30; // timeout in milliseconds
            local start = hardware.millis();
            while (!CONV_READY) 
            {
                read_conf();
                if ((hardware.millis() - start) > timeout) 
                {
                    server.error("Device: TMP102 Timed Out waiting for conversion.");
                    return -999;
                }
            }
        }
        
        local result = i2c.read(addr, format("%c", TEMP_REG), 2);
        local temp = (result[0] << 8) + result[1];

        local mask = 0x0FFF;
        local sign_mask = 0x0800;
        local offset = 4;
        
        if (EXTENDEDMODE) 
        {
            mask = 0x1FFF;
            sign_mask = 0x1000;
            offset = 3;
        }

        temp = (temp >> offset) & mask;
        if (temp & sign_mask) temp = -1.0 * (twos_comp(temp, mask));
        return temp * DEG_PER_COUNT;
    }

    /*
     * Read the temperature from the TMP102 Sensor and convert
     *
     * Returns: current temperature in degrees Fahrenheit
     */
     
    function read_f() 
    {
        local temp_c = read_c();
        
        if (temp_c == -999) 
        {
            return -999;
        } 
        else 
        {
            return (read_c() * 9.0 / 5.0 + 32.0);
        }
    }
}

// Color sensor

class TCS3472 
{
	_i2c  = null;
    _addr = null;
    _atime = null;

    constructor(i2c, address) 
    {
        _i2c  = i2c;
        _addr = address;

        _init();
    }

    function _init() 
    {
		const DEFAULT_ATIME = 0x80;

        // Each datasheet address is ORed with 0x80 to select the command register
        
        enum REGISTERS 
        {
            ENABLE  = 0x80, // Enables states and interrupts
            ATIME   = 0x81, // RGBC time
            WTIME   = 0x83, // Wait time
            AILTL   = 0x84, // Clear interrupt: low threshold, low byte
            AILTH   = 0x85, // Clear interrupt: low threshold, high byte
            AIHTL   = 0x86, // Clear interrupt: high threshold, low byte
            AIHTH   = 0x87, // Clear interrupt: high threshold, high byte
            PERS    = 0x8C, // Interrupt persistence filter
            CONFIG  = 0x8D, // Configuration (used to set WLONG, which increases WTIME by a factor of 12x)
            CONTROL = 0x8F, // Control
            ID      = 0x92, // Device ID
            STATUS  = 0x93, // Device status
            CDATAL  = 0x94, // 'Clear' data (low byte)
            CDATAH  = 0x95, // 'Clear' data (high byte)
            RDATAL  = 0x96, // Red data (low byte)
            RDATAH  = 0x97, // Red data (high byte)
            GDATAL  = 0x98, // Green data (low byte)
            GDATAH  = 0x99, // Green data (high byte)
            BDATAL  = 0x9A, // Blue data (low byte)
            BDATAH  = 0x9B  // Blue data (high byte)
        }

        enum TRANSACTION_TYPE 
        {
            REPEATED_BYTE   = 0x00, // This is the default and can be omitted normally
            AUTO_INCREMENT  = 0x01, // This mode increments the target register every read to save time
            CLEAR_INTERRUPT = 0x11
        }

        enum REG_ENABLE 
        {
            AIEN    = 0x10, // RGBC interrupt enable. When asserted, permits RGBC interrupts to be generated.
            WEN     = 0x08, // Wait enable. Activates the wait timer.
            AEN     = 0x02, // RGBC enable. Activates the RGBC color sensor.
            PON     = 0x01  // Power ON. Enables internal oscillator. (must wait 2.4ms for warm-up)
        }

        // RGBC Gain Control
        
        enum REG_CONTROL 
        {
            AGAIN_1X    = 0x00, // 1X gain
            AGAIN_4X    = 0x01, // 4X gain
            AGAIN_16X   = 0x10, // 16X gain
            AGAIN_60X   = 0x11  // 60X gain
        }

        enum REG_STATUS 
        {
            AVALID  = 0x01, // RGBC Valid. Indicates that the RGBC channels have completed an integration cycle.
            AINT    = 0x10  // RGBC clear channel interrupt
        }
    }

    // Set number of integration timeslots (0x00 - 0xFF = 2.4ms - 700ms)
    // Higher is more accurate, lower is faster
    
    function _setIntegrationTime(numslots) 
    {
        _i2c.write(_addr, format("%c%c", REGISTERS.ATIME, numslots));
    }

    function _read() 
    {
        // Table to hold measured values
        
        local colorLevels = {}
        
        // Power on, then wait at least 2.4ms for warm-up
        
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.PON));
        imp.sleep(0.01);

        // Set integration time (determines accuracy vs. duration)
        
        _setIntegrationTime(DEFAULT_ATIME);

        // Start the measurement
        
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.AEN | REG_ENABLE.PON));

        // Prepare to read the status register to find out when the measurement completes
        
        _i2c.write(_addr, format("%c", REGISTERS.STATUS));

        // Block until measurement completes
        
        while ((_i2c.read(_addr, "", 1)[0] & REG_STATUS.AVALID) == 0) {}

        // Stop measurement
        
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, REG_ENABLE.PON));

        // Read Clear, Red, Green, and Blue values
        
        _i2c.write(_addr, format("%c", TRANSACTION_TYPE.AUTO_INCREMENT << 5 | REGISTERS.CDATAL));
        local val = _i2c.read(_addr, "", 8);
        colorLevels.clear   <- (val[1].tointeger() << 8) | val[0].tointeger();
        colorLevels.red     <- (val[3].tointeger() << 8) | val[2].tointeger();
        colorLevels.green   <- (val[5].tointeger() << 8) | val[4].tointeger();
        colorLevels.blue    <- (val[7].tointeger() << 8) | val[6].tointeger();

        // Put sensor to sleep
        
        _i2c.write(_addr, format("%c%c", REGISTERS.ENABLE, 0x00));

        return colorLevels;
    }

    function getLux() 
    {
        // Get new values
        
        local colorLevels = _read();
        
        // Calculate illuminance (from TAOS (now AMS) Designer's Notebook #25)
        
        return (-0.32466 * colorLevels.red) + (1.57837 * colorLevels.green) + (-0.73191 * colorLevels.blue);
    }
}

// Read temperature and light level, then send to agent at a regular interval

function poll() 
{
    local temp = tempSensor.read_f();   // Read temperature
    local lux = colorSensor.getLux();   // Read light level
    imp.wakeup(POLLING_PERIOD, poll);   // Schedule next reading
    server.log(format("Temperature: %.01f°F, Illuminance: %.01f lux", temp, lux));
    
    // Pack data into a table
    
    local data = 
    {
        temp = temp,
        lux = lux
    }
    
    // Send data to agent
    
    agent.send("data", data);
}

// 8-bit left-justified I2C addresses

const TMP102_ADDR   = 0x92; // Temperature sensor
const TCS3472_ADDR  = 0x52; // Color sensor

// TMP102 interrupt pin - not used

alert <- hardware.pinW;
alert.configure(DIGITAL_IN);

// Configure i2c bus, maximum speed

i2c <- hardware.i2cAB;
i2c.configure(CLOCK_SPEED_400_KHZ);

tempSensor <- TMP102(i2c, TMP102_ADDR, alert);
colorSensor <- TCS3472(i2c, TCS3472_ADDR);

// Configure and turn off all LEDs

led_red.configure(DIGITAL_OUT_OD);
led_red.write(1);   // RGB active-low
led_green.configure(DIGITAL_OUT_OD);
led_green.write(1);
led_blue.configure(DIGITAL_OUT_OD);  
led_blue.write(1);
led_white.configure(DIGITAL_OUT);     
led_white.write(0);   // White active-high

// Start polling

poll();
