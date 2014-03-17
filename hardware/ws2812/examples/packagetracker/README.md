#Neopixel Package Tracker
This class uses a strip of WS2812 "Neopixels" as an analog gauge to track shipping progress of a package. Packages are tracked by scraping [PackageTrackr](http://packagetrackr.com) for the relevant tracking numbers. Note that this method is not robust or correct for a production design; this is intended as a quick demo of what can be done with a few LEDs and an internet connection. 

Progress in shipping is calculated by dividing the number of hours of shipping already completed by the total number of hours estimated from ship date to delivery. This percentage is handed to the device, which can track several items simultaneously by using different colors. Gauges are faded up to full brightness momentarily when they are updated. 

The Electric Imp Agent in this example also serves a small web page to allow the user to add and remove tracking numbers from the tracking list. Tracking numbers are kept until manually removed by the user. 

#Hardware Configuration
This example works best aesthetically when used with a [Neopixel Ring](http://www.adafruit.com/products/1463), creating the effect of an analog gauge. The Neopixel Ring has three pins to connect:

| WS2812 Pin | Connect To |
|------------|------------|
| PWR_IN | 5V Power Supply. If running the imp breakout board from 5V, you can connect this pin to "Vin" on the imp breakout. Be sure to appropriately size your 5V power supply; WS2812 LEDs can draw up to 60 mA per LED. |
| GND | Imp Breakout Ground |
| Data In ("Din") | Imp Pin7 (SPI257 MOSI) |

