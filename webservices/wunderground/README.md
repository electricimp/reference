# Wunderground
[Weather Underground](http://wunderground.com) is a commercial weather service that provides real-time weather information via the Internet.  To use Weather Underground you will need to create an API key [here](http://www.wunderground.com/weather/api/).  All Weather Underground requests in this library are sent asyncronously and require a callback function to receive requested data.

**To add this library to your project, add `#require "Wunderground.class.nut:1.0.0"` to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/Wunderground/tree/v1.0.0).


##Class Usage

###### Constructor
The class’ constructor takes two required parameters (your Wunderground API Key and a location):


| Parameter     | Type         | Default | Description |
| ------------- | ------------ | ------- | ----------- |
| apiKey        | string       | N/A     | A Wunderground API Key |
| location      | string       | N/A     | A location|

###### apiKey
Create your Wunderground API Key [here](http://www.wunderground.com/weather/api/).

###### Location Formatting
The location string can take the form of any of the following:

- **Country/City:** "Australia/Sydney"
- **US State/City:** "CA/Los_Altos"
- **Lat,Lon:** "37.776289,-122.395234"
- **Zipcode:** "94022"
- **Airport code**: "SFO"


######Example Code: 	

	const WUNDERGROUND_KEY = "YOUR_API_KEY_HERE";
	const LOCATION = "CA/Los_Altos";
	
	wunderground <- Wunderground(WUNDERGROUND_KEY, LOCATION);


## Class Methods

### getLocation()
The *getLocation* method returns the location used for all Wunderground requests.

### setLocation(*newLocation*)
The *setLocation* method updates the location used for all Wunderground requests with the new location that is passed in.  The newLocation parameter must use the location formatting found in the **Class Usage** section above. 

### getConditions(*cb*)
The *getConditions* method sends an asyncronus request to Wunderground's current conditions endpoint.  The callback is passed three parameters (error, Wunderground's response, Wunderground's current conditions data).  For a full list of conditions included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/conditions&MR=1).  

######For quick reference current conditions data includes (partial list) : 

```
	{ "temp_c" : 19.1,
	  "temp_f" : 66.3,
	  "feelslike_c" : "19.1", 
	  "feelslike_f" : "66.3",
	  "weather" : "Partly Cloudy",
	  "relative_humidity" : "65%", 
	  "wind_string" : "From the NNW at 22.0 MPH Gusting to 28.0 MPH",
	  "pressure_mb" : "1013",
	  "pressure_in" : "29.93",
	  "observation_epoch" : "1340843233",
	  "local_epoch" : "1340843234",
	  "display_location" :  { "full": "San Francisco, CA" }
	}
```

######Example Code:
	wunderground.getConditions(function(err, resp, data) {
		if(err) {
			server.log(err);
		} else {
			server.log("Temp: " + data.temp_c + "°C");
		}
	});
	

### getForecast(*cb*), getExtendedForecast(*cb*) 
The *getForecast* and *getExtendedForecast* methods send an asyncronus request to Wunderground. Forecast requests a 3 day forecast, and Extended Forecast requests a 10 day forecast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's forecast data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/forecast&MR=1).  

######For quick reference forecast data includes (partial list) : 

```
	{ "txt_forecast" : { "forecastday" : [ { "title" : "Tuesday",
											  "fcttext" : "Partly cloudy in the morning, then clear. High of 68F. Breezy. Winds from the West at 10 to 25 mph.",
											  "fcttext_metric" : "Partly cloudy in the morning, then clear. High of 20C. Windy. Winds from the West at 20 to 35 km/h." 
											}, 
										    { ... } ] 
						},
	  "simpleforecast" : { "forecastday" : [ { "date" : { "epoch" : "1340776800" },
	  											"high" : { "fahrenheit" : "68",
	  											           "celsius" : "20" },
	  											"low" : { "fahrenheit" : "50",
	  											          "celsius" : "10" },
	  											"conditions" : "Partly Cloudy" 
	  										  }, 
	  										  { ... } ] 
	  					  }
	}
```

######Example Code:
	wunderground.getForecast(function(err, resp, data) {
		if(err) {
			server.log(err);
		} else {
			local forecastArray = data.txt_forecast.forecastday;
			foreach(forecast in forecastArray) {
				server.log(format("%s. %s", forecast.title, forecast.fcttext));
			}
		}
	});
		

### getHourly(*cb*)
The *getHourly* method sends an asyncronus request to Wunderground. If the optional *extended* parameter is set to true, a request for a 10 day hourly forecast will be sent, otherwise the default behavior is (extended set to false) to request a 1 day hourly forcast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's hourly data array).  For a full list of fields included in the response table see [Wunderground's documentation](http://http://www.wunderground.com/weather/api/d/docs?d=data/hourly).  

######For quick reference the hourly data array includes (partial list) : 

```
	[ { "temp" : { "english" : "66", 
					"metric" : "19" },
		"feelslike" : { "english" : "66", 
					 	"metric" : "19" },
		"condition" : "Clear",
		"humidity" : "65", 
		"wdir" : { "dir" : "West" },
		"wspd" : { "english" : "5", 
					"metric" : "8" },
		"FCTTIME" : { "epoch" : "1341338400" } 
	  }, 
	  { ... }
	]
```

######Example Code:
	wunderground.getHourly(function(err, resp, data) {
		if(err) {
       		server.log(err);
       	} else {
       		foreach(item in data) {
           		server.log(format("%s %s°C", item.condition, item.temp.metric));
       		}
       	}
	});

### getYesterday(*cb*)
The *getYesterday* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/yesterday).  

######For quick reference historical data includes (partial list) : 

```
	{ "observations" : [ { "tempi" : "59.0",
						    "tempm" : "15.0", 
						    "conds" : "Overcast", 
						    "hum" : "81", 
						    "pressurei" : "29.90",
						    "pressurem" : "1012.3", 
						    "wdire" : "WSW",
						    "wspdi" : "5.8",
						    "wspdm" : "9.3",
						    "date" : { "pretty" : "12:56 AM PDT on July 02, 2012" } 
						  },
						  { ... }
						] 
	}
```

######Example Code:
	wunderground.getYesterday(function(err, resp, data) {
    	if(err) {
        	server.log(err);
    	} else {
        	foreach(item in data.observations) {
            	server.log(format("%s %s°C on %s", item.conds, item.tempm, item.date.pretty));
        	}
    	}
	});

### getHistory(*date, cb*)
The *getHistory* method sends an asyncronus request to Wunderground for the date that is passed in. The date needs to be formated YYYYMMDD.  The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/history).

######For quick reference historical data includes (partial list) : 

```
	{ "observations" : [ { "tempi" : "59.0",
						    "tempm" : "15.0", 
						    "conds" : "Overcast", 
						    "hum" : "81", 
						    "pressurei" : "29.90",
						    "pressurem" : "1012.3", 
						    "wdire" : "WSW",
						    "wspdi" : "5.8",
						    "wspdm" : "9.3",
						    "date" : { "pretty" : "12:56 AM PDT on July 02, 2012" } 
						  },
						  { ... }
						],
	  "dailysummary" : [ { "meantempi" : "52", 
	  						"meantempm" : "11", 
	  						"humidity" : "63", 
	  						"meanpressurei" : "29.88",
	  						"meanpressurem" : "1012", 
	  						"meanwdire" : "ESE" , 
	  						"meanwindspdi" : "7", 
	  						"meanwindspdm" : "11",
	  						"precipi" : "0.27", 
	  						"precipm" : "6.86", 
	  						"date" : { "pretty" : "12:00 PM PDT on April 05, 2006" }
	  					  }
	  					] 
	} 
```
	
######Example Code:
    wunderground.getHistory(20150704, function(err, resp, data) {
        if(err) {
           server.log(err);
        } else {
           foreach(item in data.observations) {
              server.log(format("%s %s°C on %s", item.conds, item.tempm, item.date.pretty));
           }
        }
    });

### getAstronomy(*cb*)
The *getAstronomy* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's moon phase data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/astronomy).  

######For quick reference moon phase data includes (partial list) : 

```
	{ "percentIlluminated" : "81", 
	  "ageOfMoon" : "10", 
	  "current_time" : { "hour" : "9", 
	  					  "minute" : "56" }, 
	  "sunrise" : { "hour" : "7", 
	  			     "minute" : "01" }, 
	  "sunset" : { "hour" : "16", 
	  				"minute" : "56" }
	}
```

######Example Code:
    wunderground.getAstronomy(function(err, resp, data) {
        if(err) {
            server.log(err);
        } else {
            server.log(format("Sunrise is at %s:%s", data.sunrise.hour, data.sunrise.minute));
            server.log(format("Sunset is at %s:%s", data.sunset.hour, data.sunset.minute));
        }
    });

### getAlmanac(*cb*)
The *getAlmanac* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's almanac data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/almanac).  

######For quick reference almanac data includes (partial list) : 

```
	{ "airport_code" : "KSFO", 
	  "temp_high" : { "normal" : { "F" : "71", 
	  							    "C" : "22" },  
	  				   "high" : { "F" : "89", 
	  							  "C" : "31" },
	  				   "recordyear" : "1970"
	  				},
	  "temp_low" : { "normal" : { "F" : "54", 
	  							    "C" : "12" },  
	  				   "high" : { "F" : "48", 
	  							  "C" : "8" },
	  				   "recordyear" : "1953"
	  				}
	}
```

######Example Code:
    wunderground.getAlmanac(function(err, resp, data) {
        if(err) {
            server.log(err);
        } else {
            server.log(format("High Temperature Record is %s°C set in %s", data.temp_high.record.C, data.temp_high.recordyear));
            server.log(format("Low Temperature Record is %s°C set in %s", data.temp_low.record.C, data.temp_low.recordyear));
        }
    });

### getGeoLookup(*cb*)
The *getGeoLookup* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's location data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/geolookup).  

######For quick reference location data includes (partial list) : 

```
	{ "city" : "San Francisco", 
	  "state" : "CA", 
	  "country_name" : "USA", 
	  "zip" : "94101", 
	  "lat" : "37.77500916", 
	  "lon" : "-122.41825867", 
	  "nearby_weather_stations" : { "airport" : { "station" : [ { "city" : "San Francisco", 
	  											                    "state" : "CA", 
	  											                    "country" : "USA", 
	  											                    "icao" : "KSFO", 
	  											                    "lat" : "37.61999893", 
	  											                    "lon" : "-122.37000275" 
	  											                  },
	  											                  { ... } 
	  											                ] 
	  											  }
	  							   },
	  							   { "pws" : { "station" : [ { "neighborhood" : "SOMA - Near Van Ness", 
	  							   				                "city" :"San Francisco",
	  							   				                "state" : "CA", 
	  											                "country" : "USA", 
	  											                "id" : "KCASANFR58", 
	  											                "distance_mi" : 0, 
	  											                "distance_km" : 0 
	  											              },
	  											              { ... } 
	  											            ] 
	  										  }
	  							   }
	}
```

######Example Code:
    wunderground.getGeoLookup(function(err, resp, data) {
        if(err) {
            server.log(err);
        } else {
            server.log(format("Nearby Airport Weather Stations for %s, %s are:", data.city, data.state));
            foreach(airport in data.nearby_weather_stations.airport.station) {
                server.log(format("%s in %s, %s", airport.icao, airport.city, airport.state));
            }
        }
    });

### getCurrentHurricane(*cb*)
The *getCurrentHurricane* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's current hurricane data array).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/currenthurricane).  

######For quick reference current hurricane data array includes (partial list) : 

```
	[ { "stormInfo" : { "stormName" : "Daniel",
						 "stormName_Nice" : "Hurricane Daniel",
						 "stormNumber" : "ep201204"
					   },
		"Current" : { "SaffirSimpsonCategory" : 1, 
					   "Category" : "Hurricane", 
					   "lat" : 15.4, 
					   "lon" : -130.7, 
					   "WindSpeed" : { "Mph" : 75, 
					   				    "Kph" : 120 }, 
					   "WindGust" : { "Mph" : 90, 
					   				   "Kph" : 120 },  
					   "Fspeed" : { "Mph" : 16, 
					   				 "Kph" : 25 }, 
					   "Movement" : { "Text" : "W", 
					   				   "Degrees" : "275"}, 
					   "Time" : { "epoch" : "1341867600" }
					},
		"forecast" : [ { "ForecastHour" : "12H", 
						  "SaffirSimpsonCategory" : 0, 
						  "Category" : "Tropical Strom", 
						  "lat" : 15.5, 
						  "lon" : -133.0, 
						  "WindSpeed" : { "Mph" : 65, 
					   				       "Kph" : 100 },
					   	  "Time" : { "epoch" : "1341900000" }
						}, 
						{ ... }
					  ], 
		"ExtendedForecast" : [ { "ForecastHour" : "4DAY", 
						  		  "SaffirSimpsonCategory" : 0, 
						  		  "Category" : "Tropical Strom", 
						  		  "lat" : 15.8, 
						  		  "lon" : 139.3, 
						  		  "WindSpeed" : { "Mph" : 65, 
					   				              "Kph" : 25 },
					   	  		  "Time" : { "epoch" : "1342159200" }
								}, 
								{ ... }
					  		  ], 
		"track" : [ { "SaffirSimpsonCategory" : 1, 
					   "Category" : "Hurricane", 
					   "lat" : 15.2, 
					   "lon" : -129.4, 
					   "WindSpeed" : { "Mph" : 75, 
					   				       "Kph" : 120 },
					   "Time" : { "epoch" : "1341835200" }
					 }, 
					 { ... }
				   ],
	  }, 
	  { ... }
	]
```

######Example Code:
	wunderground.getCurrentHurricane(function(err, resp, data) {
		if(err) {
			server.log(err);
		} else {
		    foreach(storm in data) {
		        server.log("Name: " + storm.stormInfo.stormName);
		        server.log(format("Current Category: %i %s", storm.Current.SaffirSimpsonCategory, storm.Current.Category));
		    }
		}
	});

### getTide(*cb*)
The *getTide* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's tide data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/tide).  

######For quick reference tide data includes (partial list) : 

```
	{ "tideInfo" : [ { "tideSite" : "Newport Beach, Newport Bay Entrance, Corona del Mar, California",
					    "lat" : "33.6033", 
					    "lon" : "-117.883"
					} ],
	  "tideSummary" : [ { "date" : { "epoch" : "1341579657" },
	  					   "data" : { "height" : "-0.79 ft", 
	  					 			   "type" : "Low Tide" }
	  					 },
	  					 { ... } 
	  				   ], 
	  "tideSummaryStats" : [ { "maxheight" : 6.870000, 
	  						    "minheight" : -1.450000
	  						} ]
	}
```

######Example Code:
    wunderground.getTide(function(err, resp, d) {
        if(err) {
            server.log(err);
        } else {
            foreach(item in d.tideInfo) {
                server.log(format("Tide Summary for %s:", item.tideSite));
            }
            foreach(summary in d.tideSummary) {
                server.log(format("Tide type: %s, Tide height: %s", summary.data.type , summary.data.height));
            }
        }
    });


## License

Wunderground is licensed under [MIT License](./LICENSE).
