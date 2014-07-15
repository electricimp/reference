// Pin allocation
btn1     <- hardware.pinU;
btn2     <- hardware.pinV;
led_blu  <- hardware.pinK;
led_red  <- hardware.pinE;
led_grn  <- hardware.pinF;

// LED configuration
led_blu.configure(DIGITAL_OUT);
led_grn.configure(DIGITAL_OUT);
led_red.configure(DIGITAL_OUT);

// Initial state of LEDs (off)
led_blu.write(1);
led_grn.write(1);
led_red.write(1);

// Button event handler (button1 = blue, button2 = green, button1 + button2 = red)
function configure_lights() {
    led_blu.write(1-btn1.read());
    led_grn.write(1-btn2.read());
    led_red.write(btn1.read() == 1 && btn2.read() == 1 ? 0 : 1);
}

// Button configuration
btn1.configure(DIGITAL_IN_PULLDOWN, configure_lights);
btn2.configure(DIGITAL_IN_PULLDOWN, configure_lights);
