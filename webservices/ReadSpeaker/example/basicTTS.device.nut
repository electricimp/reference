t DAC_SAMPLE_RATE = 24000;

dac <- hardware.fixedfrequencydac;
hardware.pin2.configure(DIGITAL_OUT);
hardware.pin2.write(0);

function buffer_empty(buffer) {
    hardware.pin2.write(0);
    dac.stop();
    server.log("Done!")
}

agent.on("audio", function(data) {
    server.log("Starting..");
    server.log(typeof(data));
    dac.configure(hardware.pin5, DAC_SAMPLE_RATE, [ data ], buffer_empty, A_LAW_DECOMPRESS | AUDIO);
    hardware.pin2.write(1);
    imp.wakeup(0.02, function() { dac.start(); });
});

