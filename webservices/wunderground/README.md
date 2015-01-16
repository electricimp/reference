# Wunderground
[Weather Underground](http://wunderground.com) is a commercial weather service that provides real-time weather information via the Internet.

# Usage

## API Key
Create your API Key [here](http://www.wunderground.com/weather/api/).

## Instantiate a Wunderground object

Wunderground objects are bound to a specific location. To create a Wunderground object, use the following code:

	const WUNDERGROUND_KEY = "YOUR_API_KEY";
	wunderground <- Wunderground(WUNDERGROUND_KEY, "locationString");
	
The location string can take the form of any of the following:

- **Country/City:** "Australia/Sydney"
- **US State/City:** "CA/Los_Altos"
- **Lat,Lon:** "37.776289,-122.395234"
- **Zipcode:** "94022"
- **Airport code**: "SFO"

## Current Conditions

To get the current conditions, make a call to the getConditions function:

	wunderground.getConditions(function(data) {
		local weatherData = data.current_observations;
		server.log("Temp: " + temp_c);
	}
	
## Sunrise/Sunset Times

We've also exposed functionality to get Sunrise / Sunset times for a particular location. This can come in handy for projects with timer based lights, etc. To get sunrise/sunset times, make a call to getSunriseSunset. The sunrise/sunset times are encoded as objects that looks like the following:  ```{ "hour" : "14", "minute": "23" }``` 

	wunderground.getSunriseSunset(function(data) {
	    server.log(format("Sunrise at %s:%s", data.sunrise.hour, data.sunrise.minute));
    	server.log(format("Sunset at %s:%s", data.sunset.hour, data.sunset.minute));
	});

## Example use

```

const WUNDERGROUND_KEY = "";
wunderground <- Wunderground(WUNDERGROUND_KEY, "94022");

wunderground.getSunriseSunset(function(data) {
    server.log(format("Sunrise at %s:%s", data.sunrise.hour, data.sunrise.minute));
    server.log(format("Sunset at %s:%s", data.sunset.hour, data.sunset.minute));
});

wunderground.getConditions(function(data) {
    // log everything
    foreach(k, v in data.current_observation) {
        server.log(k + ": " + v);
    }
});
```