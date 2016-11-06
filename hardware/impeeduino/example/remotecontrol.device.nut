
activityLED <- hardware.pin2;
linkLED <- hardware.pin8;

server.log("Starting... ");
impeeduino <- Impeeduino();

agent.on("config", function(data) {
    activityLED.write(1);
    server.log("Configuring pin " + data.pin);
    impeeduino.pinMode(data.pin, data.val);
    activityLED.write(0);
});
agent.on("digitalWrite", function(data) {
    activityLED.write(1);
    server.log("Writing " + data.val + " to pin " + data.pin);
    impeeduino.digitalWrite(data.pin, data.val);
    activityLED.write(0);
});
agent.on("analogWrite", function(data) {
    activityLED.write(1);
    server.log("PWM " + data.val + " to pin " + data.pin);
    impeeduino.analogWrite(data.pin, data.val);
    activityLED.write(0);
});
agent.on("digitalRead", function(data) {
    activityLED.write(1);
    //server.log("Pin " + data.pin + " = " + impeeduino.digitalRead(data.pin));
    impeeduino.digitalRead(data.pin, function(value) {
		server.log("Pin " + data.pin + " = " + value);
    });
    activityLED.write(0);
});
agent.on("analogRead", function(data) {
    activityLED.write(1);
    //server.log("Pin A" + data.pin + " = " + impeeduino.analogRead(data.pin));
    impeeduino.analogRead(data.pin, function(value) {
		server.log("Pin A" + data.pin + " = " + value);
    });
    activityLED.write(0);
});
agent.on("call", function(data) {
    activityLED.write(1);
    server.log("Calling function " + data.id);
    impeeduino.functionCall(data.id, data.arg, function(value) {
		server.log("Function " + data.id + " returned with value: " + value);
    });
    activityLED.write(0);
});