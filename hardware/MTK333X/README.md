# Driver Class for the MTK333X GPS Module Family

Author: [Tom Byrne](https://github.com/ersatzavian/)

The MTK333X is a family of Global Navigation Satellite System (GNSS) modules that are repackaged and sold under different part numbers by basically every hobbyist and robotics vendor out there. For instance: 
* [Adafruit "Ultimate GPS Breakout", aka PA6H (MTK3339)](https://www.adafruit.com/product/746)
** Also available as a [module, without the breakout board](https://www.adafruit.com/product/790?gclid=EAIaIQobChMIjZblr-u-2QIVhIuzCh2EKw7qEAQYAyABEgLvnPD_BwE).
* [Sparkfun "Qwiic" XA1110, aka GTOP Titan X1, aka Mediatek MT3333](https://www.sparkfun.com/products/14414).
** This module supports I2C, a feature this class doesn't include yet but could be extended to include. 
* [Sparkfun GPS Logger, aka GP3906-TLP, aka Mediatek MT3339](https://www.sparkfun.com/products/13750)

## Hardware Setup

| GPS Breakout Pin | Imp Breakout Pin | Notes |
| ----------------- | ---------------- | ----- |
| Vin | 3V3 | Power |
| GND | GND |  |
| TX> | Any Imp UART RX Pin (Ex: Pin2, Pin7) | Imp UART RX |
| RX< | Any Imp UART TX Pin (Ex: Pin1, Pin5) | Imp UART TX |
| Fix | Any Imp GPIO | DIGITAL_IN, Optional |
| EN | Any Imp GPIO | DIGITAL_OUT, Optional |
| PPS | Any Imp GPIO | Not implemented in this Class |

## Instantiation

GPIO pins must be configured before passing to the constructor. The UART need not be configured as it will be re-configured to assign the class's internal UART RX callback.

```
uart <- hardware.uart57;
fix <- hardware.pin8;
en <- hardware.pin9;

// don't need to configure the UART because the PA6H class will reconfigure it anyway
fix.configure(DIGITAL_IN);
en.configure(DIGITAL_OUT,0);

gnss <- MTK333X(uart, en, fix);
```

## General Interface

The MTK333X family of GNSS modules all use standard NMEA 0183 command sequences in ASCII over UART (or in some cases I2C). This class lazily uses pre-built command strings with pre-calculated checksums. If you want to add new commands, you can build them pretty simply by reviewing the [PMTK command datasheet](https://cdn-shop.adafruit.com/datasheets/PMTK_A11.pdf) (or another NMEA command reference guide), and then using a checksum calculator such as the one at [https://en.wikipedia.org/wiki/NMEA_0183](https://en.wikipedia.org/wiki/NMEA_0183).

## Usage

### Basic System Functions

#### enable( )
Drive the enable line high to enable the GNSS module, if an enable pin was provided to the constructor.

```
gnss.enable();
```

#### disable( )
Drive the enable line low to disable the GNSS module, if an enable pin was provided to the constructor.

```
gnss.disable();
```

#### wakeup( )
Send a single byte to wake the GNSS module from standby mode.

```
gnss.wakeup();
```

#### standby( )
Send the standby mode to put the GNSS module into a low-power state. No updated position information will be generated until wakeup() is called.

```
gnss.standby();
```

#### setBaud( baud )
Set the baud rate used to communicate with the module. Supported rates are 9600 (default), 57600, and 115200. Reconfigures the imp's UART with the given baud. This function checks to ensure the requested baud rate is valid and will throw an error if an invalid baud is given.

```
gnss.setBaud(115200);
```

#### hasFix( )
Reads the value of the FIX pin and returns it. Returns null if a FIX pin was not provided to the constructor.

```
if (gnss.hasFix()) server.log("GPS fix established");
```

### GNSS Modes

The GNSS module can calculate and report several different types of position and navigation data:

| Mode | Description |
| ---- | ----------- |
| GGA | Time, position and fix |
| GSA | GNSS receiver operating mode, active satellites used in the position solution and Dilution of Precision (DOP) values |
| GSV | The number of GNSS satellites in view, satellite ID numbers, elevation, azimuth, and Signal-to-Noise (SNR) values |
| RMC | Time, date, position, course and speed data. Recommended Minimum Navigation Information. |
| VTG | Course and speed information relative to the ground |


#### setModeRMCGGA( )
Set the module to report updates to Minimum Navigational Data (RMC) and Positional Data (GGA). 

```
gnss.setModeRMCGGA();
```

#### setModeRMC( ) 
Set the module to report updates to RMC data only. Best for minimal spurious output.

```
gnss.setModeRMC();
```

#### setModeAll( )
Set the module to report updates to any and all navigational data (GGA, GSA, GSV, RMC, and VTG)

```
gnss.setModeAll();
```

#### setReportingRate( rateSeconds )
Set the time period between navigational data reports, in seconds. Note that this does not change the rate at which this data is calculated (use setUpdateRate to change the time between GPS solutions). Accepts reporting period in seconds, and will round up to the nearest supported reporting period. Supported periods are 0.1s, 0.2s, 1s, and 10s. 

```
gnss.setReportingRate(10.0);
```

#### setUpdateRate( rateSeconds )
Set the time period between GNSS solutions, in seconds. Will round up to the nearest supported update period. Supported periods are 0.2s, 1s, and 10s.

```
gnss.setUpdateRate(10.0);
```

### GNSS Data
Example:

```
_last_pos_data = {
	"time" 			= 064951.000, 	// UTC Time 064951.000 hhmmss.sss
	"lat" 			= 2307.1256, 	// Latitude ddmm.mmmm
	"ns" 			= "N", 			// North/South indication
	"lon" 			= 12016.4438,	// Longitude ddmm.mmmm
	"ew" 			= "E",			// East/West indication
	"fix"   		= "1",			// Position Fix
	"sats_used"		= 8, 			// Range 0 to 14
	"hdop"			= 0.95, 		// Horizontal Dilution of Precision
	"msl"			= 39.9,			// altitude in meters above Mean Sea Level
	"units_alt"		= "M", 			// Units of altitude (meters)
	"geoidal_sep"	= 17.8,			// geoidal seperation
	"units_sep" 	= "M",			// Units of geoidal seperation (meters)
	"diff_corr" 	= "",			// Age of Differential Correlation (not used)
	"mode" 			= "M", 			// Depends on Type of Fix Data provided 
	"mode1"			= "2",			// 1 = Fix not available, 2 = 2D (<4 Sats Used), 3 = 3D (>= 4 sats used)
	"mode2" 		= "2",
	"sats_used_1" 	= "2", 			// sats used on channel 1
	...
	"sats_used_12" = "0", 			// sats used on channel 12
	"pdop"			= 0.8, 			// positional dilution of precision
	"hdop"			= 0.92, 		// horizontal dilution of precision
	"vdop"			= 0.93,			// vertical dilution of precision
	"sats_in_view" = 8, 			// number of satellites in view
	"sats"			= [				// array of currently-tracked satellites
		{
			"id" 			= 29,	// satellite ID
			"elevation"		= 30.0, // satellite elevation in degrees
			"azimuth"		= 91.0, // satellite azimuth in degrees
			"snr"			= 3.0 	// satellite signal-to-noise ratio
		},
		{
			...
		}
	],
	"status" 		= "A", 			// A = data valid, V = data not valid
	"gs_knots"		= 30.0,			// Ground Speed in Knots
	"true_course"	= 156.0,		// True Course over ground in degrees
	"date"			= "050514",		// Date, mmddyy
	"mag_var"		= 3.1,			// Magnetic Variation (not used)
	"gs_kmph"		= 5.1,			// Ground speed in kilometers per hour
	"ant_status" 	= 1 			// 1 = active antenna shorted, 2 = using internal antenna, 3 = using active antenna
}
```

#### getPostion()
Returns the latest values in the _last_pos_data table. See example above for fields.

```
agent.send("navdata", gnss.getPosition());
```

#### setPositionCallback( callback )
Assign a callback to be called when Position (GGA) data is updated.

```
gnss.setPositionCallback(function(pos_data) {
	// Send updated lat and lon to the agent
	agent.send("location", {"lat" = pos_data.lat, "lon" = pos_data.lon});
});
```

#### setDopCallback( callback )
Assign a callback to be called when Dilution-of-Precision data is updated.

```
gnss.setDopCallback( function(dop_data) {
	// Send updated horizontal-dilution-of-precision data to the the agent
	agent.send("hdop", dop_data.hdop);
});
```

#### setSatsCallback( callback ) 
Assign a callback to be called when Satellite data is updated.

```
gnss.setSatsCallback( function(sats_data) {
	// Send the updated number of satellites in view to the agent
	agent.send("sats", sats_data.sats_in_view));
});
```

#### setRmcCallback( callback ) 
Assign a callback to be called when minimum navigational data is updated.

```
gnss.setRmcCallback( function(rmc_data) {
	// send updated ground speed to the agent
	agent.send("ground_speed", rmc_data.gs_knots);
});
```
#### setVtgCallback( callback )
Assign a callback to be called when course-over-ground data is updated.

```
gnss.setVtgCallback( function(vtg_data) {
	// send updated true course to the agent
	agent.send("course", vtg_data.true_course);
});
```

#### setAntStatusCallback( callback )
Assign a callback to be called when antenna status is updated.

```
gnss.setAntStatusCallback( function(ant_data) ) {
	if (ant_data.ant_status == 2) {
		server.log("Internal Antenna in Use");
	}
});
```