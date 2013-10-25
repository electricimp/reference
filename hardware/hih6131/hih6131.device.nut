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
class hih6131 extends sensor {

    static WAIT = 80; // milliseconds
    
    pin_en_l = null;
    pin_drain = null;
    name = "thermistor";

    constructor(_i2c, _pin_en_l = null, _pin_drain = null, _addr = 0x4E){
        base.constructor(_i2c, _pin_en_l, _pin_drain, _addr);
    }
  
    function convert(th) {
        local t = ((((th[2]         << 6 ) | (th[3] >> 2)) * 165) / 16383.0) - 40;
        local h = ((((th[0] & 0x3F) << 8 ) | (th[1]     ))        / 163.83 );
    
        //Round to 2 decimal places
        t = (t*100).tointeger() / 100.0;
        h = (h*100).tointeger() / 100.0;

        return { temperature = t, humidity = h};
    }


    function read(callback = null) {

        if (!ready) return null;

        enable();
        i2c.write(addr, "");

        // Do a non-blocking read
        imp.wakeup(WAIT/1000.0, function() {
            local th = i2c.read(addr, "", 4);
            disable();
            if (th == null) {
                callback(null);
            } else {
                callback(convert(th));
            }
        }.bindenv(this));

    }
  
}