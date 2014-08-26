led <- hardware.pin9;
// configure LED and set initial state
// note: initial state param for impOS >= 30
led.configure(DIGITAL_OUT, 0);

agent.on("setLed", function(state) {
    led.write(state);
});

