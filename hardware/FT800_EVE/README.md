Partial Driver for FT800 Embedded Video Engine
===================================

Driver class for a [FTDI FT800 Embedded Video Engine](http://www.ftdichip.com/Support/Documents/ProgramGuides/FT800%20Programmers%20Guide.pdf).

The FT800 is underlying hardware for the [Gameduino 2](http://excamera.com/sphinx/gameduino2/). You may wish to review the [Gameduino 2 Cookbook](http://excamera.com/files/gd2book_v0.pdf).

Contributors
===================================
Tom Byrne
Jason Snell

## Hardware Setup
This class requires a SPI interface and three GPIO pins to use. In the example, the device is connected to an Electric Imp breakout board as follows

| Imp Pin | EVE Pin | Purpose |
|---------|---------|---------|
|   Pin1  | SCK     | SPI Clock |
|   Pin2  | PD#     | Power Down, Active Low |
|   Pin5  | INT#    | Interrupt, Active Low |
|   Pin7  | CS#     | SPI Chip Select, Active Low |
|   Pin8  | MOSI    | SPI Master Out, Slave In |
|   Pin9  | MISO    | SPI Master In, Slave Out |

## Basic Usage

```
cs_l_pin <- hardware.pin7;
cs_l_pin.configure(DIGITAL_OUT);
cs_l_pin.write(1);

pd_l_pin <- hardware.pin2;
pd_l_pin.configure(DIGITAL_OUT);
pd_l_pin.write(0);

// int pin gets configured inside the class
int_pin <- hardware.pin5;

// Configure SPI @ 4Mhz
spi <- hardware.spi189;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 4000);

display <- FT800(spi, cs_l_pin, pd_l_pin, int_pin);
```

Initialization is somewhat involved, and should be done in a callback on power-up, as power-up is relatively slow and is therefore asynchronous:

```
// power-up takes some time so it is done asynchronously
display.power_up(function() {
	display.init();
    display.config();
    server.log("Powered Up");
    // Do a little more configuration
    // enable touch interrupts (all sources enabled by default)
    display.gpu_write_mem8(REG_INT_EN, 0x01);
    // enable interrupts on touch events only
    display.gpu_write_mem8(REG_INT_MASK, 0x02);
    // Doing development on my desk with display upside-down.
    display.set_rotation(1);
    display.cp_clear_cst(1,1,1);
    display.cp_text(FT_DispWidth/2, 40, 28, OPT_CENTER, "Please tap the dots to calibrate.");
    display.cp_spinner(FT_DispWidth/2,FT_DispHeight/2,3,0);
    display.cp_swap();
    // calibration is required on any time the display is powered up or rotated 
    // start calibration on any touch, and clear this callback as soon as it's called.
    display.on_any_touch(calibrate,1);
});
```