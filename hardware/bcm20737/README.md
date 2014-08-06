BCM20737 "WICED Smart" Bluetooth Low Energy Module
=======================================

The BCM20737 is a Bluetooth Low-Energy SOC from Broadcom, which includes an RF Front end and an ARM Core for application use. 

This class allows the Imp to reprogram the BCM20737 by holding it in reset and reprogramming the BCM20737's external nonvolatile memory. The BCM20737 supports an I2C EEPROM or SPI Flash as external storage. This class has been tested only with an I2C EEPROM.

For more information on the BCM20737 and "WICED Smart", refer to Broadcom's [documentation](http://www.broadcom.com/products/wiced/smart/).

This code was developed on the [BCM92073X WICED Development Kit](http://avnetexpress.avnet.com/store/em/EMController/Development-Kits/Broadcom/BCM92073X-LE-KIT/_/R-5004438086478/A-5004438086478/An-0?action=part&catalogId=500201&langId=-1&storeId=500201), which is widely available.

Memory Map
=====
The BCM20737's external storage has a simple layout, consisting primarily of two sections:

- A "Static Section", 40 bytes long, at the beginning of memory. The static section contains, among other things, the 4-byte address of the beginning of the "Dynamic Section" **(stored in bytes 30-33 of the static section, little-endian)**. The Static Section appears to contain information about device configuration, and can be re-used from application to application.
- A "Dynamic Section", which varies in length.

On the BCM92073 Development Board, the BCM20737 uses a [Microchip 24FC 512kbit EEPROM](http://ww1.microchip.com/downloads/en/DeviceDoc/21754M.pdf) for external storage. The WICED SDK and examples expect the EEPROM to be organized as follows:

| Section Name | Starting Offset | Length (bytes) | Notes |
|--------------|-----------------|----------------|-------|
| Static Section 1 | 0x0000 | 40 | Default Static Section |
| Static Section 2 | 0x0100 | 40 | Used if Static Section 1 is not present or valid |
| "VS1" | 0x0140 | 1024 (1 kB) | Not sure about this one |
| Dynamic Section 1 | 0x0580 | 31232 (30.5 kB) | Application Storage. Can be larger if more space is available. |
| Dynamic Section 2 | 0x8000 | 31232 (30.5 kB) | Application Storage. Can be larger if more space is available. |


Operation
=====

This class includes methods to:

- Reset the BCM20737
- Dump the BCM20737's NVRAM (useful for dumping the image to the agent, then downloading it)
- Clear the BCM20737's NVRAM
- Reprogram the BCM20737 with a new application, or with an new application and static section

See the examples folder for complete examples.