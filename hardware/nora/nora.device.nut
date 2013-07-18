/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Temperature, Humidity, Air Pressure and Ambient Light
server.log("Nora Multisensor Started: "+time());

class hih3161{
    static wait = 0.08;
    static addr = 0x4e;
    i2c   = null;
    temp  = null;
    humid = null;
    clk   = null;

    constructor(i2c){
        this.i2c   = i2c;
        this.temp  = OutputPort("Temperature", "number");
        this.humid = OutputPort("Humidity", "number");
    }
    
    function startConversion(){
        i2c.write(this.addr, "");
        this.clk = clock();
    }
    
    function convert(){
        if(this.clk == null){
            this.startConversion()
        }
    
        //Make sure we've waited long enough
        local elapsed = clock()-this.clk;
        if(elapsed < wait){
            imp.sleep(wait - elapsed);
        }
    
        local th = i2c.read(this.addr, "", 4);
        if(th == null){
            server.error("I2C Returned Null");
            return;
        }
        
        local t = ((((th[2]         << 6 ) | (th[3] >> 2)) * 165) / 16383.0) - 40;
        local h = ((((th[0] & 0x3F) << 8 ) | (th[1]     ))        / 163.83 );
    
        //Round to 2 decimal places
        t = (t*100).tointeger() /100.0;
        //h = (h*100).tointeger() /100.0;
    
        this.temp.set(t);
        this.humid.set(h);
    }
}
    
    
class mpl115{
    static wait = 0.005;
    static addr = 0xc0;
    i2c   = null;
    temp  = null;
    press = null;
    clk   = null;    
    a0    = null;
    b1    = null;
    b2    = null;
    c12   = null;

    constructor(i2c){
        this.i2c   = i2c;
        this.temp  = OutputPort("Temperature", "number");
        this.press = OutputPort("Air Pressure", "number");

        // Create non-volatile table if it doesn't already exist
        if (("nv" in getroottable()) && ("valid" in nv)){
            a0  = nv.a0;
            b1  = nv.b1;
            b2  = nv.b2;
            c12 = nv.c12;
        }else{
            // get a0, b1, b2, and c12 environmental coefficients from Freescale barometric pressure sensor U5
            local a0_msb  = i2c.read(addr, "\x04", 1);
            local a0_lsb  = i2c.read(addr, "\x05", 1);
            local b1_msb  = i2c.read(addr, "\x06", 1);
            local b1_lsb  = i2c.read(addr, "\x07", 1);
            local b2_msb  = i2c.read(addr, "\x08", 1);
            local b2_lsb  = i2c.read(addr, "\x09", 1);
            local c12_msb = i2c.read(addr, "\x0a", 1);
            local c12_lsb = i2c.read(addr, "\x0b", 1);
            
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

            server.log("A0 Coeff: "+format("%f",a0));
            server.log("B1 Coeff: "+format("%f",b1));
            server.log("B2 Coeff: "+format("%f",b2));
            server.log("C12 Coeff: "+format("%f",c12));
    
            //Stash them in the NV table for later use
            nv["a0"]  <- a0;
            nv["b1"]  <- b1;
            nv["b2"]  <- b2;
            nv["c12"] <- c12;
            nv["valid"] <- 1;
        }
    }
    
    function startConversion(){
        // Start compensated pressure conversion
        i2c.write(addr, "\x12\xff");
        this.clk = clock();
    }
    
    function convert(){
        if(this.clk == null){
            this.startConversion()
        }

        //Make sure we've waited long enough
        local elapsed = clock()-this.clk;
        if(elapsed < wait){
            imp.sleep(wait-elapsed);
        }
    
        // Read out temperature and pressure ADC values from Freescale sensor
        // Both values are 10 bits, unsigned, with the high 8 bits in the MSB value
        local press_result = i2c.read(0xc0, "\x00", 4);
    
        if (press_result == null) {
            server.error("Pressure Conversion Failed");
            return;
        }else{
            local padc = ((press_result[0] & 0xff) << 2) | (press_result[1] & 0x03);
            local tadc = ((press_result[2] & 0xff) << 2) | (press_result[3] & 0x03);
    
            // Calculate compensated pressure from coefficients and padc
            local pcomp = a0 + ((b1 + (c12 * tadc)) * padc) + (b2 * tadc);
    
            // Pcomp is 0 at 50 kPa and full-scale (1023) at 115 kPa, so we scale to get kPa
            // Patm = 50 + (pcomp * ((115 - 50) / 1023))
            local p = 50 + (pcomp * (65.0 / 1023.0));
            this.press.set(p);
                        
            //Temperature calculation from Arduino Library
            local t = 25 + (tadc-498.0)/(-5.35);
            this.temp.set(t);
        }
    }
}

class tsl2561{
    static wait = 0.45;
    static addr = 0x52;
    i2c    = null;
    luxOut = null;
    clk    = null;

    constructor(i2c){
        this.i2c = i2c;
        this.luxOut = OutputPort("Ambient Light", "number");
    }
    
    
    
    function startConversion(){
        //Set the power bits in the config register to 11
        i2c.write(this.addr, "\x80\x03");
        this.clk = clock();
    }

    function convert(){
        if(this.clk == null){
            this.startConversion()
        }

        //Make sure we've waited long enough
        local elapsed = clock()-this.clk;
        if(elapsed < wait){
            imp.sleep(wait-elapsed);
        }
        
        local reg0 = i2c.read(this.addr, "\xAC", 2);
        local reg1 = i2c.read(this.addr, "\xAE", 2);
        if(reg0 == null || reg1 == null){
            server.error("Light Reading Failed");
            return;
        }else{
            local ch0 = ((reg0[1] & 0xFF) << 8) + (reg0[0] & 0xFF);
            local ch1 = ((reg1[1] & 0xFF) << 8) + (reg1[0] & 0xFF);
            
            local ratio = ch1 / ch0.tofloat();
            local lux = 0.0;
            if( ratio <= 0.5){
                lux = 0.0304*ch0 - 0.062*ch0*math.pow(ratio,1.4); 
            }else if( ratio <= 0.61){
                lux = 0.0224 * ch0 - 0.031 * ch1;
            }else if( ratio <= 0.8){
                lux = 0.0128*ch0 - 0.0153*ch1;
            }else if( ratio <= 1.3){
                lux = 0.00146*ch0 - 0.00112*ch1;
            }else{
                server.error("Invalid Lux calculation: "+ch0+","+ch1);
                return;
            }

            this.luxOut.set(lux);
            server.log(format("Ch0: 0x%04X Ch1: 0x%04X Ratio: %f Lux: %f", ch0, ch1, ratio, lux));
            
        }
    }
        
}

//Configure I2C
hardware.configure(I2C1_89);
    
//Power Senors On
hardware.pin2.configure(DIGITAL_OUT);
hardware.pin2.write(0);

//Ensure the NV table is created
if( !( "nv" in getroottable() )){
    nv <- {dummy = 1};
    server.log("Creating NV table");
}

//Instatiate Classes
local hih = hih3161(hardware.i2c89);
local mpl = mpl115(hardware.i2c89);
local tsl = tsl2561(hardware.i2c89);

//Start a conversion
tsl.startConversion();
hih.startConversion();
mpl.startConversion();

//Configure Imp
imp.configure("Mulitsensor", [],[hih.temp,hih.humid,mpl.temp,mpl.press,tsl.luxOut]);

//Take the reading
mpl.convert();
hih.convert();
tsl.convert();

//Power Senors Off
hardware.pin2.configure(DIGITAL_OUT);
hardware.pin2.write(1);
    
//Use I2C lines to Drain the Rail
hardware.pin8.configure(DIGITAL_OUT);
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin8.write(0);
hardware.pin9.write(0);
imp.sleep(0.02);


//Sleep for 15 minuts and 1 second, minus the time past the quarter hour
//This should ensure that we wake up every 10 minutes, at 1 second past the 10
server.sleepfor(1 + 10*60 - (time() % (10*60)));