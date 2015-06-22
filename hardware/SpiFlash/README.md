SPI Flash Driver Class
==============================
This class wraps some of the functionality of a NOR FLASH with a SPI interface. This class was developed for use in the [Lala Reference Design](http://electricimp.com/docs/hardware/resources/reference-designs/lala/), which uses an [MX25L3206EM2I-12G](http://www.macronix.com/en-us/Product/Pages/ProductDetail.aspx?PartNo=MX25L3206E) 32 Mbit SPI FLASH from Macronix.

Contributors
===================================
Tom Byrne

Usage
===================================

```
// configure hardware before passing to constructor
spi     <- hardware.spi257;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);
cs_l    <- hardware.pin8;
cs_l.configure(DIGITAL_OUT);
cs_l.write(1);

// instantiate class
flash <- SpiFlash(spi, cs_l)

// clear memory
flash.chipErase();
```
