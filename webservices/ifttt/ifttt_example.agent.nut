// #include <rocky.agent.nut>
// #include <ifttt.agent.nut>


/* ==============================[ Application code ]======================== */
server.log("Rebooted")

const CHANNEL_KEY = "";
const CLIENT_ID = "";
const CLIENT_SECRET = "";
const PROXY_URL = "";
const PROXY_API_KEY = "";


// .............................................................................
rocky <- Rocky();
ifttt <- IFTTT(rocky, CHANNEL_KEY, CLIENT_ID, CLIENT_SECRET, PROXY_URL, PROXY_API_KEY);
ifttt.name = "My Big Red Button";


// .............................................................................
// IFTTT trigger configuration

ifttt.add_trigger_field("button_pressed"); 


// .............................................................................
// Sets up a test rig when requested
ifttt.test_setup(function(test_data) {
    server.log("Test setup");
    
    // Queue four test trigger events
    ifttt.trigger("button_pressed", {}, false);
    ifttt.trigger("button_pressed", {}, false);
    ifttt.trigger("button_pressed", {}, false);
    ifttt.trigger("button_pressed", {}, false);

})


// .............................................................................
// When the button is pressed ...
device.on("button", function (click) {
    
    server.log("Button pressed");
    
    // Store the data in a trigger record list
    ifttt.trigger("button_pressed");
    
})

