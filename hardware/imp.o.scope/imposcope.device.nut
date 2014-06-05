imp.enableblinkup(false);
// BlinkUp Tester (fake oscilloscope)
// Will display a graph or something
 
// Constants & Globals
const SAMPLE_RATE = 960;  // Sample rate in hertz
const DURATION = 20;      // Sampling duration in seconds
blinkupData <- {length = 0, buffer = blob()};   // Data to be sent
sampling <- 0;            // Sampling flag
lastButtonPress <- 0;     // Debounce counter
 
config <- { sampleRate = SAMPLE_RATE }
 
// Alias for pin connected to collector of phototransistor
// Needs to be pulled down externally with around 47k (maybe less?)
pt_in <- hardware.pin1    // Phototransistor input
pt_s  <- hardware.pin2    // Phototransistor supply - write hi to use
btn   <- hardware.pin8    // Button - will pull pin low when pressed
led   <- hardware.pin9;   // Indicator LED - active low
 
 
function processBuffer(buffer, length) {
  if (length > 0) {
    blinkupData.length = length;
    blinkupData.buffer = buffer;
    agent.send("data", blinkupData);    // Upload data to agent
    server.log("Sending buffer of length " + length);
  }
  else {
    server.error("Buffer overrun!");
  }
}
 
function checkButton() {
  // server.log("Button state change");
  if (!(btn.read()) && hardware.millis() - lastButtonPress > 500) {
    lastButtonPress = hardware.millis();
    if (sampling == 0) {
      startRead();
    }
    else {
      stopRead();
    }
  }
}
 
function startRead() {

  sampling = 1;
  blinkupData.length = 0;               // Clear old blinkup data
  pt_s.write(1);                        // Enable phototransistor supply
  server.log("Starting sampler!");
  led.write(1);                         // Turn off status LED
  hardware.sampler.start();             // Start sampler
  agent.send("state", config);          // Tell agent we're starting
  imp.wakeup(DURATION, stopRead);
  
}
 
function stopRead() {
  if (sampling) {
    hardware.sampler.stop();            // Stop sampler
    led.write(0);                       // Turn on LED
    server.log("Stopping sampler.");
    pt_s.write(0);                      // Disable phototransistor supply
    agent.send("state", 0);             // Tell agent we're done
    sampling = 0;
  }
}
 
buffer1 <- blob(4000);
buffer2 <- blob(4000);
buffer3 <- blob(4000);
 
hardware.sampler.configure(pt_in, SAMPLE_RATE, [buffer1, buffer2, buffer3], processBuffer);
pt_s.configure(DIGITAL_OUT);
pt_s.write(0);
btn.configure(DIGITAL_IN_PULLUP, checkButton);
led.configure(DIGITAL_OUT_OD);
led.write(0);
 
function scopeStateChange(newState) {
    if (newState == 1)
        startRead();
    else if (newState == 0)
        stopRead();
}
 
agent.on("scopeRunning", scopeStateChange);
