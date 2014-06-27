
// Turn off the LED, we aren't using it 
hardware.pin9.configure(DIGITAL_IN);

// Turn on the button detection
hardware.pin1.configure(DIGITAL_IN, function() {
    imp.sleep(0.02);
    if (hardware.pin1.read() == 1) {
        agent.send("button", 1);
    }
});
