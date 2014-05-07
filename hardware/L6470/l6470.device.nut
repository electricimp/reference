// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf

// Consts and Globals ---------------------------------------------------------
const SPICLK = 4000; // kHz
const STEPS_PER_REV = 48; // using sparkfun's small stepper motor


// The following constants are all associated with the L6470 class
// these are consts outside the class so that we can use them in motor configuration
// and for performance reasons
const CONFIG_PWMDIV_1      = 0x0000;
const CONFIG_PWMDIV_2      = 0x2000;
const CONFIG_PWMDIV_3      = 0x4000;
const CONFIG_PWMDIV_4      = 0x5000;
const CONFIG_PWMDIV_5      = 0x8000;
const CONFIG_PWMDIV_6      = 0xA000;
const CONFIG_PWMDIV_7      = 0xC000;
const CONFIG_PWMMULT_0_625 = 0x0000;
const CONFIG_PWMMULT_0_750 = 0x0400;
const CONFIG_PWMMULT_0_875 = 0x0800;
const CONFIG_PWMMULT_1_000 = 0x0C00;
const CONFIG_PWMMULT_1_250 = 0x1000;
const CONFIG_PWMMULT_1_500 = 0x1400;
const CONFIG_PWMMULT_1_750 = 0x1800;
const CONFIG_PWMMULT_2_000 = 0x1C00;
const CONFIG_SR_320        = 0x0000;
const CONFIG_SR_75         = 0x0100;
const CONFIG_SR_110        = 0x0200;
const CONFIG_SR_260        = 0x0300;
const CONFIG_INT_OSC       = 0x0000;
const CONFIG_OC_SD         = 0x0080;
const CONFIG_VSCOMP        = 0x0020;
const CONFIG_SW_USER       = 0x0010;
const CONFIG_EXT_CLK       = 0x0008;

const STEP_MODE_SYNC    = 0x80;
const STEP_SEL_FULL     = 0x00;
const STEP_SEL_HALF     = 0x01;
const STEP_SEL_1_4      = 0x02;
const STEP_SEL_1_8      = 0x03;
const STEP_SEL_1_16     = 0x04;
const STEP_SEL_1_32     = 0x05;
const STEP_SEL_1_64     = 0x06;
const STEP_SEL_1_128    = 0x06;

const CMD_NOP		 	= 0x00;
const CMD_GOHOME		= 0x70;
const CMD_GOMARK		= 0x78;
const CMD_GOTO          = 0x60;
const CMD_GOTO_DIR      = 0x68;
const CMD_RESET_POS	    = 0xD8;
const CMD_RESET		    = 0xC0;
const CMD_RUN           = 0x50;
const CMD_SOFT_STOP	    = 0xB0;
const CMD_HARD_STOP	    = 0xB8;
const CMD_SOFT_HIZ		= 0xA0;
const CMD_HARD_HIZ		= 0xA8;
const CMD_GETSTATUS	    = 0xD0;	 
const CMD_GETPARAM      = 0x20;
const CMD_SETPARAM      = 0x00;

const REG_ABS_POS 		= 0x01;
const REG_EL_POS 		= 0x02;
const REG_MARK			= 0x03;
const REG_SPEED		    = 0x04;
const REG_ACC			= 0x05;
const REG_DEC			= 0x06;
const REG_MAX_SPD 		= 0x07;
const REG_MIN_SPD 		= 0x08;
const REG_KVAL_HOLD 	= 0x09;
const REG_KVAL_RUN 	    = 0x0A;
const REG_KVAL_ACC 	    = 0x0B;
const REG_KVAL_DEC 	    = 0x0C;
const REG_INT_SPD		= 0x0D;
const REG_ST_SLP		= 0x0E;
const REG_FN_SLP_ACC	= 0x0F;
const REG_FN_SLP_DEC	= 0x10;
const REG_K_THERM		= 0x11;
const REG_ADC_OUT		= 0x12;
const REG_OCD_TH		= 0x13;
const REG_STALL_TH		= 0x13;
const REG_STEP_MODE	    = 0x14;
const REG_FS_SPD		= 0x15;
const REG_STEP_MODE 	= 0x16;
const REG_ALARM_EN		= 0x17;
const REG_CONFIG 		= 0x18;
const REG_STATUS 		= 0x19;

class L6470 {
	spi 	= null;
	cs_l 	= null;
	rst_l 	= null;
	flag_l	= null;
	
	// full-step speed
	fs_speed = null;

    // defined before constructor because this function is used as a callback for the flag pin
	function handleFlag() {
		if (!flag_l.read()) { server.log("L6470 set flag"); }
		else { server.log("L6470 unset flag"); }
        server.log(format("Status Register: 0x%04x", getStatus()));
	}

	constructor(_spi, _cs_l, _rst_l, _flag_l) {
		this.spi 	= _spi;
		this.cs_l 	= _cs_l;
		this.rst_l 	= _rst_l;
		this.flag_l = _flag_l;

		cs_l.write(1);
		rst_l.write(1);
		// re-configure pin to assign callback
		flag_l.configure(DIGITAL_IN, handleFlag.bindenv(this));
	
		reset();
	}

	function reset() {
		rst_l.write(0);
		imp.sleep(0.001);
		rst_l.write(1);
		
		// device comes out of reset with overcurrent bit set in status register
        // read the register to clear the bit.
        getStatus();
	}
	
	// helper function: read up to four bytes from the device
	// no registers in the L6470 are more than four bytes wide
	// returns an integer
	function read(num_bytes) {
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        cs_l.write(0);
	        result += ((spi.writeread(format("%c",CMD_NOP))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        cs_l.write(1);
	    }
	    return result;
	}
	
	// helper function: write an arbitrary length value to the device
	// Input: data as a string. Use format("%c",byte) to prepare to write with this function
	// Returns an string containing the data read back as this data is written out
	function write(data) {
	    local num_bytes = data.len();
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        cs_l.write(0);
	        result += ((spi.writeread(format("%c",data[i]))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        cs_l.write(1);
	    }
	    return result;
	}
	
	// read the L6470 status register
	// Input: None
	// Return: 2-byte status register value (integer)
	function getStatus() {
		write(format("%c",CMD_GETSTATUS));
		return read(2);
	}
	
	// write the L6470 config register
	// Input: new 2-byte value (integer)
	// Return: None
	function setConfig(val) {
	    write(format("%c", CMD_SETPARAM | REG_CONFIG));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the L6470 config register
	// Input: None
	// Return: 2-byte config register value (integer)
	function getConfig() {
	    write(format("%c",CMD_GETPARAM | REG_CONFIG));
		return read(2);
	}
	
	// configure the microstepping mode
	// OR STEP_MODE consts together to generate new value
	// Input: New (1-byte) step mode (integer)
	// Return: None
	function setStepMode(val) {
	    write(format("%c", CMD_SETPARAM | REG_STEP_MODE));
	    write(format("%c", (val & 0xff)));
	}
	
	// read the current microstepping mode
	// Input: None
	// Return: 1-byte step mode register value (integer)
	function getStepMode() {
	    write(format("%c",CMD_GETPARAM | REG_STEP_MODE));
		return read(1);
	}
	
	// set the minimum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// device comes out of reset with min speed set to zero
	// Input: new min speed in steps per second (integer)
	// Return: None
	function setMinSpeed(stepsPerSec) {
	    local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    write(format("%c", CMD_SETPARAM | REG_MIN_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	
	// read the current minimum speed setting
	// Input: None
	// Return: Min speed in steps per second (integer)
	function getMinSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_MIN_SPD));
		local minspeed = read(2);
		minspeed = math.ceil((1.0 * minspeed) / 0.065536);
		return minspeed;
	}
	
	// set the maximum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// Input: new max speed in steps per second (integer)
	// Return: None
	function setMaxSpeed(stepsPerSec) {
	    local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    write(format("%c", CMD_SETPARAM | REG_MAX_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current maximum speed setting
	// Input: None
	// Return: Max speed in steps per second (integer)
	function getMaxSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_MAX_SPD));
		local maxspeed = read(2);
		maxspeed = math.ceil((1.0 * maxspeed) / 0.065536);
		return maxspeed;
	}
	
	// set the full-step motor speed in steps per second
	// Input: new full-step speed in steps per second (integer)
	// Return: None
	function setFSSpeed(stepsPerSec) {
	    local val = math.ceil((stepsPerSec * 0.065536) - 0.5).tointeger();
	    if (val > 0x03FF) { val = 0x03FF; }
	    fs_speed = val;
	    write(format("%c", CMD_SETPARAM | REG_FS_SPD));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current full-step speed setting
	// Input: None
	// Return: full-step speed in steps per second (integer)
	function getFSSpeed() {
	    write(format("%c",CMD_GETPARAM | REG_FS_SPD));
		local fsspeed = read(2);
		fsspeed = math.ceil((1.0 * fsspeed) / 0.065536);
		return fsspeed;
	}
	
	// set max acceleration in steps/sec^2
	// Input: integer
	// Return: None.
	function setAcc(stepsPerSecPerSec) {
	    local val = math.ceil(stepsPerSecPerSec * 0.137438).tointeger();
        if (val > 0x0FFF) { val = 0x0FFF; }
	    write(format("%c", CMD_SETPARAM | REG_ACC));
	    write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// set overcurrent threshold value
	// thresholds are set at 375 mA intervals from 375 mA to 6A
	// Input: threshold in mA (integer)
	// Return: None
	function setOcTh(threshold) {
	    local val = math.floor(threshold / 375).tointeger();
        if (val > 0x0f) { val = 0x0f; }
	    write(format("%c", CMD_SETPARAM | REG_OCD_TH));
	    write(format("%c", (val & 0xff)));
	}
	
	// Set Vs compensation factor for hold state
	// Input: new 1-byte compensation factor (integer)
	// Return: None
	function setHoldKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_HOLD));
	    write(format("%c", (val & 0xff)));
	}
	
	// Get Vs compensation factor for hold state
	// Input: None
	// Return: 1-byte value (integer)
	function getHoldKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_HOLD));
	    write(format("%c", (val & 0xff)));
	}
	
	// Set Vs compensation factor for run state
	// Input: new 1-byte compensation factor (integer)
	// Return: None
	function setRunKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_RUN));
	    write(format("%c", (val & 0xff)));
	}
	
	// Get Vs compensation factor for run state
	// Input: None
	// Return: 1-byte value (integer)	
	function getRunKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_RUN));
	    write(format("%c", (val & 0xff)));
	}
	
	// Set Vs compensation factor for acceleration state
	// Input: new 1-byte compensation factor (integer)
	// Return: None	
	function setAccKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_ACC));
	    write(format("%c", (val & 0xff)));
	}
	
	// Get Vs compensation factor for acceleration state
	// Input: None
	// Return: 1-byte value (integer)
	function getAccKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_ACC));
	    write(format("%c", (val & 0xff)));
	}	

	// Set Vs compensation factor for deceleration state
	// Input: new 1-byte compensation factor (integer)
	// Return: None	
	function setDecKval(val) {
	    write(format("%c", CMD_SETPARAM | REG_KVAL_DEC));
	    write(format("%c", (val & 0xff)));
	}
	
	// Get Vs compensation factor for deceleration state
	// Input: None
	// Return: 1-byte value (integer)
	function getDecKval() {
	    write(format("%c", CMD_GETPARAM | REG_KVAL_DEC));
	    write(format("%c", (val & 0xff)));
	}
	
	// Set current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: 22-bit absolute position counter value (integer)
	// Return: None
	function setAbsPos(pos) {
        write(format("%c%c%c%c", CMD_SETPARAM | REG_ABS_POS, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: None
	// Return: 22-bit value (integer)
	function getAbsPos() {
	    write(format("%c", CMD_GETPARAM | REG_ABS_POS));
	    return read(3);
	}
	
	// Set current motor electrical position 
	// Motor will immediately move to this electrical position
	// Electrical position is a 9-bit value
	// Bits 8 and 7 indicate the current step
	// Bits 6:0 indicate the current microstep
	// Input: new electrical position value (integer)
	// Return: None
	function setElPos(pos) {
        write(format("%c%c%c", CMD_SETPARAM | REG_EL_POS, (pos & 0x0100) >> 8, pos & 0xff));
	}
	
	// Get current motor electrical position 
	// Input: None
	// Return: current 9-bit electrical position value (integer)
	function getElPos() {
	    write(format("%c", CMD_GETPARAM | REG_EL_POS));
	    return read(2);
	}
	
	// Set the absolute position mark register
	// Mark is a 22-bit value
	// Units match the current step unit (full, half, quarter, etc.)
	// Values range from -2^21 to (2^21) - 1 in microsteps
	// Input: New 22-bit position mark value (integer)
	// Return: None
	function setMark(pos) {
        write(format("%c%c%c%c", CMD_SETPARAM | REG_MARK, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get the absolute position mark register
	// Input: None
	// Return: 22-bit position mark value (integer)
	function getMark() {
	    write(format("%c", CMD_GETPARAM | REG_MARK));
	    return read(3);
	}

    // Immediately disable the power bridges and set the coil outputs to high-impedance state
    // This will raise the HiZ flag, if enabled
    // This command holds the BUSY line low until the motor is stopped
    // Input: None
    // Return: None
	function hardHiZ() {
	    write(format("%c", CMD_HARD_HIZ));
	}
	
	// Decelerate the motor to zero, then disable the power bridges and set the 
	// coil outputs to high-impedance state
	// The HiZ flag will be raised when the motor is stopped
	// This command holds the BUSY line low until the motor is stopped
	// Input: None
	// Return: None
	function softHiZ() {
	    write(format("%c", CMD_SOFT_HIZ));
	}
	
    // Move the motor immediately to the HOME position (zero position marker)
    // The motor will take the shortest path
    // This is equivalent to using GoTo(0) without a direction
    // If a direction is mandatory, use GoTo and specify a direction
    // Input: None
    // Return: None
	function goHome() {
	    write(format("%c", CMD_GOHOME));
	}
	
	// Move the motor immediately to the MARK position
	// MARK defaults to zero
	// Use setMark to set the mark position register
	// The motor will take the shortest path to the MARK position
	// If a direction is mandatory, use GoTo and specify a direction
	// Input: None
	// Return: None
	function goMark() {
	    write(format("%c", CMD_GOMARK));
	}
	
	// Move the motor num_steps in a direction
	// if fwd = 1, the motor will move forward. If fwd = 0, the motor will step in reverse
	// num_steps is a 22-bit value specifying the number of steps; units match the current step mode.
	// Input: fwd (0 or 1), num_steps (integer)
	// Return: None
	function move(fwd, num_steps) {
	    local cmd = CMD_MOVE;
	    if (fwd) { cmd = CMD_RUN | 0X01; }
	    write(format("%c%c%c%c", cmd, (num_steps & 0xff0000) >> 16, (num_steps & 0xff00) >> 8, num_steps & 0xff));
	}
	
	// Move the motor to a position
	// Position is a 22-bit value. Units match the current step mode.
	// Direction is 1 for forward, 0 for reverse
	// If a direction not provided, the motor will take the shortest path
	// Input: Position (integer), [direction (integer)]
    // Return: None
	function goTo(pos, dir = null) {
	    local cmd = CMD_GOTO;
	    if (dir != null) {
	        if (dir == 0) {
    	        cmd = CMD_GOTO_DIR;
	        } else {
	            cmd = CMD_GOTO_DIR | 0x01;
	        }
	    }
	    write(format("%c%c%c%c", cmd, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Run the motor
	// Direction is 1 for fwd, 0 for reverse
	// Speed is in steps per second. Angular speed will depend on the steps per rotation of your motor
	// Input: [direction (integer)], [speed (integer)]
	// Return: None
	function run(fwd = 1, speed = 0) {
	    local cmd = CMD_RUN;
	    if (fwd) { cmd = CMD_RUN | 0x01; }
	    if (!speed) { speed = fs_speed; }
	    else { 
	        speed = math.ceil((speed * 0.065536) - 0.5).tointeger();
	        if (speed > 0x03FF) { speed = 0x03FF; }
	    }
	    write(format("%c%c%c", cmd, (speed & 0xff00) >> 8, speed & 0xff));
	}
	
	// Soft-stop the motor. This will decelerate the motor smoothly to zero speed.
	// Input: None
	// Return: None
	function stop() {
	    write(format("%c", CMD_SOFT_STOP));
	}
}

// Runtime Begins -------------------------------------------------------------
imp.enableblinkup(true);

spi <- hardware.spi189;
cs_l <- hardware.pin2;
rst_l <- hardware.pin5;
flag_l <- hardware.pin7;

spi.configure(MSB_FIRST, SPICLK);
cs_l.configure(DIGITAL_OUT);
rst_l.configure(DIGITAL_OUT);
flag_l.configure(DIGITAL_IN);

motor <- L6470(spi, cs_l, rst_l, flag_l);

// 1/64 step microstepping
motor.setStepMode(STEP_SEL_1_64); // sync disabled, pwm divisor 1, pwm multiplier 2
// set max speed to 10 revs per second
motor.setMaxSpeed(10 * STEPS_PER_REV); // steps per sec
motor.setFSSpeed(STEPS_PER_REV); // steps per sec
motor.setAcc(0x0fff); // max
motor.setOcTh(6000); // 6A
motor.setConfig(CONFIG_INT_OSC | CONFIG_PWMMULT_2_000);
motor.setRunKval(0xff); // set Vs divisor to 1

server.log(format("Status Register: 0x%04x", motor.getStatus()));
server.log(format("Config Register: 0x%04x", motor.getConfig()));

// run the motor forward at 1 rev/sec for 2.5 seconds
motor.run(1, STEPS_PER_REV);
imp.wakeup(2.5, function() {
    // soft-stop the motor
    motor.stop();
    // Hi-Z the outputs to stop current through the motor
    motor.softHiZ();
    // record the current position 
    motor.setMark(motor.getAbsPos());
    // return to initial position and wait 0.5 seconds
    motor.goHome();
    imp.wakeup(0.5, function() {
        // return to our marked position from earlier via the shortest route
        motor.goTo(motor.getMark());
        // the GoTo command does not block until the motion is complete, 
        // so wait a moment for the motion to finish before stopping the motor
        imp.wakeup(0.2, function() {
            motor.stop();
            motor.softHiZ();
        });
    });
});