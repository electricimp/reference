led <- hardware.pin9;
led.configure(DIGITAL_OUT);
led.write(0);

buttonToggle <- hardware.pin2;
buttonToggle.configure(DIGITAL_OUT_OD);
buttonToggle.write(0);

button <- hardware.pin7;
button.configure(DIGITAL_IN_PULLUP, function() {
    imp.sleep(0.02);
    if (button.read() == 1) {
        agent.send("toggleLed", null)
    }
});

agent.on("led", function(state) {
    try {
        led.write(state);
    } catch (ex) {
        server.log("error setting led: " + ex);
    }
});
