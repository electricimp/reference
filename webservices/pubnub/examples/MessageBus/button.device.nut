button <- hardware.pin1;
button.configure(DIGITAL_IN_PULLUP, function() {
    imp.sleep(0.02); // hardware debounce
    agent.send("buttonState", button.read());
});

