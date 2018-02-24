// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf

// Consts and Globals ---------------------------------------------------------
const SPICLK_KHZ = 500; // kHz
const STEPS_PER_REV = 48; // using sparkfun's small stepper motor


// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf
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

const STEP_MODE_SYNC        = 0x80;
const STEP_SEL_FULL         = 0x00;
const STEP_SEL_HALF         = 0x01;
const STEP_SEL_1_4          = 0x02;
const STEP_SEL_1_8          = 0x03;
const STEP_SEL_1_16         = 0x04;
const STEP_SEL_1_32         = 0x05;
const STEP_SEL_1_64         = 0x06;
const STEP_SEL_1_128        = 0x06;

const CMD_NOP		 	          = 0x00;
const CMD_GOHOME		        = 0x70;
const CMD_GOMARK		        = 0x78;
const CMD_GOTO              = 0x60;
const CMD_GOTO_DIR          = 0x68;
const CMD_GOUNTIL           = 0x82;
const CMD_RESET_POS	        = 0xD8;
const CMD_RESET		          = 0xC0;
const CMD_RUN               = 0x50;
const CMD_SOFT_STOP	        = 0xB0;
const CMD_HARD_STOP	        = 0xB8;
const CMD_SOFT_HIZ		      = 0xA0;
const CMD_HARD_HIZ		      = 0xA8;
const CMD_GETSTATUS	        = 0xD0;	 
const CMD_GETPARAM          = 0x20;
const CMD_SETPARAM          = 0x00;

const REG_ABS_POS 		      = 0x01;
const REG_EL_POS 		        = 0x02;
const REG_MARK			        = 0x03;
const REG_SPEED		          = 0x04;
const REG_ACC			          = 0x05;
const REG_DEC			          = 0x06;
const REG_MAX_SPD 		      = 0x07;
const REG_MIN_SPD 		      = 0x08;
const REG_KVAL_HOLD 	      = 0x09;
const REG_KVAL_RUN 	        = 0x0A;
const REG_KVAL_ACC 	        = 0x0B;
const REG_KVAL_DEC 	        = 0x0C;
const REG_INT_SPD	  	      = 0x0D;
const REG_ST_SLP		        = 0x0E;
const REG_FN_SLP_ACC	      = 0x0F;
const REG_FN_SLP_DEC	      = 0x10;
const REG_K_THERM		        = 0x11;
const REG_ADC_OUT		        = 0x12;
const REG_OCD_TH		        = 0x13;
const REG_STALL_TH		      = 0x13;
const REG_STEP_MODE	        = 0x14;
const REG_FS_SPD		        = 0x15;
const REG_STEP_MODE 	      = 0x16;
const REG_ALARM_EN		      = 0x17;
const REG_CONFIG 		        = 0x18;
const REG_STATUS 		        = 0x19;

class L6470 {
  
	_spi 	  = null;
	_cs_l 	= null;
	_rst_l 	= null;
	_flag_l	= null;
	
	constructor(spi, cs_l, rst_l = null, flag_l = null, flag_l_cb = null) {
		this._spi 	  = spi;
		this._cs_l 	  = cs_l;
		this._rst_l 	= rst_l;
		this._flag_l  = flag_l;

		_cs_l.write(1);
		
		// hardware reset line is optional; don't attempt to write if not provided
		if (_rst_l) {
		  _rst_l.write(1);
		}
		
		// If flag pin exists, re-configure to assign callback
		if (flag_l_cb) {
  		_flag_l.configure(DIGITAL_IN, handleFlag.bindenv(this));
		}
		
		reset();
	}
	
	// helper function: read up to four bytes from the device
	// no registers in the L6470 are more than four bytes wide
	// returns an integer
	function _read(num_bytes) {
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        _cs_l.write(0);
	        result += ((spi.writeread(format("%c",CMD_NOP))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        _cs_l.write(1);
	    }
	    return result;
	}
	
	// helper function: write an arbitrary length value to the device
	// Input: data as a string. Use format("%c",byte) to prepare to write with this function
	// Returns an string containing the data read back as this data is written out
	function _write(data) {
	    local num_bytes = data.len();
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        _cs_l.write(0);
	        result += ((spi.writeread(format("%c",data[i]))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        _cs_l.write(1);
	    }
	    return result;
	}
	
	// Use the hardware reset line to reset the controller
	// Blocks for 1 ms while pulsing the reset line
	// If reset line is not provided to constructor, soft Reset is used.
	// Input: None
	// Return: None
	function reset() {
	  if (!_rst_l) {
	    softReset();
	    return;
	  }
	  _rst_l.write(0);
		imp.sleep(0.001);
		_rst_l.write(1);
		imp.sleep(0.001);
		
		// device comes out of reset with overcurrent bit set in status register
    // read the register to clear the bit.
    getStatus();
	}
	
  // Use the reset command to reset the controler
  // Input: None
  // Return: None
	function softReset() {
		_write(format("%c", CMD_RESET));
		
		// device comes out of reset with overcurrent bit set in status register
    // read the register to clear the bit.
    getStatus();
	}
	
	// read the L6470 status register
	// Input: None
	// Return: 2-byte status register value (integer)
	function getStatus() {
		_write(format("%c", CMD_GETSTATUS));
		return _read(2);
	}
	
	// read the state of the BUSY bit in the L6470 status register
	// Input: None
	// Return: 1 if busy, 0 otherwise.
	function isBusy() {
	  if (getStatus() & 0x0002) { return 0; }
	  return 1;
	}
	
	// write the L6470 config register
	// Input: new 2-byte value (integer)
	// Return: None
	function setConfig(val) {
	  _write(format("%c", CMD_SETPARAM | REG_CONFIG));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the L6470 config register
	// Input: None
	// Return: 2-byte config register value (integer)
	function getConfig() {
	  _write(format("%c", CMD_GETPARAM | REG_CONFIG));
		return _read(2);
	}
	
	// configure the microstepping mode
	// OR STEP_MODE consts together to generate new value
	// Input: New (1-byte) step mode (integer)
	// Return: None
	function setStepMode(val) {
	  _write(format("%c", CMD_SETPARAM | REG_STEP_MODE));
	  _write(format("%c", (val & 0xff)));
	}
	
	// read the current microstepping mode
	// Input: None
	// Return: step divisor (1, 2, 4, 8, 16, 32, 64, or 128), or 0 for Sync mode. Returns -1 on error.
	function getStepMode() {
	  _write(format("%c", CMD_GETPARAM | REG_STEP_MODE));
	  local mode = _read(1);
	  switch (mode) {
	    case STEP_MODE_SYNC:
	      return 0;
	    case STEP_SEL_FULL:
	      return 1;
	    case STEP_SEL_HALF:
	      return 2;
	    case STEP_SEL_1_4:
	      return 4;
	    case STEP_SEL_1_8:
	      return 8;
	    case STEP_SEL_1_16:
	      return 16;
	    case STEP_SEL_1_32:
	      return 32;
	    case STEP_SEL_1_64:
	      return 64;
	    case STEP_SEL_1_128:
	      return 128;
	    default:
	      return -1;
	  }
	}
	
	// set the minimum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// device comes out of reset with min speed set to zero
	// Input: new min speed in steps per second (integer)
	// Return: None
	function setMinSpeed(stepsPerSec) {
	  // min speed (steps/s) = (MIN_SPEED * 2^-24 / tick (250 ns))
	  local val = math.ceil(stepsPerSec * 4.194304).tointeger();
	  if (val > 0x1FFF) { val = 0x1FFF; }
	  _write(format("%c", CMD_SETPARAM | REG_MIN_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	
	// read the current minimum speed setting
	// Input: None
	// Return: Min speed in steps per second (integer)
	function getMinSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
		local minspeed = _read(2) & 0x1FFF;
		minspeed = math.ceil((1.0 * minspeed) / 4.194304);
		return minspeed;
	}
	
	// set the maximum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// Note that resolution is 15.25 steps/s
	// Input: new max speed in steps per second (integer)
	// Return: None
	function setMaxSpeed(stepsPerSec) {
	  // max speed (steps/s) = (MAX_SPEED * 2^-28 / tick (250ns))
	  local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	  if (val > 0x03FF) { val = 0x03FF; }
	  _write(format("%c", CMD_SETPARAM | REG_MAX_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current maximum speed setting
	// Input: None
	// Return: Max speed in steps per second (integer)
	function getMaxSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_MAX_SPD));
		local maxspeed = _read(2) & 0x03FF;
		maxspeed = math.ceil((1.0 * maxspeed) / 0.065536);
		return maxspeed;
	}
	
	// set the full-step motor speed in steps per second
	// Input: new full-step speed in steps per second (integer)
	// Return: None
	function setFSSpeed(stepsPerSec) {
	  // fs_speed (steps/s) = ((FS_SPD + 0.5) * 2^-18) / tick (250ns))
	  local val = math.ceil((stepsPerSec * 0.065536) - 0.5).tointeger();
	  if (val > 0x03FF) { val = 0x03FF; }
	  _write(format("%c", CMD_SETPARAM | REG_FS_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current full-step speed setting
	// Input: None
	// Return: full-step speed in steps per second (integer)
	function getFSSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_FS_SPD));
		local fsspeed = _read(2) & 0x03FF;
		fsspeed = math.ceil(((1.0 * fsspeed) / 0.065536) + 7.629395);
		return fsspeed;
	}
	
	// set max acceleration in steps/sec^2
	// Input: integer
	// Return: None.
	function setAcc(stepsPerSecPerSec) {
	  local val = math.ceil(stepsPerSecPerSec * 0.137438).tointeger();
    if (val > 0x0FFF) { val = 0x0FFF; }
	  _write(format("%c", CMD_SETPARAM | REG_ACC));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// set overcurrent threshold value
	// thresholds are set at 375 mA intervals from 375 mA to 6A
	// Input: threshold in mA (integer)
	// Return: None
	function setOcTh(threshold) {
	  local val = math.floor(threshold / 375).tointeger();
    if (val > 0x0f) { val = 0x0f; }
	  _write(format("%c", CMD_SETPARAM | REG_OCD_TH));
	  _write(format("%c", (val & 0xff)));
	}
	
	// Set Supply Voltage Multiplier for hold state
	// Controller will apply a sinusoidal voltage of magnitude up to Vsupply * KVal
	// to the motor. 
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None
	function setHoldKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_HOLD));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for hold state
	// Input: None
	// Return: current hold-state supply voltage multiplier (0 to 1, float)
	function getHoldKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_HOLD));
	  return _read(1) / 256.0;
	}
	
	// Set Supply Voltage Multiplier for run state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None
	function setRunKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_RUN));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for run state
	// Input: None
	// Return: current run-state supply voltage multiplier (0 to 1, float)
	function getRunKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_RUN));
	  return _read(1) / 256.0;
	}
	
	// Set Supply Voltage Multiplier for acceleration state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None	
	function setAccKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_ACC));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for acceleration state
	// Input: None
	// Return: current accel-state supply voltage multiplier (0 to 1, float)
	function getAccKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_ACC));
	  return _read(1) / 256.0;
	}	

	// Set Supply Voltage Multiplier for deceleration state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None	
	function setDecKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_DEC));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for deceleration state
	// Input: None
	// Return: current accel-state supply voltage multiplier (0 to 1, float)
	function getDecKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_DEC));
	  return _read(1) / 256.0;
	}
	
	// Enable or Disable Low-speed position optimization. 
	// This feature reduces phase current crossover distortion and improves position tracking at low speed
	// See datasheet section 7.3
	// When enabled, min speed is forced to zero.
	// Input: bool 
	// Return: None
	function setLspdPosOpt(en) {
	  if (en) {
	    en = 1;
	  } else {
	    en = 0;
	  }
	  local mask = en << 12;
	  server.log(format("0x%02X", mask));
	  // get the MIN_SPEED reg contents and mask the LSPD_OPT bit in
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
	  local data = ((_read(2) & 0x1fff) & ~mask) | mask;
	  server.log(format("0x%X", data));
    _write(format("%c%c%c", CMD_SETPARAM | REG_MIN_SPD, (data & 0x1f00 >> 8), data & 0xff));
	}
	
	// Determine whether low-speed position optimization is enabled. 
	// Input: None
	// Return: 1 if enabled, 0 otherwise
	function getLspdPosOpt() {
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
	  local mask = 1 << 12;
	  local data = _read(2);
	  server.log(format("0x%X", data));
	  return (data & 0x1fff) & mask;
	}
	
	// Set current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: 22-bit absolute position counter value (integer)
	// Return: None
	function setAbsPos(pos) {
    _write(format("%c%c%c%c", CMD_SETPARAM | REG_ABS_POS, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: None
	// Return: 22-bit value (integer)
	function getAbsPos() {
	  _write(format("%c", CMD_GETPARAM | REG_ABS_POS));
	  return _read(3);
	}
	
	// Set current motor electrical position 
	// Motor will immediately move to this electrical position
	// Electrical position is a 9-bit value
	// Bits 8 and 7 indicate the current step
	// Bits 6:0 indicate the current microstep
	// Input: new electrical position value (integer)
	// Return: None
	function setElPos(pos) {
    _write(format("%c%c%c", CMD_SETPARAM | REG_EL_POS, (pos & 0x0100) >> 8, pos & 0xff));
	}
	
	// Get current motor electrical position 
	// Input: None
	// Return: current 9-bit electrical position value (integer)
	function getElPos() {
	  _write(format("%c", CMD_GETPARAM | REG_EL_POS));
	  return _read(2);
	}
	
	// Set the absolute position mark register
	// Mark is a 22-bit value
	// Units match the current step unit (full, half, quarter, etc.)
	// Values range from -2^21 to (2^21) - 1 in microsteps
	// Input: New 22-bit position mark value (integer)
	// Return: None
	function setMark(pos) {
    _write(format("%c%c%c%c", CMD_SETPARAM | REG_MARK, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get the absolute position mark register
	// Input: None
	// Return: 22-bit position mark value (integer)
	function getMark() {
	  _write(format("%c", CMD_GETPARAM | REG_MARK));
	  return _read(3);
	}

    // Immediately disable the power bridges and set the coil outputs to high-impedance state
    // This will raise the HiZ flag, if enabled
    // This command holds the BUSY line low until the motor is stopped
    // Input: None
    // Return: None
	function hardHiZ() {
	  _write(format("%c", CMD_HARD_HIZ));
	}
	
	// Decelerate the motor to zero, then disable the power bridges and set the 
	// coil outputs to high-impedance state
	// The HiZ flag will be raised when the motor is stopped
	// This command holds the BUSY line low until the motor is stopped
	// Input: None
	// Return: None
	function softHiZ() {
	  _write(format("%c", CMD_SOFT_HIZ));
	}
	
    // Move the motor immediately to the HOME position (zero position marker)
    // The motor will take the shortest path
    // This is equivalent to using GoTo(0) without a direction
    // If a direction is mandatory, use GoTo and specify a direction
    // Input: None
    // Return: None
	function goHome() {
	  _write(format("%c", CMD_GOHOME));
	}
	
	// Move the motor immediately to the MARK position
	// MARK defaults to zero
	// Use setMark to set the mark position register
	// The motor will take the shortest path to the MARK position
	// If a direction is mandatory, use GoTo and specify a direction
	// Input: None
	// Return: None
	function goMark() {
	  _write(format("%c", CMD_GOMARK));
	}
	
	// Move the motor num_steps in a direction
	// if fwd = 1, the motor will move forward. If fwd = 0, the motor will step in reverse
	// num_steps is a 22-bit value specifying the number of steps; units match the current step mode.
	// Input: fwd (0 or 1), num_steps (integer)
	// Return: None
	function move(fwd, num_steps) {
	  local cmd = CMD_MOVE;
	  if (fwd) { cmd = CMD_RUN | 0X01; }
	  _write(format("%c%c%c%c", cmd, (num_steps & 0xff0000) >> 16, (num_steps & 0xff00) >> 8, num_steps & 0xff));
	}
	
	// Move the motor to a position
	// Position is in steps and may be floating-point. 
	// Class will convert this to a 22-bit value in the same units as the current stepping value.
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
	  local step_mode = getStepMode();
	  if (step_mode < 1) { step_mode = 1; }
	  local pos_counts = (pos * step_mode).tointeger();
	  // get the current step 
    _write(format("%c%c%c%c", cmd, (pos_counts & 0x3f0000) >> 16, (pos_counts & 0xff00) >> 8, pos_counts & 0xff));
	}
	
	// Move the motor until the controller's switch line is pulled low
	// This automates setting the home position with a limit switch or hall sensor!
	// If the SW_MODE bit in the config reg is '0', the motor will hard-stop. 
	// If SW_MODE is '1', the motor will decelerate. 
	// When the motor is stopped, 
	// Input: 
	//  fwd (bool) - if true, run forward to the switch.
  //  speed (steps per second, integer) - defaults to max speed.
	//  set_mark_reg (bool) - if true, ABS_POS will be preserved and copied to the MARK register. Otherwise, ABS_POS will be zeroed.
	// Return: None
	function goUntil(fwd = 1, speed = null, set_mark_reg = 0) {
	  //server.log("running at speed = "+speed);
	  local cmd = CMD_GOUNTIL;
	  if (set_mark_reg) { cmd = cmd | 0x04; }
	  if (fwd) { cmd = cmd | 0x01; }
	  
	  // default to max speed (15650 steps/s)
	  local spd = 0x0fffff;
	  if (speed != null) {
	    // speed (steps/s) = SPEED * 2^-28/tick (250ns). Speed field is 20 bits.
	    spd = math.ceil(67.108864 * speed).tointeger();
	  }
	  
	  local spd_byte2 = (spd >> 16) & 0x0f;
	  local spd_byte1 = (spd >> 8) & 0xff;
	  local spd_byte0 = spd & 0xff;
	  //server.log(format("0x %02X %02X %02X %02X", cmd, spd_byte2, spd_byte1, spd_byte0));
	  _write(format("%c%c%c%c", cmd, spd_byte2, spd_byte1, spd_byte0));
	}
	
	// Run the motor
	// Direction is 1 for fwd, 0 for reverse
	// Speed is in steps per second. Angular speed will depend on the steps per rotation of your motor
	// Input: [direction (integer)], [speed (steps/s)]
	// Return: None
	function run(fwd = 1, speed = null) {
	  local cmd = CMD_RUN;
	  if (fwd) { cmd = CMD_RUN | 0x01; }
	  
	  // default to max speed (15650 steps/s)
	  local spd = 0x0fffff;
	  if (speed != null) {
	    // speed (steps/s) = SPEED * 2^-28/tick (250ns). Speed field is 20 bits.
	    spd = math.ceil(67.108864 * speed).tointeger();
	  }
	  
	  local spd_byte2 = (spd >> 16) & 0x0f;
	  local spd_byte1 = (spd >> 8) & 0xff;
	  local spd_byte0 = spd & 0xff;
    _write(format("%c%c%c", cmd, spd_byte2, spd_byte1, spd_byte0));
	}
	
	// Soft-stop the motor. This will decelerate the motor smoothly to zero speed.
	// Input: None
	// Return: None
	function stop() {
	  _write(format("%c", CMD_SOFT_STOP));
	}
}

// // Runtime Begins -------------------------------------------------------------
// imp.enableblinkup(true);

// spi <- hardware.spi189;
// cs_l <- hardware.pin2;
// rst_l <- hardware.pin5;
// flag_l <- hardware.pin7;

// spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPICLK_KHZ);
// cs_l.configure(DIGITAL_OUT);
// rst_l.configure(DIGITAL_OUT);
// flag_l.configure(DIGITAL_IN);

// motor <- L6470(spi, cs_l, rst_l, flag_l);

// // 1/64 step microstepping
// motor.setStepMode(STEP_SEL_1_64); // sync disabled, pwm divisor 1, pwm multiplier 2
// // set max speed to 10 revs per second
// motor.setMaxSpeed(10 * STEPS_PER_REV); // steps per sec
// motor.setFSSpeed(STEPS_PER_REV); // steps per sec
// motor.setAcc(0x0fff); // max
// motor.setOcTh(6000); // 6A
// motor.setConfig(CONFIG_INT_OSC | CONFIG_PWMMULT_2_000);
// motor.setRunKval(0xff); // set Vs divisor to 1

// server.log(format("Status Register: 0x%04x", motor.getStatus()));
// server.log(format("Config Register: 0x%04x", motor.getConfig()));

// // run the motor forward at 1 rev/sec for 2.5 seconds
// motor.run(1, STEPS_PER_REV);
// imp.wakeup(2.5, function() {
//     // soft-stop the motor
//     motor.stop();
//     // Hi-Z the outputs to stop current through the motor
//     motor.softHiZ();
//     // record the current position 
//     motor.setMark(motor.getAbsPos());
//     // return to initial position and wait 0.5 seconds
//     motor.goHome();
//     imp.wakeup(0.5, function() {
//         // return to our marked position from earlier via the shortest route
//         motor.goTo(motor.getMark());
//         // the GoTo command does not block until the motion is complete, 
//         // so wait a moment for the motion to finish before stopping the motor
//         imp.wakeup(0.2, function() {
//             motor.stop();
//             motor.softHiZ();
//         });
//     });
// });