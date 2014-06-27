#include "rocky.agent.nut"
#include "ifttt.agent.nut"


/* ==============================[ Application code ]======================== */
server.log("Rebooted")

const CHANNEL_KEY = "";
const CLIENT_ID = "";
const CLIENT_SECRET = "";
const PROXY_URL = "https://agent.electricimp.com/xxxxxxxx";
const PROXY_API_KEY = "";


// .............................................................................
rocky <- Rocky();
ifttt <- IFTTT(rocky, CHANNEL_KEY, CLIENT_ID, CLIENT_SECRET, PROXY_URL, PROXY_API_KEY);
ifttt.name = "Hannah";


// .............................................................................
// IFTTT trigger configuration

ifttt.add_trigger_field("button_pressed", "device", ifttt.agentid, ifttt.agentid); 
ifttt.add_trigger_field("button_pressed", "button", "Button One", "1"); 
ifttt.add_trigger_field("button_pressed", "button", "Button Two", "2"); 
ifttt.add_trigger_field("button_pressed", "button", "Either Button", "either"); 
ifttt.add_trigger_field("button_pressed", function(filter, event) {
    // Check if this event passes the trigger's filter
    if ("button" in filter && "button" in event) {
        if (filter.button == "either" || filter.button == event.button) {
            return true;
        } else {
            return false;
        }
    } else {
        return true;
    }
});

ifttt.add_action_field("set_led", "device", ifttt.agentid, ifttt.agentid);
ifttt.add_action_field("set_led", "colour", "Off", "off");
ifttt.add_action_field("set_led", "colour", "White", "white");
ifttt.add_action_field("set_led", "colour", "Red", "red");
ifttt.add_action_field("set_led", "colour", "Green", "green");
ifttt.add_action_field("set_led", "colour", "Blue", "blue");
ifttt.add_action_field("set_led", "colour", "Cyan", "cyan");
ifttt.add_action_field("set_led", "colour", "Magenta", "magenta");
ifttt.add_action_field("set_led", "colour", "Yellow", "yellow");
ifttt.action("set_led", function(context, fields) {
    server.log("Set LED to: " + fields.colour);
    device.send("set_led", fields.colour)
    ifttt.action_ok(context)
});



// .............................................................................
// Sets up a test rig when requested
ifttt.test_setup(function(test_data) {
    server.log("Test setup");
    
    // Queue at least three test trigger events
    ifttt.trigger("button_pressed", { button="1" }, false);
    ifttt.trigger("button_pressed", { button="1" }, false);
    ifttt.trigger("button_pressed", { button="1" }, false);
    ifttt.trigger("button_pressed", { button="2" }, false);
    ifttt.trigger("button_pressed", { button="2" }, false);
    ifttt.trigger("button_pressed", { button="2" }, false);
    imp.wakeup(30, function() {
        server.log("Tests cleared")
        ifttt.clear_triggers();
        device.send("set_led", "off");
    })

})


// .............................................................................
// When the button is pressed ...
device.on("button", function (button) {
    
    // Store the data in a trigger record list
    ifttt.trigger("button_pressed", { button=button.tostring() });
    
})

