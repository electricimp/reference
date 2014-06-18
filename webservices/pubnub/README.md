# PubNub
The PubNub library wraps [PubNub's API](http://www.pubnub.com/) for real time messaging. 

# Contributors
- Matt Haines

#Usage
## Instantiate a PubNub object
The create a new object, you'll need your Publish-Key, Subscribe-Key, and Secret-Key

```
pubNub <- PubNub(publishKey, subscribeKey, secretKey);
```

NOTE: You can pass an optional fourth parameter - uuid. If you leave the UUID blank, the library will automatically use the last part of your agent URL.

## Publish Data
To publish data, we need to specify the channel, and the data. The data can be a basic type (string, integer, etc), an array, or an object:

```
// sending a string
pubNub.publish(channel, "test data");
// sending an object
pubNub.publish(channel, { foo = "bar" });
```

You can specify an optional third parameter - a callback function that takes two parameters: err and data. If you do not specify the callback function, a default callback function that logs the results will be used. Here's an example where we specify a callback:

```
pubNub.publish(channel, { foo = "bar" }, function(err, data) {
	if (err != null) {
		server.log("ERROR: " + err);
		return;
	}
	
	// do something interesting with data.. we're just going to log it:
	if (data[0] == 1 && data[1] == "Send") {
		server.log("Success!");
	else {
		server.log(data[1]);
	}
});

## Subscribing to Data
To subscribe to the channel, we need to specify the channel we are subscribing to, and a callback function to execute whenever there is more data. The callback function takes two parameters: err and data:

```
pubNum.subscribe(channel, function(err, data) {
	if (err != null) {
		server.log("ERROR: " + err);
		return;
	} else {
		// do something with data - we're just going to log it:
		server.log(data);
	} 
});
```

The subscribe endpoint will automatically reconnect after each datapoint, however if there is an error, you are responsible for reconnecting. 