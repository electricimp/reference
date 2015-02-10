# imb_bh1750
Electric Imp device code for monitoring a BH1750 temperature sensor connected via I2C on Pins 8&amp;9

The BH1750 device seems to have an I2c address of 0xb8 when the address pin is pulled high, so that's what this code uses.

I am using 4.7K pullup resistors on the SDA and SCL lines.

Hope this helps someone out. 

Cheers!!
