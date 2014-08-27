# PubNub
The PubNub library wraps [PubNub's API](http://www.pubnub.com/) for real time messaging. 

# Contributors
- Matt Haines
- Tom Byrne

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
```

## Subscribing to Data
To subscribe to the channel, we need to specify the channel(s) we are subscribing to, and a callback function to execute whenever there is more data. The callback function takes three parameters: err, result, and timetoken. The "result" parameter is a table containing a channel/value pair for each channel/message received:

```
pubNub.subscribe(["foo", "demo"], function(err, data, tt) {
    if (err != null) {
        server.log(err);
        return;
    }
    
    local logstr = "Received at " + tt + ": "
    local idx = 1;
    foreach (channel, value in data) {
        logstr += (channel + ": "+ value);
        if (idx++ < data.len()) {
            logstr += ", ";
        }
    }
    server.log(logstr);
});
```

The subscribe endpoint will automatically reconnect after each datapoint, however if there is an error, you are responsible for reconnecting. 

## Getting Channel History
To get historical values published on a given channel, specify the channel, the max number of values to return, and a callback to execute when the data arrives. The callback takes two parameters: err, and data. The err parameter is null on success. The data parameter is an array of messages.

```
// get up to 50 historical values from the demo channel
pubNub.history("demo",50,function(err, data) {
    if (err != null) {
        server.error(err);
    } else {
        server.log("History: "+http.jsonencode(data));
    }
});
```

## Presence Detection: whereNow
The whereNow function returns a list of channels on which this client's UUID is currently "present". A UUID is marked present when it publishes or subscribes to a channel, and is removed when that client leaves a channel with the *leave* method. The whereNow function takes one parameter: a callback function to execute with the list of channels is returned. The callbck function must take two parameters: err and channels. The err parameter is null on success, and the channels parameter is an array of channels for which the UUID is present.

```
// list the channels that this UUID is currently present on
pubNub.whereNow(function(err,channels) {
    if (err != null) {
        server.log(err);
    }
    server.log("Currently watching channels: "+http.jsonencode(channels));
});
```

## Presence Detection: hereNow
The hereNow function provides the current occupancy of a given channel. The whereNow function takes one parameter: a callback function. The callback takes two parameters: err and result. The err parameter is null on success. The result parameter is a table with two members: *result.occupancy* (an integer) and *result.uuids* (an array).

```
// list the UUIDs that are currently watching the temp_c channel
pubNub.hereNow("temp_c",function(err,result) {
    if (err != null) {
        server.log(err);
    }
    server.log(result.occupancy + " Total UUIDs watching temp_c: "+http.jsonencode(result.uuids));
});
```

## Presence Detection: globalHereNow
The globalHereNow function provides the current occupancy of a given subscribe key. The globalWhereNow function takes one parameter: a callback function. The callback takes two parameters: err and result. The err parameter is null on success. The result parameter contains a key/value pair for each channel on the requested subscribe key; the key is the channel name, and each value is a table with two members: *channel.occupancy* (an integer) and *channel.uuids* (an array).

```
// list all channels and UUIDs that are currently using the same subscribe key as us
pubNub.globalHereNow(function(err,result) {
    if (err != null) {
        server.log(err);
    }
    server.log("Other Channels Using this Subscribe Key:");
    foreach (chname, channel in result) {
        server.log(chname + " (Occupancy: "+channel.occupancy+"): "+http.jsonencode(channel.uuids));
    }
});
```