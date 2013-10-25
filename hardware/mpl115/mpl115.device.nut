/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


// **********************************************************************************************************************************
class sensor {

    i2c       = null;
    pin_en_l  = null;
    pin_drain = null;
    addr      = null;
    ready     = false;
    name      = "sensor";
    static sensorlist = {};
    
    constructor(_i2c=null, _pin_en_l=null, _pin_drain=null, _addr=null) {
        i2c = _i2c;
		pin_en_l = _pin_en_l;
		pin_drain = _pin_drain;
        addr = _addr;
        ::last_activity <- time();
        
        if (i2c) i2c.configure(CLOCK_SPEED_400_KHZ);
		if (pin_en_l) pin_en_l.configure(DIGITAL_OUT);
		if (pin_drain) pin_drain.configure(DIGITAL_OUT);

        // Test the sensor and if its alive then setup a handler to execute all functions of the class
        if (test()) {
            sensorlist[name] <- this;
            agent.on(name, agent_event.bindenv(this));
        }
    }

	function enable() {
		if (pin_en_l) pin_en_l.write(0);
		if (pin_drain) pin_drain.write(1);
		imp.sleep(0.001);
	}

	function disable() {
		if (pin_en_l) pin_en_l.write(1);
		if (pin_drain) pin_drain.write(0);
	}

	function test() {
        if (i2c == null) {
            ready = false;  
        } else {
      		enable();
      		local t = i2c.read(addr, "", 1);
      		ready = (t != null);
      		disable();
        }
    
        return ready;
	}

    function get_nv(key) {
    	if (("nv" in getroottable()) && (key in ::nv)) {
            return ::nv[key];
		} else {
    	    return null;   
		}
    }
    
    function set_nv(key, value) {
        if (!("nv" in getroottable())) ::nv <- {};
        ::nv[key] <- value;
    }


    function dump_nv(root = null) {
        if ("nv" in getroottable()) {
            if (root == null) root = ::nv;
            foreach (k,v in root) {
                if (typeof v == "array" || typeof v == "table") {
                    log("NV: " + k + " => " + v)
                    dump_nv(v);
                } else {
                    log("NV: " + k + " => " + v)
                }
            }
        } else {
            log("NV: Not defined");
        }
        
    }
    
    
    function get_wake_reason() {
        
		switch (hardware.wakereason()) {
		case WAKEREASON_POWER_ON: return "power on"; 
		case WAKEREASON_TIMER: return "timer"; 
		case WAKEREASON_SW_RESET: return "software reset";
		case WAKEREASON_PIN1: return "pin1 interrupt";
		case WAKEREASON_NEW_SQUIRREL: return "new squirrel";
		default: return "unknown";
		}
    }
    
    
	function get_bootreason() {
        // log("GET bootreason: " + get_nv("reason"));
        return get_nv("reason");
	}


	function set_bootreason(_reason = null) {
        set_nv("reason", _reason);
        // log("SET bootreason to " + _reason);
	}
    
    function agent_event(data) {
        last_activity = time();
        if (data.method in this && typeof this[data.method] == "function") {
      
            // Formulate the function and the callback
            local method = this[data.method];
            local params = [this];
            local callback = remote_response(name, data.method).bindenv(this);
            
            if ("params" in data) {
                if (typeof data.params == "array") {
                    params.extend(data.params);
                } else {
                    params.push(data.params);
                }
            }
            params.push(callback);
        
            // Execute the function call with the parameters and callbacks
            try {
                method.acall(params);
            } catch (e) {
                log(format("Exception while executing '%s.%s': %s", name, data.method, e))
            }
        }
    }

    function reset() {
        if (i2c) {
            i2c.write(0x00,format("%c",RESET_VAL));
            imp.sleep(0.01);
        }
    }


	function sleep(dur = 600, delay = 0, callback = null) {

		switch (hardware.wakereason()) {
		case WAKEREASON_POWER_ON:
		case WAKEREASON_NEW_SQUIRREL:
			delay = delay >= 10 ? delay : 10;
			break;
		}

		server.log("Sleeping in " + delay + " for " + dur + ". Last wake reason: " + get_wake_reason());
		imp.wakeup(delay, function() {
			imp.onidle(function() {
				// Clearing the interrupt pins like this is a bit hacky but it gets the job done.
				// If squirrel had a destructor() function, I would prefer to do it there.
				if (i2c) i2c.read(addr, lis3dh.INT1_SRC, 1); 
				if (i2c) i2c.read(addr, lis3dh.TAP_SRC, 1); 

				server.expectonlinein(dur);
				imp.deepsleepfor(dur);
			}.bindenv(this))
		}.bindenv(this))

	}


    function remote_response(dev, method) {
        return function(data = null) {
            agent.send(dev + "." + method, data);
        }
    }
	
}

// **********************************************************************************************************************************
/* MPL115 Miniature I2C Barometer
 * http://www.freescale.com/files/sensors/doc/data_sheet/MPL115A2.pdf
 *
 */
class mpl115 extends sensor {
  static WAIT = 80; // milliseconds

    a0 = null;
    b1 = null;
    b2 = null;
    c12 = null;
  
    name = "pressure";

    constructor(_i2c, _pin_en_l = null, _pin_drain = null, _addr = 0xC0) {
        base.constructor(_i2c, _pin_en_l, _pin_drain, _addr);
        if (ready) init();
    }

    function init() {
        // Create non-volatile table if it doesn't already exist
        local cache = get_nv("mpl115");
        if (cache) {
            a0  = cache.a0;
            b1  = cache.b1;
            b2  = cache.b2;
            c12 = cache.c12;
        } else {

            enable();

            // get a0, b1, b2, and c12 environmental coefficients from Freescale barometric pressure sensor U5
            local a0_msb  = i2c.read(addr, "\x04", 1);
            local a0_lsb  = i2c.read(addr, "\x05", 1);
            local b1_msb  = i2c.read(addr, "\x06", 1);
            local b1_lsb  = i2c.read(addr, "\x07", 1);
            local b2_msb  = i2c.read(addr, "\x08", 1);
            local b2_lsb  = i2c.read(addr, "\x09", 1);
            local c12_msb = i2c.read(addr, "\x0a", 1);
            local c12_lsb = i2c.read(addr, "\x0b", 1);

            disable();

            // if values (coefficients and ADC values) are less than 16 bits, lsb is padded from low end with zeros
            // a0 is 16 bits, signed, 12 integer, 3 fractional (2^3 = 8)
            a0 = ((a0_msb[0] << 8) | (a0_lsb[0] & 0x00ff));
            // handle 2's complement sign bit
            if (a0 & 0x8000) {
                a0 = (~a0) & 0xffff;
                a0++;
                a0 *= -1;
            }
            a0 = a0/8.0;

            // b1 is 16 bits, signed, 2 integer, 13 fractional (2^13 = 8192)
            b1 = (b1_msb[0] << 8) | (b1_lsb[0] & 0xff);
            if (b1 & 0x8000) {
                b1 = (~b1) & 0xffff;
                b1++;
                b1 *= -1;
            }
            b1 = b1/8192.0;

            // b2 is 16 bits, signed, 1 integer, 14 fractional
            b2 = (b2_msb[0] << 8) | (b2_lsb[0] & 0xff);
            if (b2 & 0x8000) {
                b2 = (~b2) & 0xffff;
                b2++;
                b2 *= -1;
            }
            b2 = b2/16384.0;

            // c12 is 14 bits, signed, 13 fractional bits, with 9 zeroes of padding
            c12 = ((c12_msb[0] & 0xff) << 6) | ((c12_lsb[0] & 0xfc) >> 2);
            if (c12 & 0x2000) {
                c12 = (~c12) & 0xffff;
                c12++;
                c12 *= -1;
            }
            c12 = c12/4194304.0;

            //Stash them in the NV table for later use
            set_nv("mpl115", {a0 = a0, b1 = b1, b2 = b2, c12 = c12})
        }
    }


    function convert(pr) {
        local padc = ((pr[0] & 0xff) << 2) | (pr[1] & 0x03);
        local tadc = ((pr[2] & 0xff) << 2) | (pr[3] & 0x03);

        // Calculate compensated pressure from coefficients and padc
        local pcomp = a0 + ((b1 + (c12 * tadc)) * padc) + (b2 * tadc);

        // Pcomp is 0 at 50 kPa and full-scale (1023) at 115 kPa, so we scale to get kPa
        // Patm = 50 + (pcomp * ((115 - 50) / 1023))
        local p = 50 + (pcomp * (65.0 / 1023.0));
        return {pressure = p};
    }


  function read(callback = null) {
        if (!ready) return null;

        enable();
        i2c.write(addr, "\x12\xFF");
        imp.wakeup(WAIT/1000.0, function() {
            // Read out temperature and pressure ADC values from Freescale sensor
            // Both values are 10 bits, unsigned, with the high 8 bits in the MSB value
            local pr = i2c.read(0xc0, "\x00", 4);
            disable();

            if (pr == null) {
                callback(null);
            } else {
                callback(convert(pr));
            }
        }.bindenv(this));
  }

} 