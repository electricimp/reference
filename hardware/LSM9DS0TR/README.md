Driver for the LSM9DS0TR Inertial Measurement Unit
===================================

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LSM9DS0TR](http://www.adafruit.com/datasheets/LSM9DS0.pdf) is a MEMS Inertial Measurement Unit (Accelerometer + Magnetometer + Angular Rate Sensor). This sensor has extensive functionality and this class has not implemented all of it. 

The LSM9DS0TR can interface over I2C or SPI. This class addresses only I2C for the time being. 

The LSM9DS0TR has two separate I2C Student addresses: one for the Gyroscope and one for the Accelerometer/Magnetometer. All three functional blocks can be enabled or disabled separately.

## Usage

#### Instantiation
The constructor takes two arguments: I2C bus and two I2C addresses; one for the Accelerometer/Magnetometer and one for the Gyroscope. Imp pins should be configured before passing them to the constructor.

```
const XM_ADDR           = 0x3C; // 8-bit I2C Student Address for Accel / Magnetometer
const G_ADDR            = 0xD4; // 8-bit I2C Student Address for Angular Rate Sensor

i2c         <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

imu  <- LSM9DS0TR(i2c, XM_ADDR, G_ADDR);
```

#### Enabling Functional Blocks
The IMU comes out of reset with all three functional blocks disabled. To begin reading them, they must be enabled.

```
imu.set_power_state_g(1);
server.log("Gyro Enabled");

imu.set_datarate_a(3);
server.log("Accel Enabled at 3.125 Hz");

imu.set_mode_cont_m();
server.log("Magnetometer in Continuous Measurement Mode at 3.125 Hz");
```

#### Reading Data
Three methods are implemented to directly read the accelerometer, magnetometer, and gyroscope. Each functional block also supports a FIFO for recording bursts of data, which is not yet implemented in this class. Each read method returns a table with three members: x, y, and z. 

The LSM9DS0TR also allows the user to read the on-chip temperature sensor (which is used to calibrate the other sensors). Note that the value returned by this temperature sensor may be very different from ambient temperature depending on which sensors are enabled. For example, in development the temperature sensor returned approximately room temperature (25&deg;C) with the accelerometer and magnetometer enabled, but approximately 42&deg;C with the gyroscope enabled.

```
local acc = imu.read_a();
local mag = imu.read_m();
local gyr = imu.read_g();
server.log(format("Accel: (%0.2f, %0.2f, %0.2f)", acc.x, acc.y, acc.z));
server.log(format("Mag:   (%0.2f, %0.2f, %0.2f)", mag.x, mag.y, mag.z));
server.log(format("Gyro:  (%0.2f, %0.2f, %0.2f)", gyr.x, gyr.y, gyr.z));
server.log(format("Temp: %d C", imu.read_temp()));
```






