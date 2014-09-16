// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

i2c <- hardware.i2c89; // Set to desired I2C bus

i2c.configure(CLOCK_SPEED_100_KHZ);
for(local i = 2; i < 256; i+=2){
    if(i2c.read(i,"", 1) != null){
       server.log(format("Device at address: 0x%02X",i));
   }
}