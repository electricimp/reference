# PubNub
The PubNub library wraps [PubNub's API](http://www.pubnub.com/) for real time messaging. 

# Contributors
- Matt Haines
- Tom Byrne

# Example
This example shows how to perform various operations with the PubNub library, including publishing real temperature data. The device code used in this example is a copy of the device code provided in the [tempBug example](https://github.com/electricimp/examples/tree/master/tempBug) and [instructable](http://www.instructables.com/id/TempBug-internet-connected-thermometer/)

In this example, the agent is subscribed to two channels: "demo" and "temp_c". The device pushes new temperature data to the agent every 15 minutes. The agent publishes the data on the "temp_c" channel, and immediately receives it back. 

When the agent first boots, it also demonstrates the use of the history and presence functions. 