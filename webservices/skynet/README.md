ElectricImp-SkyNet
==================
Electric Imp wrapper for the [SkyNet.im](http://skynet.im) REST API

Usage
=====
Initialization
--------------
Create a SkyNet client with a unique token:

```
const TOKEN = "b9a964a0-f3b9-4974-b2ad-024dae549f5e";
skynet <- SkyNet.Client(token);
````

Create a Device
---------------
You can create a device with a UUID and (optionally) arbitrary metadata/properties. We recommend using your Agent URL as the UUID, but you can use what ever you want:

```
uuid <- split(http.agenturl(), "/").pop();
device <- skynet.CreateDevice(uuid, {
    lat = 102.23,
    long = 42.34,
    deviceType = "tempbug"
});
```

Get a Device
------------
You can GET an existing device by requesting a device with a specific UUID. If the device's token matches you're token, you will be able to modify it:

```
device <- skynet.GetDevice(uuid);
```

Pushing Data
------------
Once you have a device object (either through GetDevice, or CreateDevice) you can push data to it's stream:

```
device.Push({
    temp = tempData,
    ts = time()
});
```

Streaming Data
--------------
You can data from your device (or any other with public data) by supply an onData callback, then opening a stream with StreamData:

```
// setup onData callback
device.onData(function(data) {
    if ("temp" in data) {
        if (temp.data.tofloat() > 75.0) {
            device.send("TurnOnAC", null);
        } else if (temp.data.tofloat() < 68.0) {
            device.send("TurnOnHeat", null);
        }
    }
});

// open stream:
device.StreamData(true);    // true = auto-reconnect
```

