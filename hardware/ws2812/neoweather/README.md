#Neopixel Weather Display
This class uses a strip of WS2812 "Neopixels" as an display to show ambient "weather effects". The result is a handy gadget to have by a front door or by your desk, especially if you don't have a window. Distinct animations are included for:

* Drizzle / Rain
* Thunderstorms
* Snow
* Mist
* Ice
* Fog / Haze
* Clear / Overcast conditions: when no precipitation is present, the color of the display indicates the current temperature, and the brightness is set by the cloud conditions. Colors range from dark blue at -10ºC to warm yellow/green at around 15ºC to bright red at 30ºC. 

Weather data is obtained from [Weather Underground](wunderground.com), which has a free and very full-featured API. New users will need to sign up for a Weather Underground API key, which is free and takes less than 5 minutes. 

The Electric Imp Agent in this example also serves a small web page to allow the user to change the forecast location and view the 5-day forecast. The 5-day forecast is sourced from [forecast.io](forecast.io), another very useful service with free developer tools. 

#Hardware Configuration

| WS2812 Pin | Connect To |
| --- |
| PWR_IN | 5V Power Supply. If running the imp breakout board from 5V, you can connect this pin to "Vin" on the imp breakout. Be sure to appropriately size your 5V power supply; WS2812 LEDs can draw up to 60 mA per LED. |
| GND | Imp Breakout Ground |
| Data In ("Din") | Imp Pin7 (SPI257 MOSI) |

