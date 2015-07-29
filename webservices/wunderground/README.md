# Wunderground
[Weather Underground](http://wunderground.com) is a commercial weather service that provides real-time weather information via the Internet.

**To add this library to your project, add #require "Wunderground.class.nut:1.0.0"` to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/Wunderground/tree/v1.0.0).


##Class Usage

###### Constructor
The class’ constructor takes two required parameters (your Wunderground API Key and a default location):


| Parameter     | Type         | Default | Description |
| ------------- | ------------ | ------- | ----------- |
| apiKey        | string       | N/A     | A Wunderground API Key |
| location      | string       | N/A     | A default location|

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

	const WUNDERGROUND_KEY = "YOUR_API_KEY";
	const LOCATION = "CA/Los_Altos";

	wunderground <- Wunderground(WUNDERGROUND_KEY, LOCATION);


## Class Methods

### getLocation()
The *getLocation* method returns the location used for all Wunderground requests.

### setLocation(*newLocation*)
The *setLocation* method updates the location used for all Wunderground requests with the new location that is passed in.  The newLocation parameter must use the location formatting found in the **Class Usage** section above.

### getConditions(*cb*)
The *getConditions* method sends an asyncronus request to Wunderground's current conditions endpoint.  The callback is passed three parameters (error, Wunderground's response, Wunderground's current conditions data).  For a full list of conditions included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/conditions&MR=1).  For quick reference data includes :

- **current temp** (temp_c, temp_f)
- **"feels like" temp** (feelslike_c, feelslike_f)
- **weather condition** (weather)
- **humidity** (relative_humidity)
- **wind** (wind_string)
- **pressure** (pressure_mb, pressure_in)
- **time/date** (observation_epoch, local_epoch)
- **location** (display_location.full)


######Example Code:
	wunderground.getConditions(function(err, resp, data) {
		if(err) {
			server.log(err);
		} else {
			server.log("Temp: " + data.temp_c + "°C");
		}
	});


### getForecast(*cb, [extended]*)
The *getForecast* method sends an asyncronus request to Wunderground. If the optional *extended* parameter is set to true, a request for a 10 day forecast will be sent, otherwise the default behavior is (extended set to false) to request a 3 day forcast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's forecast data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/forecast&MR=1).  For quick reference data includes :

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
The *getHourly* method sends an asyncronus request to Wunderground. If the optional *extended* parameter is set to true, a request for a 10 day hourly forecast will be sent, otherwise the default behavior is (extended set to false) to request a 1 day hourly forcast.  The callback is passed three parameters (error, Wunderground's response, Wunderground's hourly data).  For a full list of fields included in the response table see [Wunderground's documentation](http://http://www.wunderground.com/weather/api/d/docs?d=data/hourly).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getYesterday(*cb*)
The *getYesterday* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/yesterday).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getHistory(*cb, date*)
The *getHistory* method sends an asyncronus request to Wunderground for the date that is passed in. The date needs to be formated YYYYMMDD.  The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/history).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getAstronomy(*cb*)
The *getAstronomy* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/astronomy).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getAlmanac(*cb*)
The *getAlmanac* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/almanac).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getGeoLookup(*cb*)
The *getGeoLookup* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/geolookup).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getCurrentHurricane(*cb*)
The *getCurrentHurricane* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/currenthurricane).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd

### getTide(*cb*)
The *getTide* method sends an asyncronus request to Wunderground. The callback is passed three parameters (error, Wunderground's response, Wunderground's historical data).  For a full list of fields included in the response table see [Wunderground's documentation](http://www.wunderground.com/weather/api/d/docs?d=data/tide).  For quick reference data includes :

- **TBD** (tbd)

######Example Code:
	tbd


## License

Rocky is licensed under [MIT License](./LICENSE).