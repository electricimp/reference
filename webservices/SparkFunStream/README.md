SparkFunStream
==============

The SparkFunStream class wraps the [data.sparkfun.com](https://data.sparkfun.com) API. It is a very simple data store to get up and running with.

Contributors
============

Matt

Example Code
============

```
/******************** Application Code ********************/
// Create a Sparkfun Data Stream

const SPARKFUN_PUBLIC_KEY = "";
const SPARKFUN_PRIVATE_KEY = "";

stream <- SparkFunStream(SPARKFUN_PUBLIC_KEY, SPARKFUN_PRIVATE_KEY);

// Syncronous Push:
local resp = stream.push({ temp = 102.5 });
server.log(format("PUSH: %i - %s", resp.statuscode, resp.body));

// Asyncronous Push:
stream.push({ temp = 103}, function(resp) {
    server.log(format("PUSH: %i - %s", resp.statuscode, resp.body));
})

// Syncronous Get:
resp = stream.get();
server.log(resp.body);

// Asyncronous Get:
stream.get(function(resp) {
    server.log(resp.body);
});

// Syncronous Clear:
resp = stream.clear();
server.log(format("CLEAR: %i - %s", resp.statuscode, resp.body));

// Asyncronous Clear:
stream.clear(function(resp) {
    server.log(format("CLEAR: %i - %s", resp.statuscode, resp.body));
});

```
