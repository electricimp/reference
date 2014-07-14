Using the STM32 Bootloader with External NOR Flash for Image Storage
==============================
In this example, the Electric Imp is connected to an external STM32 processor over UART, and a NOR flash IC over SPI. Images are downloaded to NOR flash when they arrive at the agent. A second request must be sent to the agent to then load the image from NOR flash into the STM32. 

SPI Flash is abstracted through the [SPI Flash driver class](https://github.com/electricimp/reference/tree/master/hardware/SpiFlash).

## Hardware

To use this class, you'll need to connect one of the Imp's UARTs to one of the STM32's bootloader-compatible USARTs. Note that not all of the STM32's USARTs are available for use by the bootloader. 

You'll also need to connect any two Imp pins to BOOT0 and NRST on the STM32. If BOOT1 on the STM32 is not strapped to the correct value to allow the device to enter bootloader mode, you'll need to connect that to any Imp pin as well, and provide it to the Stm32 constructor.

If you're using the STM32F4-Discovery board, you can connect it up with an Amber board as I did:

| Amber Pin | STM32 Discovery Board Pin | Description |
| --------- | ------------------------- | ----------- |
| VIN | 5V | Power for Amber / Imp |
| GND | GND | Ground |
| Pin5 | PB11 | Imp TX / STM32 RX (USART3) |
| Pin7 | PB10 | Imp RX / STM32 TX (USART3) |
| Pin8 | NRST | STM32 Reset, Active-Low |
| Pin9 | BOOT0 | STM32 BOOT0 |

Note: 
- You cannot use STM32 USART1 on the STM32F4 Discovery board because the required pins are already in use on the discovery board
- You cannot use STM32 USART2 on the STM32F4 Discovery board because the STM32F4 does not support USART bootloader on USART2

You will also need to connect the Imp to a SPI Flash IC:

| SPI Flash Pin| Amber Pin | Description |
| --------- | ------------------------- | ----------- |
| CS_L | PinD | Chip Select, Active-Low |
| SO/SIO1 | Pin2 | SPI MISO |
| WP_L | 3V3 | Write Protect, Active-Low (Not Used) |
| GND | GND | Ground |
| SI/SIO0 | Pin7 | SPI MOSI |
| SCLK | Pin5 | SPI SCLK |
| HOLD_L | VCC | Hold, Active Low (Not Used) |
| VCC | 3V3 | SPI Flash Power |


## Updating Application Code on the STM32 with the Imp

### Load New Image File Into NOR Flash

#### Push directly to the agent

Sending a binary file:

```
14:20:12-tom$ curl --data-binary @blinky.bin https://agent.electricimp.com/<ID>/push
```

Sending an Intel Hex file:

```
14:20:12-tom$ curl --data-binary @blinky.hex https://agent.electricimp.com/<ID>/push
```

#### Tell the agent to fetch the file

Include the source url as query parameter:

```
14:20:12-tom$ curl https://agent.electricimp.com/<ID>/fetch?url=<image url>
```

### Update STM32 from Image in NOR Flash

### (Not Required) Clearing NOR or STM32 Flash
