Keen IO
=======
[Keen IO](http://keen.io) is a hosted service that allows you to easily push and query event based data.

This library wraps the Keen IO data collection API.

Usage
=====
Instantiating and pushing data with the KeenIO class:

```
    const KEEN_PROJECT_ID = "";
    const KEEN_WRITE_API_KEY = "";

    keen <- KeenIO(KEEN_PROJECT_ID, KEEN_WRITE_API_KEY);
    
    eventData <- {
        location = {
            lat = 37.123
            lon = -122.123
        },
        temp = 20.4,
        humidity = 36.7
    };

	// send an event sycronously
    local result = keen.sendEvent("tempBugs", eventData);
    server.log(result.statuscode + ": " + result.body);
	
	// send an event asyncronously
	keen.sendEvent("tempBugs", eventData, function(resp) {
		server.log(resp.statuscode + ": " + resp.body);
	});
```