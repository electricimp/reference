function requestHandler(request, response) {
    try {
        if ("command" in request.query) {
            local data = {};
            data.pin <- request.query.pin.tointeger();
            if ("val" in request.query) {
                data.val <- request.query.val.tointeger();
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