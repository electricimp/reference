// Copyright (c) 2016 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

function requestHandler(request, response) {
    try {
        if ("command" in request.query) {
            local data = {};
            if ("async" in request.query && request.query.async == "true") {
        		data.async <- true;
        	} else {
        		data.async <- false;
        	}
            if (request.query.command == "call") {
            	data.id <- request.query.id.tointeger();
            	data.arg <- request.query.arg;
            } else if (request.query.command == "analogWrite") {
            	data.pin <- request.query.pin.tointeger();
            	data.val <- request.query.val.tofloat();
            	if (data.val > 1.0)
            		data.val = data.val.tointeger();
            } else {
				data.pin <- request.query.pin.tointeger();
				if ("val" in request.query) {
					data.val <- request.query.val.tointeger();
				}
            }
            device.send(request.query.command, data);
        }
        response.send(200, "OK"); // "200: OK" is standard return message
    } catch (ex) {
        response.send(500, ("Agent Error: " + ex)); // Send 500 response if error occured
    }
}

// Register the callback function that will be triggered by incoming HTTP requests
http.onrequest(requestHandler);