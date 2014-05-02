// Class for DHT11 Temp/Humidity Sensor

const SPICLK = 937.5;

// Class to read the DHT11 temperature/humidity sensor
// See http://akizukidenshi.com/download/ds/aosong/DHT11.pdf
// These sensors us a proprietary one-wire protocol. The imp
// emulates this protocol with SPI. 
// To use:
//  - tie MOSI to MISO with a 10k resistor
//  - tie MISO to the data line on the sensor
class DHT11 {
    static STARTTIME_LOW     = 0.001000;    // 1 ms low time for start
    static STARTTIME_HIGH    = 0.000020;  // 20 us min high time for start
    static STARTTIME_SENSOR  = 0.000080;  // 80 us low / 80 us high "ACK" from sensor on START
    static MARKTIME          = 0.000050;  // 50 us low pulse between 0 or 1 marks
    static ZERO              = 0.000026; // 26 us high for "0"
    static ONE               = 0.000075;  // 70 us high for "1"
    
    spi                 = null;
    clkspeed            = null;
    bittime             = null;
    bytetime            = null;
    start_low_bits      = null;
    start_low_bytes     = null;
    start_high_bits     = null;
    start_high_bytes    = null;
    start_ack_bits      = null;
    start_ack_bytes     = null;
    mark_bits           = null;
    mark_bytes          = null;
    zero_bits           = null;
    zero_bytes          = null;
    one_bits            = null;
    one_bytes           = null;
    
    // class constructor
    // Input: 
    //      _spi: a pre-configured SPI peripheral (e.g. spi257)
    //      _clkspeed: the speed the SPI has been configured to run at
    // Return: (None)
    constructor(_spi, _clkspeed) {
        this.spi = _spi;
        this.clkspeed = _clkspeed;
    
        bittime     = 1.0 / (clkspeed * 1000);
        bytetime    = 8.0 * bittime;
        
        start_low_bits      = STARTTIME_LOW / bittime;
        start_low_bytes     = (start_low_bits / 8);
        start_high_bits     = STARTTIME_HIGH / bittime;
        start_high_bytes    = (start_high_bits / 8);
        start_ack_bits      = STARTTIME_SENSOR / bittime;
        start_ack_bytes     = (start_ack_bits / 8);
        mark_bits           = MARKTIME / bittime;
        mark_bytes          = (mark_bits / 8);
        zero_bits           = ZERO / bittime;
        zero_bytes          = (zero_bits / 8);
        one_bits            = ONE / bittime;
        one_bytes           = (one_bits / 8);
    }
    
    // helper function
    // given a long blob, find times between transitions and parse to 
    // temp and humidity values. Assumes 40-bit return value (16 humidity / 16 temp / 8 checksum)
    // Input: 
    //      hexblob (blob of arbitrary length)
    // Return: 
    //      table containing:
    //          "rh": relative humidity (float)
    //          "temp": temperature in celsius (float)
    //      if read fails, rh and temp will return 0
    function parse(hexblob) {
        local laststate     = 0;
        local lastbitidx    = 0;
        
        local gotack        = false;
        local rawidx        = 0;
        local result        = blob(5); // 2-byte humidity, 2-byte temp, 1-byte checksum
    
        local humid         = 0;
        local temp          = 0;
        
        // iterate through each bit of each byte of the returned signal
        for (local byte = 0; byte < hexblob.len(); byte++) {
            for (local bit = 7; bit >= 0; bit--) {
                
                local thisbit = (hexblob[byte] & (0x01 << bit)) ? 1:0;
                
                if (thisbit != laststate) {
                    if (thisbit) {
                        // low-to-high transition; watch to see how long it is high
                        laststate = 1;
                        lastbitidx = (8 * byte) + (7 - bit);
                    } else {
                        // high-to-low transition;
                        laststate = 0;
                        local idx = (8 * byte) + (7 - bit);
                        local hightime = (idx - lastbitidx) * bittime;
                        
                        // we now have one valid bit of info. Figure out what symbol it is.
                        local resultbyte = (rawidx / 8);
                        local resultbit =  7 - (rawidx % 8);
                        //server.log(format("bit %d of byte %d",resultbit, resultbyte));
                        if (hightime < ZERO) {
                            // this is a zero
                            if (gotack) {
                                // don't record any data before the ACK is seen
                                result[resultbyte] = result[resultbyte] & ~(0x01 << resultbit);
                                rawidx++;
                            }
                        } else if (hightime < ONE) {
                            // this is a one
                            if (gotack) {
                                result[resultbyte] = result[resultbyte] | (0x01 << resultbit);
                                rawidx++;
                            }
                        } else {
                            // this is a START ACK
                            gotack = true;
                        }
                    }
                }
            }
        }
        
        //server.log(format("parsed: 0x %02x%02x %02x%02x %02x",result[0],result[1],result[2],result[3],result[4]));
        humid = (result[0] * 1.0) + (result[1] / 1000.0);
        if (result[2] & 0x80) {
            // negative temperature
            result[2] = ((~result[2]) + 1) & 0xff;
        }
        temp = (result[2] * 1.0) + (result[3] / 1000.0);
        if (((result[0] + result[1] + result[2] + result[3]) & 0xff) != result[4]) {
            return {"rh":0,"temp":0};
        } else {
            return {"rh":humid,"temp":temp};
        }
    }
    
    // read the sensor
    // Input: (none)
    // Return:
    //      table containing:
    //          "rh": relative humidity (float)
    //          "temp": temperature in celsius (float)
    //      if read fails, rh and temp will return 0
    function read() {
        local bloblen = start_low_bytes + start_high_bytes + (40 * (mark_bytes + one_bytes));
        local startblob = blob(bloblen);
        for (local i = 0; i < start_low_bytes; i++) {
            startblob.writen(0x00,'b');
        }
        for (local j = start_low_bytes; j < bloblen; j++) {
            startblob.writen(0xff,'b');
        }
        
        //server.log(format("Sending %d bytes", startblob.len()));
        local result = spi.writeread(startblob);
        return parse(result);
    }
}

spi         <- hardware.spi257;
clkspeed    <- spi.configure(MSB_FIRST, SPICLK);

dht11 <- DHT11(spi, clkspeed);
data <- dht11.read();
server.log(format("Relative Humidity: %0.1f",data.rh)+" %");
server.log(format("Temperature: %0.1f C",data.temp));
