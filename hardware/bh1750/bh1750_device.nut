
/* Basic code to read light level from a BH1750 device via I2C */
// This code is based loosely on the BMP085 and TMP102 Temperature Reader
// because I already had those sensors working and it seemed like a good 
// place to start.

// Copyright (c) 2015 Jim Conner
// This file is licensed under the MIT license
// http://opensource.org/licenses/MIT

//-----------------------------------------------------------------------------------------
class LightDevice_BH1750 {
    // Data Members
    //   i2c parameters
    i2cPort = null;
    i2cAddress = null;
    oversampling_setting = 2; // 0=lowest precision/least power, 3=highest precision/most power

    
    //-------------------
    constructor( i2c_port, i2c_address ) {
        // example:   local mysensor = TempDevice_BMP085(I2C_89, 0x49);
        if(i2c_port == I2C_12)
        {
            // Configure I2C bus on pins 1 & 2
            hardware.configure(I2C_12);
            hardware.i2c12.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c12;
        }
        else if(i2c_port == I2C_89)
        {
            // Configure I2C bus on pins 8 & 9
            hardware.configure(I2C_89);
            hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port " + i2c_port + " specified in TempDevice_BMP085::constructor.");
        }

        i2cAddress = i2c_address;
        
    }


    function read_int_register( register_address ) {
        // read two bytes from i2c device and converts it to a short (2 byte) signed int.
        // register_address is MSB in format "\xAA"
        local reg_data = i2cPort.read(i2cAddress, register_address, 2);
        //server.log(reg_data);
        local output_int = ((reg_data[0] & 0xFF) << 8) | (reg_data[1] & 0xFF);
        // Is negative value? Convert from 2's complement:
        if (reg_data[0] & 0x80) {
            output_int = (0xffff ^ output_int) + 1;
            output_int *= -1;
        }
        // data sheet says that 0x0 and 0xffff denote bad reads. Can check integrity for looking for these values.
        if (output_int == null || output_int==0x0 || output_int == 0xffff){
            server.log( "ERROR: bad I2C return value" + reg_data + " from address " + register_address );
            //server.sleepfor(2); // puts the Imp into DEEP SLEEP, powering it down for 5 seconds. when it wakes, it re-downloads its firmware and starts over.
        }
        return output_int;
    }

    //-------------------
    function read_light_level() {
        
        // to write to our i2c device this we need to mask the last bit into a 1.
        // We can use a variety of different commands to begin conversion.
        // 0x10 is High res, continuous mode (1lux resolution)
        // 0x11 is High res, continuous mode 2 (0.5 lux resolution)
        // 0x20 is High res, one-time mode (1 lux res)
        // 0x21 is High res, one-time mode 2 (0.5 lux res)
        i2cPort.write(i2cAddress | 0x01, "\x10" ); // write 0x10 into register 0xF4
        // Wait for conversion to finish. datasheet wants 180ms max
        imp.sleep(0.18);
     
        // Read msb and lsb 
        local light_level = read_int_register("\x02");
        //server.log( "Reading Light Level=" + light_level );
        
        return light_level;
    }


}

//---------------------------------------------------------------
local mysensor = LightDevice_BH1750(I2C_89, 0xb8);
local counter = 0;

function bigLoop() { 
    counter = counter +1;
    
    // divide the result by 1.2 to get the lumens value.
    local lux = mysensor.read_light_level()/1.2;

    server.log( counter + " BH1750: " + lux + " lux " );
    
    
    imp.wakeup(5, bigLoop); // sleep for 10 seconds
}

bigLoop();

