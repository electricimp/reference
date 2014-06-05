Driver for the SHT10 Temperature/Humidity Sensor
===================================

Author: [Juan Albanell](https://github.com/juanderful11/)

Driver class for a [DHT10 temperature/humidity sensor](http://www.adafruit.com/products/1298?&main_page=product_info&products_id=1298).

[Here is the datasheet](http://www.adafruit.com/datasheets/Sensirion_Humidity_SHT1x_Datasheet_V5.pdf) that we used when writing this class.

## Hardware Setup
The SHT1x family uses a proprietary one-wire protocol. The imp emulates this protocol via bit-banging. 
To use tie data line to pull-up resistor (10K)

![Connecting a SHT10 to an Electric Imp Card](SHT10_bb.png "Connection Diagram")