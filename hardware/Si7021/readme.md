Driver for the Si7021 Temperature/Humidity Sensor
===================================

Author: [Juan Albanell](https://github.com/juanderful11/)

Driver class for a [Si7021 temperature/humidity sensor](http://www.digikey.com/product-detail/en/SI7021-A10-GM1R/336-2542-2-ND/4211753?WT.srch=1&WT.medium=cpc&WT.mc_id=IQ66882670-VQ2-g-VQ6-45013741995-VQ15-1t1-VQ16-c).

[Here is the datasheet](http://www.silabs.com/Support%20Documents/TechnicalDocs/Si7021.pdf) that we used when writing this class.

## Hardware Setup
These sensors us i2c wire protocol where the Electric Imp is the master
To use:

- tie scl and sdas line to pull-up resistors (4.7K)
- tie vdd to a decoupling capacitor (0.1uF)