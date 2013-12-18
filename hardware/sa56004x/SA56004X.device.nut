// Temperature Sensor Class for SA56004X
class SA56004X
{
    i2cPort = null;
    i2cAddress = null;
    conversionRate = 0x04;
 
    constructor(port, address)
    {
        if(port == I2C_12)
        {
            // Configure I2C bus on pins 1 & 2
            hardware.configure(I2C_12);
            i2cPort = hardware.i2c12;
        }
        else if(port == I2C_89)
        {
            // Configure I2C bus on pins 8 & 9
            hardware.configure(I2C_89);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port specified.");
        }
 
        i2cAddress = address << 1;
 
        // Configure device for single shot, no alarms
        write(0x09, 0xD5);
 
        // Set default conversion rate (1Hz)
        setRate(conversionRate);
    }
 
    // Read a byte
    function read(register)
    {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if(data == null)
        {
            server.log("I2C Read Failure");
            return -1;
        }
 
        return data[0];
    }
 
    // Write a byte
    function write(register, data)
    {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }
 
    // Set continuous conversion rate, 0 = 0.06Hz, 4 = 1Hz, 9 = 32Hz
    function setRate(rate)
    {
        if(rate >= 0 && rate <= 9)
        {
            write(0x0a, rate);
            conversionRate = rate;
        }
        else
        {
            write(0x0a, 0x04);
            conversionRate = 0x04;
            server.log("Invalid conversion rate, using default 1Hz");
        }
 
    }
 
    // Stop continuous conversion
    function stop()
    {
        write(0x09, 0xD5);
    }
 
    // Start conversion, continuous or single shot
    function start(continuous)
    {
        if(continuous == true)
        {
            write(0x09, 0x55);
        }
        else
        {
            write(0x0f, 0x00);
        }
    }
 
    // Check if conversion is completed
    function isReady()
    {        
        return (read(0x02) & 0x80)?false:true;
    }
 
    // Retrieve temperature (from local sensor) in deg C
    function getTemperature()
    {
        // Get 11-bit signed temperature value in 0.125C steps
        local temp = (read(0x00) << 3) | (read(0x22) >> 5);
 
        if(temp & 0x400)
        {
            // Negative two's complement value
            return -((~temp & 0x7FF) + 1) / 8.0;
        }
        else
        {
            // Positive value
            return temp / 8.0;
        }
    }
}
 
// Instantiate the sensor
local sensor = TemperatureSensor(I2C_89, 0x4c);
 
// Capture and log a temperature reading every 5s
function capture()
{
    // Set timer for the next capture
    imp.wakeup(30.0, capture);
 
    // Start a single shot conversion
    sensor.start(false);
 
    // Wait for conversion to complete
    while(!sensor.isReady()) imp.sleep(0.05);
 
    // Output the temperature
    local temp = sensor.getTemperature();
    server.log(format("%3.1fC", temp));
}
 
// Start capturing temperature
capture();