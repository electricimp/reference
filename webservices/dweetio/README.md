dweet.io
=======
[dweet.io](http://dweet.io) is a 'rediculously simple messaging (and alerts)' system for the Internet of Things.

This API wraps the dweet.io API for non-locked Things.

Usage
=====
Instantiating a dweet client:

    client <- DweetIO();

Sending a dweet:

    client.dweet("myThing", { "field1": 1, "field2": "test" });

Getting the most recent dweet:

   client.get("myThing", function(resp) {
        if (resp.statuscode != 200) {
            server.log("Error getting dweet: " + resp.statuscode + " - " + resp.body);
            return; 
        }

        local data = http.jsondecode(resp.body)["with"][0];
        // do something with the data
    });

Get the last 500 dweets over a 24 hour period:

    client.getHistory("myThing", function(resp) {
        if (resp.statuscode != 200) {
            server.log("Error getting dweets: " + resp.statuscode + " - " + resp.body);
            return;
        }

        local data = http.jsondecode(resp.body)["with"];
    });

Stream dweets:

    client.stream("myThing", function(dweet) {
        // do something with the dweet
        server.log(http.jsonencode(dweet);
    });


