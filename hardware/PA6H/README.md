#Driver Class for the PA6H GPS Module

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [PA6H](http://www.adafruit.com/datasheets/GlobalTop-FGPMMOPA6H-Datasheet-V0A.pdf) is a GPS module wiht integrated antenna and UART interface, [available on a breakout from Adafruit](http://www.adafruit.com/product/746) and other retailers. This module has a great deal of built-in functionality and can track satellites on 66 channels.

## Hardware Setup

| PA6H Breakout Pin | Imp Breakout Pin | Notes |
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

gps <- PA6H(uart, en, fix);
```

## Usage

### Basic System Functions

#### enable( )
Drive the enable line high to enable the PA6H, if an enable pin was provided to the constructor.

```
gps.enable();
```

#### disable( )
Drive the enable line low to disable the PA6H, if an enable pin was provided to the constructor.

```
gps.disable();
```

#### wakeup( )
Send a single byte to wake the PA6H from standby mode.

```
gps.wakeup();
```

#### standby( )
Send the standby mode to put the PA6H into a low-power state. No updated position information will be generated until gps.wakeup() is called.

```
gps.standby();
```

#### setBaud( baud )
Set the baud rate used to communicate with the PA6H. Supported rates are 9600 (default) and 57600. Reconfigures the imp's UART with the given baud. This function checks to ensure the requested baud rate is valid and will throw an error if an invalid baud is given.

```
gps.setBaud(57600);
```

#### hasFix( )
Reads the value of the FIX pin and returns it. Returns null if a FIX pin was not provided to the constructor.

```
if (gps.hasFix()) server.log("GPS fix established");
```

### GPS Modes

The PA6H can calculate and report several different types of position and navigation data:

| Mode | Description |
| ---- | ----------- |
| GGA | Time, position and fix |
| GSA | GPS receiver operating mode, active satellites used in the position solution and Dilution of Precision (DOP) values |
| GSV | The number of GPS satellites in view, satellite ID numbers, elevation, azimuth, and Signal-to-Noise (SNR) values |
| RMC | Time, date, position, course and speed data. Recommended Minimum Navigation Information. |
| VTG | Course and speed information relative to the ground |


#### setModeRMCGGA( )
Set the PA6H to report updates to Minimum Navigational Data (RMC) and Positional Data (GGA). 

```
gps.setModeRMCGGA();
```

#### setModeRMC( ) 
Set the PA6H to report updates to RMC data only. Best for minimal spurious output.

```
gps.setModeRMC();
```

#### setModeAll( )
Set the PA6H to report updates to any and all navigational data (GGA, GSA, GSV, RMC, and VTG)

```
gps.setModeAll();
```

#### setReportingRate( rateSeconds )
Set the time period between navigational data reports, in seconds. Note that this does not change the rate at which this data is calculated (use setUpdateRate to change the time between GPS solutions). Accepts reporting period in seconds, and will round up to the nearest supported reporting period. Supported periods are 0.1s, 0.2s, 1s, and 10s. 

```
gps.setReportingRate(10.0);
```

#### setUpdateRate( rateSeconds )
Set the time period between GPS solutions, in seconds. Will round up to the nearest supported update period. Supported periods are 0.2s, 1s, and 10s.

```
gps.setUpdateRate(10.0);
```

### GPS Data
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
agent.send("navdata", gps.getPosition());
```

#### setPositionCallback( callback )
Assign a callback to be called when Position (GGA) data is updated.

```
gps.setPositionCallback(function(pos_data) {
	// Send updated lat and lon to the agent
	agent.send("location", {"lat" = pos_data.lat, "lon" = pos_data.lon});
});
```

#### setDopCallback( callback )
Assign a callback to be called when Dilution-of-Precision data is updated.

```
gps.setDopCallback( function(dop_data) {
	// Send updated horizontal-dilution-of-precision data to the the agent
	agent.send("hdop", dop_data.hdop);
});
```

#### setSatsCallback( callback ) 
Assign a callback to be called when Satellite data is updated.

```
gps.setSatsCallback( function(sats_data) {
	// Send the updated number of satellites in view to the agent
	agent.send("sats", sats_data.sats_in_view));
});
```

#### setRmcCallback( callback ) 
Assign a callback to be called when minimum navigational data is updated.

```
gps.setRmcCallback( function(rmc_data) {
	// send updated ground speed to the agent
	agent.send("ground_speed", rmc_data.gs_knots);
});
```
#### setVtgCallback( callback )
Assign a callback to be called when course-over-ground data is updated.

```
gps.setVtgCallback( function(vtg_data) {
	// send updated true course to the agent
	agent.send("course", vtg_data.true_course);
});
```

#### setAntStatusCallback( callback )
Assign a callback to be called when antenna status is updated.

```
gps.setAntStatusCallback( function(ant_data) ) {
	if (ant_data.ant_status == 2) {
		server.log("Internal Antenna in Use");
	}
});
```