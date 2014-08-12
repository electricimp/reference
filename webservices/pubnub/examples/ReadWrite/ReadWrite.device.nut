led <- hardware.pin9;
led.configure(DIGITAL_OUT);
led.write(0);

agent.on("led", function(state) {
    if (state == 0 || state == 1) led.write(state);
});

lastLight <- null;

function lightLoop() {
    imp.wakeup(0.25, lightLoop);
    
    local light = hardware.lightlevel() / 655.35;
    if (lastLight == null || math.abs(lastLight - light) > 5.0) {
        lastLight = light;
        agent.send("light", light);
    }
} lightLoop();