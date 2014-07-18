// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Pin allocation

btn1 <- hardware.pinU;
btn2 <- hardware.pinV;
led_blue <- hardware.pinK;
led_red <- hardware.pinE;
led_green <- hardware.pinF;

// LED configuration

led_blue.configure(DIGITAL_OUT);
led_green.configure(DIGITAL_OUT);
led_red.configure(DIGITAL_OUT);

// Initial state of LEDs (off)

led_blue.write(1);
led_green.write(1);
led_red.write(1);

// Button event handler (button1 = blue, button2 = green, button1 + button2 = red)

function configureLights()
{
    led_blue.write(1 - btn1.read());
    led_green.write(1 - btn2.read());
    led_red.write(btn1.read() == 1 && btn2.read() == 1 ? 0 : 1);
}

// Button configuration

btn1.configure(DIGITAL_IN_PULLDOWN, configureLights);
btn2.configure(DIGITAL_IN_PULLDOWN, configureLights);
