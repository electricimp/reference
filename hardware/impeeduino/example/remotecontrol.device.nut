activityLED <- hardware.pin2;
linkLED <- hardware.pin8;

server.log("Starting... ");
impeeduino <- Impeeduino();

agent.on("config", function(data) {
    server.log("Configuring pin " + data.pin);
    impeeduino.pinMode(data.pin, data.val);
});
agent.on("digitalWrite", function(data) {
    server.log("Writing " + data.val + " to pin " + data.pin);
    impeeduino.digitalWrite(data.pin, data.val);
});
agent.on("analogWrite", function(data) {
    server.log("PWM " + data.val + " to pin " + data.pin);
    impeeduino.analogWrite(data.pin, data.val);
});
agent.on("digitalRead", function(data) {
    server.log("Pin " + data.pin + " = " + impeeduino.digitalRead(data.pin));
});
agent.on("analogRead", function(data) {
    server.log("Pin A" + data.pin + " = " + impeeduino.analogRead(data.pin));
});