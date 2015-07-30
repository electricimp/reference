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
The *getConditions* method sends an asyncronus request to Wunderground's current conditions endpoint.  The callback is passed three parameters (error, Wunderground's response, Wunderground's current conditions data).  For a full list of conditions included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/conditions&MR=1).  For quick reference current conditions data includes :

- **Current Temperature** (temp_c, temp_f)
- **"Feels Like" Temperature** (feelslike_c, feelslike_f)
- **Weather Condition** (weather)
- **Humidity** (relative_humidity)
- **Wind** (wind_string)
- **Pressure** (pressure_mb, pressure_in)
- **Time/Date** (observation_epoch, local_epoch)
- **Location** (display_location.full)


######Example Code:
	wunderground.getConditions(function(err, resp, data) {
		if(err) {
			server.log(err);
		} else {
			server.log("Temp: " + data.temp_c + "°C");
		}
	});


### getForecast(*cb, [extended]*)
The *getForecast* method sends an asyncronus request to Wunderground. If the optional *extended* parameter is set to true, a request for a 10 day forecast will be sent, otherwise the default behavior is (extended set to false) to request a 3 day forcast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's forecast data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/forecast&MR=1).  For quick reference forecast data includes :

- **Text Forecast Array** (txt_forecast.forecastday)
	- **Time of Day Discription** (txt_forecast.forecastday[arrIndex].title)
	- **Text Forecast** (txt_forecast.forecastday[arrIndex].fcttext, txt_forecast.forecastday[arrIndex].fcttext_metric)
- **Forecast Array** (simpleforecast.forecastday)
	- **Time/Date** (simpleforecast.forecastday[arrIndex].date.epoch)
	- **Temp High** (simpleforecast.forecastday[arrIndex].high.fahrenheit, simpleforecast.forecastday[arrIndex].high.celsius)
	- **Temp Low** (simpleforecast.forecastday[arrIndex].low.fahrenheit, simpleforecast.forecastday[arrIndex].low.celsius)
	- **Weather Conditions** (simpleforecast.forecastday[arrIndex].conditions)


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
	}, true);


### getHourly(*cb, [extended]*)
The *getHourly* method sends an asyncronus request to Wunderground. If the optional *extended* parameter is set to true, a request for a 10 day hourly forecast will be sent, otherwise the default behavior is (extended set to false) to request a 1 day hourly forcast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's hourly data array).  For a full list of fields included in the response table see [Wunderground's documentation](http://http://www.wunderground.com/weather/api/d/docs?d=data/hourly).  For quick reference the hourly data array includes :

- **Temperature** ([dataArrayIndex].temp.english, [dataArrayIndex].temp.metric)
- **"Feels Like" Temperature** ([dataArrayIndex].feelslike.english, [dataArrayIndex].feelslike.metric)
- **Weather Condition** ([dataArrayIndex].condition)
- **Humidity** ([dataArrayIndex].humidity)
- **Wind Direction** ([dataArrayIndex].wdir.dir)
- **Wind Speed** ([dataArrayIndex].wspd.english, [dataArrayIndex].wspd.metric)
- **Time/Date** ([dataArrayIndex].FCTTIME.epoch)


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
The *getYesterday* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/yesterday).  For quick reference historical data includes :

- **Observations Array** (observations)
	- **Temperature** (observations.[observationsArrayIndex].tempi, observations.[observationsArrayIndex].tempm)
	- **Weather Condition** (observations.[observationsArrayIndex].conds)
	- **Humidity** (observations.[observationsArrayIndex].hum)
	- **Pressure** (observations.[observationsArrayIndex].pressurei, observations.[observationsArrayIndex].pressurem)
	- **Wind Direction** ([observations.[observationsArrayIndex].wdire)
	- **Wind Speed** (observations.[observationsArrayIndex].wspdi, observations.[observationsArrayIndex].wspdm)
	- **Time/Date** (observations.[observationsArrayIndex].date.pretty)

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

### getHistory(*cb, date*)
The *getHistory* method sends an asyncronus request to Wunderground for the date that is passed in. The date needs to be formated YYYYMMDD.  The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/history).  For quick reference historical data includes :

- **Observations Array** (observations)
	- **Temperature** (observations.[observationsArrayIndex].tempi, observations.[observationsArrayIndex].tempm)
	- **Weather Condition** (observations.[observationsArrayIndex].conds)
	- **Humidity** (observations.[observationsArrayIndex].hum)
	- **Pressure** (observations.[observationsArrayIndex].pressurei, observations.[observationsArrayIndex].pressurem)
	- **Wind Direction** (observations.[observationsArrayIndex].wdire)
	- **Wind Speed** (observations.[observationsArrayIndex].wspdi, observations.[observationsArrayIndex].wspdm)
	- **Time/Date** (observations.[observationsArrayIndex].date.pretty)
- **Daily Summary Array** (dailysummary)
	- **Temperature** (dailysummary[0].meantempi, dailysummary[0].meantempm)
	- **Humidity** (dailysummary[0].humidity)
	- **Pressure** (dailysummary[0].meanpressurei, dailysummary[0].meanpressurem)
	- **Wind Direction** (dailysummary[0].meanwdire)
	- **Wind Speed** (dailysummary[0].meanwindspdi, dailysummary[0].meanwindspdm)
	- **Precipitaion** (dailysummary[0].precipi, dailysummary[0].precipm)
	- **Time/Date** (dailysummary[0].date.pretty)

######Example Code:
    wunderground.getHistory(function(err, resp, data) {
        if(err) {
           server.log(err);
        } else {
           foreach(item in data.observations) {
              server.log(format("%s %s°C on %s", item.conds, item.tempm, item.date.pretty));
           }
        }
    }, 20150704);

### getAstronomy(*cb*)
The *getAstronomy* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's moon phase data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/astronomy).  For quick reference moon phase data includes :

- **Percent Illuminated** (percentIlluminated)
- **Age of Moon** (ageOfMoon)
- **Current Time** (current_time.hour, current_time.minute)
- **Sunrise** (sunrise.hour, sunrise.minute)
- **Sunset** (sunset.hour, sunset.minute)


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
The *getAlmanac* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's almanac data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/almanac).  For quick reference almanac data includes :

- **Airport Code** (airport_code)
- **High Temperature** (temp_high)
	- **Normal** (temp_high.normal.F, temp_high.normal.C)
	- **Record** (temp_high.record.F, temp_high.record.C)
	- **Year** (temp_high.recordyear)
- **Low Temperature** (current_time.hour, current_time.minute)
	- **Normal** (temp_low.normal.F, temp_low.normal.C)
	- **Record** (temp_low.record.F, temp_low.record.C)
	- **Year** (temp_low.recordyear)

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
The *getGeoLookup* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's location data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/geolookup).  For quick reference location data includes :

- **Location Info** (city, state, country_name, zip, lat, lon)
- **Nearby Airport Weather Stations Array** (nearby_weather_stations.airport.station)
	- **City** (nearby_weather_stations.airport.station[arrIndex].city)
	- **State** (nearby_weather_stations.airport.station[arrIndex].state)
	- **Country** (nearby_weather_stations.airport.station[arrIndex].country)
	- **Airport Code** (nearby_weather_stations.airport.station[arrIndex].icao)
	- **Latitude** (nearby_weather_stations.airport.station[arrIndex].lat)
	- **Longitude** (nearby_weather_stations.airport.station[arrIndex].lon)
- **Nearby Personal Weather Stations Array** (nearby_weather_stations.pws.station)
	- **Neighborhood** (nearby_weather_stations.pws.station[arrIndex].neighborhood)
	- **City** (nearby_weather_stations.pws.station[arrIndex].city)
	- **State** (nearby_weather_stations.pws.station[arrIndex].state)
	- **Country** (nearby_weather_stations.pws.station[arrIndex].country)
	- **ID** (nearby_weather_stations.pws.station[arrIndex].id)
	- **Distance** (nearby_weather_stations.pws.station[arrIndex].distance_mi, pws.station[arrIndex].distance_km)


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
The *getCurrentHurricane* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's current hurricane data array).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/currenthurricane).  For quick reference current hurricane data array includes :

- **Strom Info Table** ([currentHurricaneArrayIndex].stormInfo)
	- **Strom Name** ([currentHurricaneArrayIndex].stormInfo.stormName, [currentHurricaneArrayIndex].stormInfo.stormName_Nice)
	- **Storm Number** ([currentHurricaneArrayIndex].stormInfo.stormNumber)
- **Current Storm Info Table** ([currentHurricaneArrayIndex].Current)
	- **Category** ([currentHurricaneArrayIndex].Current.SaffirSimpsonCategory, [currentHurricaneArrayIndex].Current.Category)
	- **Latitude** ([currentHurricaneArrayIndex].Current.lat)
	- **Latitude** ([currentHurricaneArrayIndex].Current.lon)
	- **WindSpeed** ([currentHurricaneArrayIndex].Current.WindSpeed.Mph, [currentHurricaneArrayIndex].Current.WindSpeed.Kph)
	- **WindGust** ([currentHurricaneArrayIndex].Current.WindGust.Mph, [currentHurricaneArrayIndex].Current.WindGust.Kph)
	- **Speed** ([currentHurricaneArrayIndex].Current.Fspeed.Mph, [currentHurricaneArrayIndex].Current.Fspeed.Kph)
	- **Direction** ([currentHurricaneArrayIndex].Current.Movement.Text, [currentHurricaneArrayIndex].Current.Movement.Degrees)
	- **Time** ([currentHurricaneArrayIndex].Current.Time.epoch)
- **Forecast Array** ([currentHurricaneArrayIndex].forecast)
	- **Hour in the Future for Projected Forecast Info** ([currentHurricaneArrayIndex].forecast[forecastIndex].ForecastHour)
	- **Category** ([currentHurricaneArrayIndex].forecast[forecastIndex].SaffirSimpsonCategory, [currentHurricaneArrayIndex].forecast[forecastIndex].Category)
	- **Latitude** ([currentHurricaneArrayIndex].forecast[forecastIndex].lat)
	- **Latitude** ([currentHurricaneArrayIndex].forecast[forecastIndex].lon)
	- **WindSpeed** ([currentHurricaneArrayIndex].forecast[forecastIndex].WindSpeed.Mph, [currentHurricaneArrayIndex].forecast[forecastIndex].WindSpeed.Kph)
	- **Time** ([currentHurricaneArrayIndex].forecast[forecastIndex].Time.epoch)
- **Extended Forecast Array** ([currentHurricaneArrayIndex].ExtendedForecast)
	- **Hour in the Future for Projected Forecast Info** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].ForecastHour)
	- **Category** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].SaffirSimpsonCategory, [currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].Category)
	- **Latitude** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].lat)
	- **Latitude** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].lon)
	- **WindSpeed** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].WindSpeed.Mph, [currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].WindSpeed.Kph)
	- **Time** ([currentHurricaneArrayIndex].ExtendedForecast[ExforecastIndex].Time.epoch)
- **Tracking Array** ([currentHurricaneArrayIndex].track)
	- **Category** ([currentHurricaneArrayIndex].track[trackIndex].SaffirSimpsonCategory, [currentHurricaneArrayIndex].track[trackIndex].Category)
	- **Latitude** ([currentHurricaneArrayIndex].track[trackIndex].lat)
	- **Latitude** ([currentHurricaneArrayIndex].track[trackIndex].lon)
	- **WindSpeed** ([currentHurricaneArrayIndex].track[trackIndex].WindSpeed.Mph, [currentHurricaneArrayIndex].track[trackIndex].WindSpeed.Kph)
	- **Time** ([currentHurricaneArrayIndex].track[trackIndex].Time.epoch)

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
The *getTide* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's tide data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/tide).  For quick reference tide data includes :

- **Tide Info Array** (tideInfo)
	- **Tide Site** (tideInfo[infoIndex].tideSite)
	- **Latitude** (tideInfo[infoIndex].lat)
	- **Longitude** (tideInfo[infoIndex].lon)
- **Tide Summary Array** (tideSummary)
	- **Time/Date** (tideSummary[summaryIndex].date.epoch)
	- **Height** (tideSummary[summaryIndex].data.height)
	- **Type** (tideSummary[summaryIndex].data.type)
- **Tide Summary Stats Array** (tideSummaryStats)
	- **Max Height** (tideSummaryStats[statsIndex].maxheight)
	- **Min Height** (tideSummaryStats[statsIndex].minheight)

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