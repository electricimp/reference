/*  electric imp Web Response Example (agent)
    by: Jim Lindblom
    SparkFun Electronics
    date: November 5, 2013
    modified by: Amanda Ervin
    modified date: 6/17/2014
    license: Beerware. Use, reuse, and modify this code however you see fit.
    If you find it useful, buy me a beer some day!

    The agent half of this code accomplishes two tasks:
    1. In the device.on("impValues", function) definitions, the agent receives
    a table of pin values from the imp. It stores those values in a global
    variables.
    2. On an http request, respondImpValues(request, response) is called. This
    function constructs a JSON of the imp pin values, and responds with that.

    Also, check the comment at the bottom of this code for an example HTML file,
    which sends a request to the imp, then parses and prints the response.
*/

//////////////////////
// Global Variables //
//////////////////////
   // Stores pin 2 value received from imp
_pin2 <- "";
_voltage <- "";

//////////////////////////
// Function Definitions //
//////////////////////////

// respondImpValues is called whenever an http request is received.
// This function will construct a JSON table containing our most recently
// received imp pin values, then send that out to the requester.
function respondImpValues(request,response){

    // First, construct a JSON table with our received pin values.
    local pinTable = {
          // e.g.: "pin1" : "1"
        "pin2": ""+_pin2+"",
        "voltage": ""+_voltage+"" + " V",   // e.g.: "voltage" : "3.274 V"
    }

    // the http.jsonencode(object) function takes a squirrel variable and returns a
    // standardized JSON string. - https://electricimp.com/docs/api/http/jsonencode/
    local jvars = http.jsonencode(pinTable);

    // Attach a header to our response.
    // "Access-Control-Allow-Origin: *" allows cross-origin resource sharing
    // https://electricimp.com/docs/api/httpresponse/header/
    response.header("Access-Control-Allow-Origin", "*");

    // Send out our response. 
    // 200 is the "OK" http status code
    // jvars is our response string. The JSON table we constructed earlier.
    // https://electricimp.com/docs/api/httpresponse/send/
    response.send(200,jvars);
}

// device.on("impValues") will be called whenever an "impValues" request is sent
// from the device side. This simple function simply fills up our global variables
// with the equivalent vars received from the imp.
device.on("impValues", function(iv) {
    _pin2 = iv.pin2;
    _voltage = iv.voltage;
    });

///////////
// Setup //
///////////

// http.onrequest(function) sets up a function handler to call when an http
// request is received. Whenever we receive an http request call respondImpValues
// https://electricimp.com/docs/api/http/onrequest/
http.onrequest(respondImpValues);
