/* Pin out -
Imp pin -> FT800 pin
      2 -> MISO
      5 -> SCLK
      7 -> MOSI
      8 -> CS
      9 -> PD
*/

const RAM_CMD              = 1081344;
const RAM_DL               = 1048576;
const RAM_G                = 0;
const RAM_PAL              = 1056768;
const RAM_REG              = 1057792;

const FIFO_SIZE            = 4092;

const OPT_CENTER           = 1536;
const OPT_CENTERX          = 512;
const OPT_CENTERY          = 1024;

const FT_GPU_EXTERNAL_OSC  = 0x44;
const FT_GPU_PLL_48M       = 0x62;
const FT_GPU_CORE_RESET    = 0x68;
const FT_GPU_ACTIVE_M      = 0;

/* Definitions used for FT800 co processor command buffer */
const FT_DL_SIZE           = 8192;  //8KB Display List buffer size
const FT_CMD_FIFO_SIZE     = 8192;  //4KB coprocessor Fifo size
const FT_CMD_SIZE          = 4;     //4 byte per coprocessor command of EVE

const REG_ANALOG           = 1058104;
const REG_ANA_COMP         = 1058160;
const REG_CLOCK            = 1057800;
const REG_CMD_DL           = 1058028;
const REG_CMD_READ         = 1058020;
const REG_CMD_WRITE        = 1058024;
const REG_CPURESET         = 1057820;
const REG_CRC              = 1058152;
const REG_CSPREAD          = 1057892;
const REG_CYA0             = 1058000;
const REG_CYA1             = 1058004;
const REG_CYA_TOUCH        = 1058100;
const REG_DATESTAMP        = 1058108;
const REG_DITHER           = 1057884;
const REG_DLSWAP           = 1057872;
const REG_FRAMES           = 1057796;
const REG_FREQUENCY        = 1057804;
const REG_GPIO             = 1057936;
const REG_GPIO_DIR         = 1057932;
const REG_HCYCLE           = 1057832;
const REG_HOFFSET          = 1057836;
const REG_HSIZE            = 1057840;
const REG_HSYNC0           = 1057844;
const REG_HSYNC1           = 1057848;
const REG_ID               = 1057792;
const REG_INT_EN           = 1057948;
const REG_INT_FLAGS        = 1057944;
const REG_INT_MASK         = 1057952;
const REG_MACRO_0          = 1057992;
const REG_MACRO_1          = 1057996;
const REG_OUTBITS          = 1057880;
const REG_PCLK             = 1057900;
const REG_PCLK_POL         = 1057896;
const REG_PLAY             = 1057928;
const REG_PLAYBACK_FORMAT  = 1057972;
const REG_PLAYBACK_FREQ    = 1057968;
const REG_PLAYBACK_LENGTH  = 1057960;
const REG_PLAYBACK_LOOP    = 1057976;
const REG_PLAYBACK_PLAY    = 1057980;
const REG_PLAYBACK_READPTR = 1057964;
const REG_PLAYBACK_START   = 1057956;
const REG_PWM_DUTY         = 1057988;
const REG_PWM_HZ           = 1057984;
const REG_RENDERMODE       = 1057808;
const REG_ROMSUB_SEL       = 1058016;
const REG_ROTATE           = 1057876;
const REG_SNAPSHOT         = 1057816;
const REG_SNAPY            = 1057812;
const REG_SOUND            = 1057924;
const REG_SWIZZLE          = 1057888;
const REG_TAG              = 1057912;
const REG_TAG_X            = 1057904;
const REG_TAG_Y            = 1057908;
const REG_TAP_CRC          = 1057824;
const REG_TAP_MASK         = 1057828;
const REG_TOUCH_ADC_MODE   = 1058036;
const REG_TOUCH_CHARGE     = 1058040;
const REG_TOUCH_DIRECT_XY  = 1058164;
const REG_TOUCH_DIRECT_Z1Z2= 1058168;
const REG_TOUCH_MODE       = 1058032;
const REG_TOUCH_OVERSAMPLE = 1058048;
const REG_TOUCH_RAW_XY     = 1058056;
const REG_TOUCH_RZ         = 1058060;
const REG_TOUCH_RZTHRESH   = 1058052;
const REG_TOUCH_SCREEN_XY  = 1058064;
const REG_TOUCH_SETTLE     = 1058044;
const REG_TOUCH_TAG        = 1058072;
const REG_TOUCH_TAG_XY     = 1058068;
const REG_TOUCH_TRANSFORM_A= 1058076;
const REG_TOUCH_TRANSFORM_B= 1058080;
const REG_TOUCH_TRANSFORM_C= 1058084;
const REG_TOUCH_TRANSFORM_D= 1058088;
const REG_TOUCH_TRANSFORM_E= 1058092;
const REG_TOUCH_TRANSFORM_F= 1058096;
const REG_TRACKER          = 1085440;
const REG_TRIM             = 1058156;
const REG_VCYCLE           = 1057852;
const REG_VOFFSET          = 1057856;
const REG_VOL_PB           = 1057916;
const REG_VOL_SOUND        = 1057920;
const REG_VSIZE            = 1057860;
const REG_VSYNC0           = 1057864;
const REG_VSYNC1           = 1057868;

const DECR                 = 4;
const DECR_WRAP            = 7;
const DISPLAY              = 0;
const DLSWAP_DONE          = 0;
const DLSWAP_FRAME         = 2;
const DLSWAP_LINE          = 1;
const DST_ALPHA            = 3;
const EDGE_STRIP_A         = 7;
const EDGE_STRIP_B         = 8;
const EDGE_STRIP_L         = 6;
const EDGE_STRIP_R         = 5;
const END                  = 0x210000;
const EQUAL                = 5;
const GEQUAL               = 4;
const GREATER              = 3;
const INCR                 = 3;
const INCR_WRAP            = 6;
const INT_CMDEMPTY         = 32;
const INT_CMDFLAG          = 64;
const INT_CONVCOMPLETE     = 128;
const INT_PLAYBACK         = 16;
const INT_SOUND            = 8;
const INT_SWAP             = 1;
const INT_TAG              = 4;
const INT_TOUCH            = 2;
const INVERT               = 5;

const CMDBUF_SIZE          = 4096;
const CMD_APPEND           = 4294967070;
const CMD_BGCOLOR          = 4294967049;
const CMD_BITMAP_TRANSFORM = 4294967073;
const CMD_BUTTON           = 4294967053;
const CMD_CALIBRATE        = 4294967061;
const CMD_CLOCK            = 4294967060;
const CMD_COLDSTART        = 4294967090;
const CMD_CRC              = 4294967043;
const CMD_DIAL             = 4294967085;
const CMD_DLSTART          = 4294967040; // 0xffff ff00
const CMD_EXECUTE          = 4294967047;
const CMD_FGCOLOR          = 4294967050;
const CMD_GAUGE            = 4294967059;
const CMD_GETMATRIX        = 4294967091;
const CMD_GETPOINT         = 4294967048;
const CMD_GETPROPS         = 4294967077;
const CMD_GETPTR           = 4294967075;
const CMD_GRADCOLOR        = 4294967092;
const CMD_GRADIENT         = 4294967051;
const CMD_HAMMERAUX        = 4294967044;
const CMD_IDCT             = 4294967046;
const CMD_INFLATE          = 4294967074;
const CMD_INTERRUPT        = 4294967042;
const CMD_KEYS             = 4294967054;
const CMD_LOADIDENTITY     = 4294967078;
const CMD_LOADIMAGE        = 4294967076; // 0xffff ff24
const CMD_LOGO             = 4294967089; // 0xffff ff31
const CMD_MARCH            = 4294967045;
const CMD_MEMCPY           = 4294967069;
const CMD_MEMCRC           = 4294967064;
const CMD_MEMSET           = 4294967067;
const CMD_MEMWRITE         = 4294967066;
const CMD_MEMZERO          = 4294967068;
const CMD_NUMBER           = 4294967086;
const CMD_PROGRESS         = 4294967055;
const CMD_REGREAD          = 4294967065;
const CMD_ROTATE           = 4294967081;
const CMD_SCALE            = 4294967080;
const CMD_SCREENSAVER      = 4294967087;
const CMD_SCROLLBAR        = 4294967057;
const CMD_SETFONT          = 4294967083;
const CMD_SETMATRIX        = 4294967082;
const CMD_SKETCH           = 4294967088;
const CMD_SLIDER           = 4294967056;
const CMD_SNAPSHOT         = 4294967071;
const CMD_SPINNER          = 4294967062;
const CMD_STOP             = 4294967063;
const CMD_SWAP             = 4294967041;
const CMD_TEXT             = 4294967052;
const CMD_TOGGLE           = 4294967058;
const CMD_TOUCH_TRANSFORM  = 4294967072;
const CMD_TRACK            = 4294967084;
const CMD_TRANSLATE        = 4294967079;

const KEEP                 = 1;
const L1                   = 1;
const L4                   = 2;
const L8                   = 3;
const LEQUAL               = 2;
const LESS                 = 1;
const LINEAR_SAMPLES       = 0;
const LINES                = 3;
const LINE_STRIP           = 4;
const NEAREST              = 0;
const NEVER                = 0;
const NOTEQUAL             = 6;
const ONE                  = 1;
const ONE_MINUS_DST_ALPHA  = 5;
const ONE_MINUS_SRC_ALPHA  = 4;
const OPT_CENTER           = 1536;
const OPT_CENTERX          = 512;
const OPT_CENTERY          = 1024;
const OPT_FLAT             = 256;
const OPT_MONO             = 1;
const OPT_NOBACK           = 4096;
const OPT_NODL             = 2;
const OPT_NOHANDS          = 49152;
const OPT_NOHM             = 16384;
const OPT_NOPOINTER        = 16384;
const OPT_NOSECS           = 32768;
const OPT_NOTICKS          = 8192;
const OPT_RIGHTX           = 2048;
const OPT_SIGNED           = 256;
const PALETTED             = 8;
const FTPOINTS             = 2;
const RECTS                = 9;

const REPEAT               = 1;
const REPLACE              = 2;
const RGB332               = 4;
const RGB565               = 7;
const SRC_ALPHA            = 2;
const TEXT8X8              = 9;
const TEXTVGA              = 10;
const TOUCHMODE_CONTINUOUS = 3;
const TOUCHMODE_FRAME      = 2;
const TOUCHMODE_OFF        = 0;
const TOUCHMODE_ONESHOT    = 1;
const ULAW_SAMPLES         = 1;
const ZERO                 = 0;

const ADC_DIFFERENTIAL     = 1;
const ADC_SINGLE_ENDED     = 0;
const ADPCM_SAMPLES        = 2;
const ALWAYS               = 7;
const ARGB1555             = 0;
const ARGB2                = 5;
const ARGB4                = 6;
const BARGRAPH             = 11;
const BILINEAR             = 1;
const BITMAPS              = 1;
const BORDER               = 0;

// Configurable Screen Settings
const FT_DispWidth         = 480;
const FT_DispHeight        = 272;
const FT_DispHCycle        = 548;
const FT_DispHOffset       = 43;
const FT_DispHSync0        = 0;
const FT_DispHSync1        = 41;
const FT_DispVCycle        = 292;
const FT_DispVOffset       = 12;
const FT_DispVSync0        = 0;
const FT_DispVSync1        = 10;
const FT_DispPCLK          = 5;
const FT_DispSwizzle       = 0;
const FT_DispPCLKPol       = 1;

/*
    function end() {
        return (33<<24);
    }
*/

class ft800 {
    cp_ptr          = 0;
    freespace       = 0;
    debug           = 0;
    
    spi             = null;
    cs_l            = null;
    pd_l            = null;
    int_l           = null;
    
    // callback functions assigned to specific tags
    tag_callbacks   = array(256,null);
    // a general callback to call on any touch
    any_touch_callback = null;
    // flag; if set, clear the any_touch_callback when it is called
    clear_any_touch_callback = null;
    
    /* General FT800 interrupt handler. This is where touch events are detected */
    function int_handler() {
        local touch_pressure = 0;
        local touch_y = 0;
        local touch_x = 0;
        local tag_y = 0;
        local tag_x = 0;
        local tag = 0;
        // interrupt is active-low
        if (this.int_l.read()) {return;}
        local int_byte = gpu_read_mem(REG_INT_FLAGS, 1);
        if (int_byte && 0x02) {
            // The touch engine takes about 25 ms (measured experimentally :/ to load
            // the touch coordinates into the tag registers and find the tag.
            imp.sleep(0.025);
            local data = gpu_read_mem(REG_TOUCH_RZ, 13);
            touch_pressure = ((data[1] << 8) + data[0]);
            touch_y = (data[5] << 8) + data[4];
            touch_x = (data[7] << 8) + data[6];
            tag_y = (data[9] << 8) + data[8];
            tag_x = (data[11] << 8) + data[10];
            tag = data[12];
            
            if (tag_callbacks[tag]) {
                tag_callbacks[tag]();
            } else if (any_touch_callback && touch_pressure < 0x7fff) {
                any_touch_callback();
                if (clear_any_touch_callback) {
                    any_touch_callback = null;
                    clear_any_touch_callback = null;
                }
            }    
        }
        // give a moment for the touch to release (not unlike debouncing a switch!)
        imp.sleep(0.2);
    }
    
    /* Register a callback that is called on any touch event.
     * Input:
     *      callback: function to call
     *      clear: if true, remove the callback the first time it is called
     * Return: (None);
     */
    function on_any_touch(callback, clear) {
        this.any_touch_callback = callback;
        if (clear) {
            this.clear_any_touch_callback = true;
        } else {
            this.clear_any_touch_callback = false;
        }
    }
    
    constructor(_spi, _cs_l, _pd_l, _int_l) {
        this.spi    = _spi;
        this.cs_l   = _cs_l;
        this.pd_l   = _pd_l;
        this.int_l  = _int_l;

        cp_ptr      = 0;
        freespace   = FIFO_SIZE;
        
        this.int_l.configure(DIGITAL_IN, int_handler.bindenv(this));
    }
    
    function clear_color_rgb(red,green,blue) {
        return (0x02<<24)|((red & 0xff)<<16)|((green & 0xff)<<8)|(blue & 0xff);
    }
    function color_rgb(red,green,blue) {
        return (0x04<<24)|((red & 0xff)<<16)|((green & 0xff)<<8)|(blue & 0xff);
    }
    function color_a(alpha) {
        return (0x10<<24)|(alpha & 0xff);
    }
    function clear_cst(c, s, t) {
        return (0x26<<24)|((c & 0x01) << 2)|((s & 0x01) << 1)|(t & 0x01);
    }
    function line_width(width) {
        return (0x0e<<24)|(width & 0x0fff);
    }
    function begin(prim) {
        return (0x1f<<24)|(prim & 0x0f);
    }
    function bitmaphandle(handle) {
        return (0x05<<24)|(handle & 0x0f);
    }
    function touchtag(tag) {
        return (0x03<<24)|(tag & 0xff);
    }
    function tagmask(state) {
        return (0x14<<24)|(state & 0x01);
    }
    function vertex2f(x, y) {
        return (0x01<<30)|((x & 0x7fff) << 15)|(y & 0x7fff);
    }
    function vertex2ii(x, y, handle=0, cell=0) {
        return (0x02<<30)|((x & 0x01ff) << 21)|((y & 0x01ff) << 12)|((handle & 0x1f) << 7)|(cell & 0x7f);
    }
    function point_size(size) {
        return (0x0d<<24)|(size & 0x1fff);
    }
    function scissor_xy(x, y) {
        return (0x1b<<24)|((x & 0x01ff) << 9)|(y & 0x01ff);
    }
    function scissor_size(width, height) {
        return (0x1c<<24)|((width & 0x03ff) << 10)|(height & 0x03ff);
    }
    function bitmap_source(addr) {
        return (0x01<<24)|(addr & 0x0fffff);
    }
    function bitmap_layout(format, linestride, height) {
        return (0x07<<24)|((format & 0x1f) << 19)|((linestride & 0x03ff) << 9)|(height & 0x01ff);
    }
    function bitmap_size(filter, wrapx, wrapy, width, height) {
        return (0x08<<24)|((filter & 0x01) << 20)|((wrapx & 0x01) << 19)|((wrapy & 0x01) << 18)|((width & 0x01ff) << 9)|(height & 0x01ff);
    }
    function bitmap_transform_a(a) {
        return (0x15<<24)|(a & 0x01ffff);
    }
    function bitmap_transform_e(e) {
        return (0x19<<24)|(e & 0x01ffff);
    }
    function blend_func(src, dst) {
        return (0x0b<<24)|((src & 0x07) << 3)|(dst & 0x07);
    }

    function gpu_host_cmd(cmd) {
        this.cs_l.write(0);
        this.spi.write(format("%c%c%c",cmd,0,0));
        this.cs_l.write(1);
    }
    
    function power_down(callback) {
        this.pd_l.write(0);
        imp.wakeup(0.5, callback);
    }

    function power_up(callback) {
        this.pd_l.write(1);
        imp.wakeup(0.2, callback);
    }

    function init() {
        gpu_host_cmd(FT_GPU_EXTERNAL_OSC);
        // TO-DO: get rid of imp.sleep because it's synchronous and icky.
        imp.sleep(0.2);
        
        gpu_host_cmd(FT_GPU_PLL_48M);
        imp.sleep(0.2);
        
        gpu_host_cmd(FT_GPU_CORE_RESET);
        gpu_host_cmd(FT_GPU_ACTIVE_M);
        
        // wait for the GPU to report init complete
        local timeout = 500000; // time in us
        local start = hardware.micros();
        local chip_id = gpu_read_mem(REG_ID, 1);
        while (chip_id[0] != 0x7C) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for GPU init to finish");
                return 1;
            }
            chip_id = gpu_read_mem(REG_ID, 1);
            //server.log(format("0x%02x", chip_id[0]));
        }
    }

    function config() {
        gpu_write_mem16(REG_HCYCLE, FT_DispHCycle);
        gpu_write_mem16(REG_HOFFSET, FT_DispHOffset);
        gpu_write_mem16(REG_HSYNC0, FT_DispHSync0);
        gpu_write_mem16(REG_HSYNC1, FT_DispHSync1);
        gpu_write_mem16(REG_VCYCLE, FT_DispVCycle);
        gpu_write_mem16(REG_VOFFSET, FT_DispVOffset);
        gpu_write_mem16(REG_VSYNC0, FT_DispVSync0);
        gpu_write_mem16(REG_VSYNC1, FT_DispVSync1);
        // REG_SWIZZLE is there in case your panel switches R,G,B around
        gpu_write_mem8(REG_SWIZZLE, FT_DispSwizzle);
        // start the display clock
        gpu_write_mem8(REG_PCLK_POL, FT_DispPCLKPol);
        gpu_write_mem8(REG_PCLK, FT_DispPCLK);
        // set the display size
        gpu_write_mem16(REG_HSIZE, FT_DispWidth);
        gpu_write_mem16(REG_VSIZE, FT_DispHeight);
        
        /*Set DISP_EN to 1*/
        //local reg_gpio_dir = gpu_read_mem(REG_GPIO_DIR, 1);
        //server.log("REG_GPIO_DIR: " + reg_gpio_dir[0]);
        // This seems to control the audio
        //gpu_write_mem8(REG_GPIO_DIR, 0x83); // | reg_gpio_dir[0].tointeger());
        local reg_gpio = gpu_read_mem(REG_GPIO, 1);
        //server.log("REG_GPIO: " + reg_gpio[0]);
        gpu_write_mem8(REG_GPIO, 0x83 | reg_gpio[0].tointeger());
        
        /* Touch configuration - configure the resistance value to 1200 - this value is specific to customer requirement and derived by experiment */
        gpu_write_mem16(REG_TOUCH_RZTHRESH, 1200);
        
        cp_stream();
        cp_send_cmd(CMD_DLSTART);
        this.cs_l.write(1);
    }

    function gpu_write_mem(addr, byte_array) {
        gpu_write_start(addr);
        foreach (i, byte in byte_array) {
            this.spi.write(format("%c",byte));
        }
        cs_l.write(1);
    }
    
    function gpu_write_blob(addr, data) {
        gpu_write_start(addr);
        this.spi.write(data);
        cs_l.write(1);
    }
    
    function gpu_write_start(addr) {
        local startStr = format("%c%c%c",(0x80 | (addr >> 16)),
            ((addr >> 8) & 0xff),(addr & 0xff));
        this.cs_l.write(1);
        this.cs_l.write(0);
        this.spi.write(startStr);
    }
    
    function gpu_write_mem8(addr, byte) {
        gpu_write_start(addr);
        this.spi.write(format("%c",byte));
        this.cs_l.write(1);
    }
    
    function gpu_write_mem16(addr, int) {
        local writeStr = format("%c%c",(int & 0xff),((int >> 8) & 0xff));
        gpu_write_start(addr);
        this.spi.write(writeStr);
        this.cs_l.write(1);
    }

    function gpu_write_mem32(addr, int) {
        local writeStr = format("%c%c%c%c",(int & 0xff),((int >> 8) & 0xff),
            ((int >> 16) & 0xff),((int >> 24) & 0xff));
        gpu_write_start(addr);
        this.spi.write(writeStr);
        this.cs_l.write(1);
    }
    
    function gpu_wr32(int) {
        this.spi.write(format("%c%c%c%c",(int & 0xff),((int >> 8) & 0xff),
            ((int >> 16) & 0xff),((int >> 24) & 0xff)));
    }

    function gpu_read_mem(addr, len) {
        local writeStr = format("%c%c%c%c",((addr >> 16) & 0xff),((addr >> 8) & 0xff),(addr & 0xff),0);
        cs_l.write(0);
        this.spi.write(writeStr);
        local ret = this.spi.readblob(len);
        this.cs_l.write(1);
        
        return ret;
    }

    function gpu_dlswap(swap_type) {
        gpu_write_mem8(REG_DLSWAP, swap_type);
        
        local timeout = 50000; // time in us
        local start = hardware.micros();
        local swap_done = gpu_read_mem(REG_DLSWAP, 1);
        while (swap_done[0] != DLSWAP_DONE) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for display list swap.");
                return 1;
            }
            swap_done = gpu_read_mem(REG_DLSWAP, 1);
        }
    }
    
    function set_rotation(val) {
        this.cs_l.write(1);
        if (val) {
            gpu_write_mem8(REG_ROTATE, 0x01);
        } else {
            gpu_write_mem8(REG_ROTATE, 0x00);
        }
        this.cs_l.write(1);
    } 

    /* COPROCESSOR COMMANDS --------------------------------------------------*/
    
    function cp_start() {
        cp_stream();
        cp_send_cmd(CMD_DLSTART);
        this.cs_l.write(1);
    }
    
    /* End a SPI transaction with the coprocessor. Ends the current display list.
     */
    function cp_finish() {
        cp_stream();
        cp_send_cmd(END);
        cp_getfree(4);
        this.cs_l.write(1);
    }
    
    /* Initiate a SPI transaction with the address pointer set to the current 
     * position in the coprocessor command FIFO.
     */
    function cp_stream() {
        this.cs_l.write(1);
        gpu_write_start(RAM_CMD + (cp_ptr & FIFO_SIZE));
    }
    
    /* End a SPI transaction with the coprocessor. Ends the current display list
     * and swaps the display buffer.
     */
    function cp_swap() {
        cp_stream();
        cp_send_cmd(CMD_SWAP);
        cp_send_cmd(DISPLAY);
        cp_send_cmd(CMD_DLSTART);
        cp_getfree(4);
        this.cs_l.write(1);
    }
    
    /* Reset the coprocessor. May be used if the coprocessor reports a fault or stalls
     * Input: (None)
     * Return: (None)
     */
    function cp_reset() {
        cp_ptr = 0;
        freespace = FIFO_SIZE;
        // put the coprocessor into reset
        gpu_write_mem8(REG_CPURESET, 1);
        // reset the command pointers
        gpu_write_mem16(REG_CMD_WRITE, cp_ptr);
        gpu_write_mem16(REG_CMD_READ, cp_ptr);
        // release the coprocessor from reset
        gpu_write_mem8(REG_CPURESET, 0);
        // start a new display list
        cp_start();
    }

    /* Get the current position of the coprocessor's read pointer in the command 
     * FIFO. This is used to determine the amount of free space in the FIFO and 
     * the coprocessor's progress when processing a stream of new commands. 
     */
    function cp_rdptr() {
        // release the chip select so we can select a new memory offset with gpu_read_mem
        this.cs_l.write(1);
        // gpu_read_mem sets the chip select on its own to start the transaction
        local rdpointerraw = gpu_read_mem(REG_CMD_READ, 2);
        // gpu_read_mem releases the chip select on its own to end the transaction
        local rdptr = ((rdpointerraw[1] << 8) + rdpointerraw[0]) & (FIFO_SIZE + 3);
        //server.log(format("rdptr at 0x%04x",rdptr));
        return rdptr;
        // Don't restart the "stream" here, because this is called from inside cp_getfree
        // cp_getfree will restart the stream when it sees the read pointer in the right place
    }
    
    /* Set the command write pointer and wait for the coprocessor to process all or
     * part of the coprocessor command FIFO. 
     * Input: 
     *      n: minimum free space to see in the command FIFO before returning
     *      timeout: (optional) time in ms to wait before timing out operation 
     */ 
    function cp_getfree(n, timeout = 250) {
        // Wrap around at the command FIFO boundary
        cp_ptr = cp_ptr & 0xfff;
        // End the current SPI Transaction
        this.cs_l.write(1);
        // Set the write pointer register to the current position of the write pointer
        this.cs_l.write(0);
        gpu_write_mem16(REG_CMD_WRITE, cp_ptr);
        this.cs_l.write(1);
        // Wait for the coprocessor to process enough of the current buffer for 
        // us to have n bytes free for new commands.
        local fullness = 0;
        local start = hardware.micros();
        do {
            // If coprocessor writes "0xFFF" to REG_CMD_READ, it has had a fault.
            local rdptr = cp_rdptr();
            if (rdptr == 0xfff) {
                server.error(format("Coprocessor reported fault, cp_ptr at 0x%04x",cp_ptr));
                cp_reset();
                return 1;
            }
            fullness = (cp_ptr - rdptr) & (FIFO_SIZE - 1);
            freespace = FIFO_SIZE - fullness;
            if ((hardware.micros() - start) > (timeout * 1000)) {
                server.error("Timed out waiting for Coprocessor");
                cp_reset();
                return 1;
            }
        } while (freespace < n);
        return 0;
    }
    
    /* Write general commands to the coprocessor command FIFO.
     * This function assumes a SPI transaction is already initiated, see
     * cp_stream() to see how a transaction is initiated. 
     * 
     * This command ensures there's room in the command FIFO for the command, 
     * then copies the command into the FIFO. 
     * 
     * After a stream of commands is copied into the FIFO, call cp_getfree(4) to
     * set the command pointer and start the coprocessor working on the new command
     * stream. 
     * 
     * Coprocessor commands must be 4-byte aligned.
     */
    function cp_send_cmd(cmd) {
        if (freespace < 4) {
            cp_getfree(4);
            cp_stream();
        }
        local writeStr = format("%c%c%c%c",(cmd & 0xff),((cmd >> 8) & 0xff),
            ((cmd >> 16) & 0xff),((cmd >> 24) & 0xff));
        this.spi.write(writeStr);
        cp_ptr += 4;
        freespace -= 4;
    }
    
    /* Run the touch screen calibration command to align the touch coordinates.
     * Input:
     *      timeout: time in seconds to wait (for the user) before timing out the calibration 
     * Return:
     *      1 if operation times out
     *      0 on successful completion
     */
    function cp_calibrate(timeout) {
        cp_stream();
        cp_send_cmd(clear_color_rgb(0,0,0));
        cp_send_cmd(clear_cst(1,1,0));
        cp_send_cmd(CMD_CALIBRATE);
        cp_send_cmd(0xffffffff);
        this.cs_l.write(1);
        if (cp_getfree(FIFO_SIZE, timeout * 1000)) {
            return 1;
        } else {
            return 0;
        }
    } 
    
    /* Clear the screen to a specified RGB color through the coprocessor.
     * This command sets the default color of the screen when nothing is drawn on it,
     * then uses CMD_SWAP to redraw the screen on the next draw.
     * Input: 
     *      r: red value (0-255)
     *      g: green value (0-255)
     *      b: blue value (0-255)
     * Return: (None)
     */
    function cp_clear_to(r,g,b) {
        // Start a transaction with the coprocessor
        cp_stream();
        cp_send_cmd(clear_color_rgb(r,g,b));
        // clear the color, stencil, and tag buffers
        cp_send_cmd(clear_cst(1, 1, 1));
        cp_swap();
    }
    
    /* Set the color used to draw primitives such as fonts and shapes
     * Input:
     *      r, g, b: integer 0-255
     * Return: (None)
     */
    function cp_set_color(r,g,b) {
        cp_stream();
        cp_send_cmd(color_rgb(r,g,b));
        this.cs_l.write(1);
    }
    
    /* Set the alpha value for the current color
     * How alpha is used depends on BLEND_FUNC; default is a transparent blend
     * Input: 
     *      alpha: 0-255
     * Return: (None)
     */
    function cp_set_alpha(alpha) {
        cp_stream();
        cp_send_cmd(color_a(alpha));
        this.cs_l.write(1);
    }
    
    /* Clear the color, stencil, and tag buffers
     * Input
     *      c: clear color buffer (bool)
     *      s: clear stencil buffer (bool)
     *      t: clear tag buffer (bool)
     */
    function cp_clear_cst(c,s,t) {
        cp_stream();
        cp_send_cmd(clear_cst(c,s,t));
        this.cs_l.write(1);
    }

    /* Write a blob into the coprocessor command FIFO. 
     * This command assumes a SPI transaction has already been initiated with 
     * cp_stream().
     *
     * Note that coprocessor commands must be four-byte aligned.
     *
     * This method uses cp_getfree() to wrap around the beginning of the circular
     * command buffer, if necessary. 
     */
    function cp_send_blob(myblob) {
        // pad blob to make sure length is a multiple of 4 (FT800 requirement)
        local length = myblob.len()
        local bytesToAdd = 0;
        if (length % 4) {
            bytesToAdd = 4 - (length % 4);
        }
        myblob.seek(0, 'e');
        for (local i = 0; i < bytesToAdd; i++) {
            ///server.log("Padding blob to 4-byte align.");
            myblob.writen(0x00,'b');
        }
        myblob.seek(0,'b');
        
        //server.log(freespace+" bytes free in FIFO");
        if (freespace < myblob.len()) {
            cp_getfree(myblob.len());
            cp_stream();
        }
        this.spi.write(myblob);
        cp_ptr += myblob.len();
        freespace -= myblob.len();
    }
    
    /* Write a string into the coprocessor command FIFO.
     * This pads the string so that it is four-byte aligned (all coprocessor 
     * commands are four-byte aligned).
     */
    function cp_send_string(string) {
        // Coprocessor commands must be four-byte aligned.
        local padding = "";
        switch (string.len() % 4) {
            case 1:
                padding = "000";
                break;
            case 2:
                padding = "00";
                break;
            case 3:
                padding = "0";
                break;
        }
        // Make sure the coprocessor buffer has room in it for the string
        if (freespace < string.len()) {
            cp_getfree(string.len());
        }
        local rawStr = "";
        // Copy the string directly into the coprocessor command buffer
        foreach (char in (string + padding)) {
            rawStr += format("%c",char);
            cp_ptr += 1;
        }
        this.spi.write(rawStr);
    }
    
    /* Change the foreground color to use when drawing coprocessor widgets.
     * Input:
     *      r, g, b: color values (0-255)
     * Return: (None)
     */
    function cp_fgcolor(r, g, b) {
        cp_stream();
        cp_send_cmd(CMD_FGCOLOR);
        cp_send_cmd(((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff));
        this.cs_l.write(1);
    }
    
    /* Change the background color to use when drawing coprocessor widgets.
     * Input:
     *      r, g, b: color values (0-255)
     * Return: (None)
     */
    function cp_bgcolor(r, g, b) {
        cp_stream();
        cp_send_cmd(CMD_BGCOLOR);
        cp_send_cmd(((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff));
        this.cs_l.write(1);
    }
    
    /* Change the gradient color to use when drawing coprocessor widgets.
     * Usually used for 3D button highlight color
     * Input:
     *      r, g, b: color values (0-255)
     * Return: (None)
     */
    function cp_gradcolor(r, g, b) {
        cp_stream();
        cp_send_cmd(CMD_GRADCOLOR);
        cp_send_cmd(((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff));
        this.cs_l.write(1);
    }
    
    /* Send CMD_GRADIENT to the coprocessor; draws a smooth color gradient
     * Input: 
     *      x0, y0:     coordinates of point 0, in pixels
     *      r0,g0,b0:   color values of point 0 (0 - 255)
     *      x1, y1:     coordinates of point 1, in pixels
     *      r1,g1,b1:   color values of point 1 (0 - 255)
     * Return: (None)
     */
    function cp_gradient(x0, y0, r0, g0, b0, x1, y1, r1, g1, b1) {
        cp_stream(); 
        cp_send_cmd(CMD_GRADIENT);
        cp_send_cmd(((y0 & 0xffff) << 16) | (x0 & 0xffff));
        cp_send_cmd(((r0 & 0xff) << 16) | ((g0 & 0xff) << 8) | (b0 & 0xff));
        cp_send_cmd(((y1 & 0xffff) << 16) | (x1 & 0xffff));
        cp_send_cmd(((r1 & 0xff) << 16) | ((g1 & 0xff) << 8) | (b1 & 0xff));
        this.cs_l.write(1);
    }
    
    /* Use coprocessor commands to write a point primitive into the current display list
     * Input:
     *      x, y: coordinates of point center in pixels
     *      radius: point radius in pixels
     * Return: (None);
     */
    function cp_point(x, y, radius) {
        cp_stream();
        cp_send_cmd(point_size(radius * 16));
        cp_send_cmd(begin(FTPOINTS));
        cp_send_cmd(vertex2f(x * 16, y * 16));
        cp_send_cmd(END);
    }
    
    /* Send CMD_BUTTON to the coprocessor; draws a button widget.
     * Input: 
     *      x:      x-coordinate of button top-left, in pixels
     *      y:      y-coordinate of button top-left, in pixels
     *      width:  width of button in pixels 
     *      height: height of button in pixels
     *      font:   bitmap handle to specify font
     *      options: 
     *          OPT_FLAT: remove 3D effect on button
     *          Button is 3D by default.
     *      str:    button label.
     */
    function cp_button(x, y, width, height, font, str, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_BUTTON);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((height & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((options & 0xffff) << 16) | (font & 0xffff));
        cp_send_string(str+"\0");
        this.cs_l.write(1);
    }
    
    /* Send CMD_KEYS to the coprocessor; draws a row of keys.
     * Input: 
     *      x:      x-coordinate of top-left corner of key row, in pixels
     *      y:      y-coordinate of top-left corner of key row, in pixels
     *      width:  width of each key in pixels 
     *      height: height of each key in pixels
     *      font:   bitmap handle to specify font
     *      options: 
     *          OPT_FLAT: remove 3D effect on button
     *          OPT_CENTER: draw keys at minimum size centered within the W x H rectangle
     *          Button is 3D by default.
     *      str:    string of key labels, one char per key. The TAG value is set
     *              to the ASCII value of each key, so key presses can be detected using REG_TOUCH_TAG
     */
    function cp_keys(x, y, width, height, font, str, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_KEYS);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((height & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((options & 0xffff) << 16) | (font & 0xffff));
        cp_send_string(str+"\0");
        this.cs_l.write(1);
    }
    
    /* Send CMD_GUAGE to the coprocessor; draws a gauge widget.
     * Input: 
     *      x:      x-coordinate of the gauge center, in pixels
     *      y:      y-coordinate of the gauge center, in pixels
     *      radius
     *      major:  number of major divisions on the guage (1-10)
     *      minor:  number of minor divisions per major division (1-10)
     *      value:  displayed value, between 0 and range, inclusive
     *      range:  range of gauge (max value)
     *      options: 
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     *          OPT_NOBACK:     omit background
     *          OPT_NOTICKS:    omit tick marks on guage
     *          OPT_NOPOINTER:  omit pointer
     * Return: (None)
     */
    function cp_gauge(x, y, radius, major, minor, value, range, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_GAUGE);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        // Docs are wrong; radius is actually diameter ;P
        cp_send_cmd(((options & 0xffff) << 16) | ((radius * 2) & 0xffff));
        cp_send_cmd(((minor & 0xffff) << 16) | (major & 0xffff));
        cp_send_cmd(((range & 0xffff) << 16) | (value & 0xffff));
        this.cs_l.write(1);
    }

    
    /* Send CMD_CLOCK to the coprocessor; draws a clock widget.
     * Input: 
     *      x:      x-coordinate of the clock center, in pixels
     *      y:      y-coordinate of the clock center, in pixels
     *      radius
     *      hours
     *      minutes
     *      seconds
     *      ms:     milliseconds
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     *          OPT_NOBACK:     omit background
     *          OPT_NOTICKS:    omit 12-hour ticks
     *          OPT_NOSECS:     omit second hand
     *          OPT_NOHM:       omit minute and hour hands
     *          OPT_NOHANDS:    omit all hands
     * Return: (None)
     */
    function cp_clock(x, y, radius, hours, minutes, seconds, ms, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_CLOCK);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        // Docs are wrong; radius is actually diameter ;P
        cp_send_cmd(((options & 0xffff) << 16) | ((radius * 2) & 0xffff));
        cp_send_cmd(((minutes & 0xffff) << 16) | (hours & 0xffff));
        cp_send_cmd(((ms & 0xffff) << 16) | (seconds & 0xffff));
        this.cs_l.write(1);
    }
    
    /* Send CMD_PROGRESS to the coprocessor; draws a progress bar.
     * Input: 
     *      x, y:   coordinates of top-left corner, in pixels
     *      width:  width of bar in pixels
     *      height: height of bar in pixels
     *  -> if width is greater than height, bar is drawn horizontally
     *  -> otherwise, bar is drawn vertically.
     *      value:  displayed value, between 0 and range, inclusive
     *      range:  range of bar (max value)
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     * Return: (None)
     */
    function cp_progress(x, y, width, height, value, range, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_PROGRESS);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((height & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((value & 0xffff) << 16) | (options & 0xffff));
        cp_send_cmd(range & 0xffff);
        this.cs_l.write(1);
    }
    
    /* Send CMD_SCROLL to the coprocessor; draws a scroll bar.
     * Input: 
     *      x, y:   coordinates of top-left corner, in pixels
     *      width:  width of bar in pixels 
     *      height: height of bar in pixels
     *  -> if width is greater than height, bar is drawn horizontally
     *  -> otherwise, bar is drawn vertically.
     *      value:  displayed value, between 0 and range, inclusive
     *      range:  range of bar (max value)
     *      size:   size of marker (pixels)
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     * Return: (None)
     */
    function cp_scroll(x, y, width, height, value, range, size, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_SCROLLBAR);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((height & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((value & 0xffff) << 16) | (options & 0xffff));
        cp_send_cmd(((range & 0xffff) << 16) | (size & 0xffff));
        this.cs_l.write(1);
    }
    
    /* Send CMD_SLIDER to the coprocessor; draws a slider bar.
     * Input: 
     *      x, y:   coordinates of top-left corner, in pixels
     *      width:  width of bar in pixels 
     *      height: height of bar in pixels
     *  -> if width is greater than height, bar is drawn horizontally
     *  -> otherwise, bar is drawn vertically.
     *      value:  displayed value, between 0 and range, inclusive
     *      range:  range of bar (max value)
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     * Return: (None)
     */
    function cp_slider(x, y, width, height, value, range, options = 0) {
        cp_stream(); 
        cp_send_cmd(CMD_SLIDER);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((height & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((value & 0xffff) << 16) | (options & 0xffff));
        cp_send_cmd(range & 0xffff);
        this.cs_l.write(1);
    }
    
    /* Send CMD_DIAL to the coprocessor; draws a rotary dial control.
     * Input: 
     *      x, y:   coordinates of dial center, in pixels
     *      radius
     *      value:  position of dial (0-65535)
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     * Return: (None)
     */
    function cp_dial(x, y, radius, value, options = 0) {
        server.log("Drawing a Dial at ("+x+", "+y+")");
        cp_stream(); 
        cp_send_cmd(CMD_DIAL);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        // datasheet calls it radius, but turns out it's diameter
        cp_send_cmd(((options & 0xffff) << 16) | ((radius * 2) & 0xffff));
        cp_send_cmd(value & 0xffff);
        this.cs_l.write(1);
    }
    
    /* Send CMD_TOGGLE to the coprocessor; draws a toggle switch
     * Input: 
     *      x, y:   coordinates of top-left corner, in pixels
     *      width:  width of toggle, in pixels
     *      font:   font bitmap handle
     *      state:  state of the toggle. 0 is of, 1 is on
     *      labeltrue,labelfalse: string labels for toggle states
     *      options:
     *          OPT_3D:         default
     *          OPT_FLAT:       removes 3D effect
     * Return: (None)
     */
    function cp_toggle(x, y, width, font, state, labeltrue, labelfalse, options = 0) {
        // coprocessor expects 65535 for on (never heard of bool??)
        if (state) {state = 65535};
        cp_stream(); 
        cp_send_cmd(CMD_TOGGLE);
        cp_send_cmd(((y & 0xffff) << 16) | (x & 0xffff));
        cp_send_cmd(((font & 0xffff) << 16) | (width & 0xffff));
        cp_send_cmd(((state & 0xffff) << 16) | (options & 0xffff));
        cp_send_string(labeltrue+"\xff"+labelfalse+"\0");
        this.cs_l.write(1);
    }

    /* Send CMD_TEXT to the coprocessor.
     * Input:
     *      x: x-coordinate of the text base in pixels (top-left corner of text by default)
     *      y: y-coordinate of the text base in pixels
     *      font: handle of preset font to use, integer 0-31
     *      options: OR together any of the following options:
     *          OPT_CENTERX: center text horizontally
     *          OPT_CENTERY: center text vertically
     *          OPT_CENTER: center text both vertically and horizontally
     *          OPT_RIGHTX: right-justify text (value of OPT_RIGHTX is 2048).
     *      string: 
     * Return: (None)
     */
    function cp_text(x, y, font, options, string) {
        cp_stream();
        cp_send_cmd(CMD_TEXT);
        cp_send_cmd(((y << 16) | (x & 0xffff)));
        cp_send_cmd(((options << 16) | font));
        cp_send_string(string + "\0");
        this.cs_l.write(1);
    }
    
    /* Start an animated spinner
     * Input:
     *      x, y: coordinates of top-left corner of spinner (pixels)
     *      style: 0-3 to specify pre-made spinner styles
     *      scale: scaling coefficient; 0 = no scaling
     * Return: (None)
     */
    function cp_spinner(x, y, style, scale=0) {
        cp_stream();
        cp_send_cmd(CMD_SPINNER);
        cp_send_cmd(((y << 16) | (x & 0xffff)));
        cp_send_cmd(((scale << 16) | (style & 0xff)));
        this.cs_l.write(1);
    }
     
    /* Start an animated screensaver
     * After this command, the coprocessor continuously updates REG_MACRO_0 with 
     * VERTEX2F of varying coordinates. By calling this command after creating an
     * appropriate display list, the command will shift the bitmap around the screen
     * without any additional work with the MCU.
     * 
     * Send CMD_STOP with cp_stop() to halt the screensaver.
     *
     * Input: (None)
     * Return: (None)
     */
    function cp_screensaver() {
        cp_stream();
        cp_send_cmd(CMD_SCREENSAVER);
        this.cs_l.write(1);
    }
    
    /* Start interactive sketching and store result in RAM
     * Input: 
     *      x, y: coordinates of sketch area top-left (pixels)
     *      width, height: dimensions of sketch area (pixels)
     *      ptr: base address of sketch bitmap
     *      format: format of sketch bitmap (L1 or L8)
     * Return: (None)
     */
    function cp_sketch(x, y, width, height, ptr, format) {
        cp_stream();
        cp_send_cmd(CMD_SKETCH);
        cp_send_cmd(((y << 16) | (x & 0xffff)));
        cp_send_cmd(((height << 16) | (width & 0xffff)));
        cp_send_cmd(((ptr << 16) | (format & 0xffff)));
        this.cs_l.write(1);
    }
    
    /* Stop a continuous coprocessor operation, such as SKETCH or SCREENSAVER
     * Input: (None)
     * Return: (None)
     */
    function cp_stop() {
        cp_stream();
        cp_send_cmd(CMD_STOP);
        this.cs_l.write(1);
    }
    
    /* Take a snapshot of the current screen. Snapshot is stored as an ARGB4 bitmap.
     * Bitmap size is the size of the screen as set in REG_HSIZE and REG_VSIZE.
     * Curing the snapshot process, the display should be disabled by setting REG_PCLK to 0.
     * Input:
     *      ptr: offset to where snapshot should be stored.
     * Return: (None)
     */
    function cp_snapshot(ptr) {
        // disable display before sending coprocessor commands
        gpu_write_mem8(REG_PCLK, 0);
        cp_stream();
        cp_send_cmd(CMD_SNAPSHOT);
        cp_send_cmd(ptr);
        this.cs_l.write(1);
        // re-enable display
        gpu_write_mem8(REG_PCLK, FT_DispPCLK);
    }
    
    /* Track the touch on a particular object with one valid tag assigned.
     * Coprocessor updates REG_TRACKER periodically (w/ frame rate of panel)
     * REG_TRACKER will hold:
     *      rotary mode: angle between touching point and center of object
     *              value is in 1/65535 of a circle
     *      linear mode: value is in 1/65535 of the range of the object
     * Input: 
     *      x, y: coordinates of track area (top-left for linear tracker, center
     *              for rotary tracker, in pixels)
     *      width, height: dimensions of track area, in pixels
     *      tag:  tag of the object to be tracked, 1-255
     * Return: (None)
     */
    function cp_track(x, y, width, height, tag) {
        cp_stream();
        cp_send_cmd(CMD_TRACK);
        cp_send_cmd((y << 16) | (x & 0xffff));
        cp_send_cmd((height << 16) | (width & 0xffff));
        cp_send_cmd(tag & 0xffff);
    }
    
    /* Set the bitmap handle
     * This allows us to perform graphics operations on this handle, treating it as a sprite
     * Input:
     *      handle (integer, 0 to 14)
     * Return: (None)
     */
    function cp_set_bmphandle(handle) {
        cp_stream();
        cp_send_cmd(bitmaphandle(handle));
        // Don't flush the command buffer; leave the display list open so we can finish writing it.
        this.cs_l.write(1);
    }
    
    /* Set the tag mask bit. 
     * This bit controls whether or not graphics object tags can be set, and defaults to 1.
     * Input:
     *      state: 1 to allow tags to be set, 0 to disable tags.
     * Return: (None)
     */
    function cp_set_tagmask(state) {
        cp_stream();
        //server.log(format("Tag Mask: 0x%08x",tagmask(state)));
        cp_send_cmd(tagmask(state));
        this.cs_l.write(1);
    }
    
    /* Set the touch tag for a graphics object.
     * Input: 
     *      tag:    Valid tags are 1-255
     *      callback: a function to call when the tagged object is touched.
     * Return: (None)
     */
    function cp_set_tag(tag, callback=null) {
        cp_stream();
        //server.log(format("Tag: 0x%08x",touchtag(tag)));
        cp_send_cmd(touchtag(tag));
        this.tag_callbacks[tag] = callback;
        this.cs_l.write(1);
    }
     
    /* Load a bitmap into general memory, then set display list context through the coprocessor.
     * This command requires some information be parsed from the bitmap header. 
     * Input:
     *      bitmap_header: a table with parameters from the bitmap header:
     *          format: FT800 BMP Format code (e.g. ARGB1555)
     *          stride: linestride (4 * ((bmpheader.width * (bmpheader.bitsperpx / 8) + 3) / 4);)
     *          width: bitmap width
     *          height: bitmap height
     *          bitsperpx: bits per pixel (color depth)
     *      bitmap_data: the pixel field of the bitmap file, as a blob
     *      bitmap handle: bitmap handle to associate with this data (0-15)
     */
    function cp_load_bmp(bitmap_header, bitmap_data, handle, dest_offset) {
        // dump the bitmap data in graphics memory
        gpu_write_blob(dest_offset, bitmap_data);
        
        server.log("Done writing data to FT800 RAM.");

        // end this transaction and restart "stream" with coprocessor
        this.cs_l.write(1);
        cp_stream();
        
        cp_send_cmd(begin(BITMAPS));
        cp_send_cmd(bitmaphandle(handle));
        cp_send_cmd(bitmap_source(dest_offset)); // specify the bmp source location
        cp_send_cmd(bitmap_layout(bitmap_header.format, bitmap_header.stride, bitmap_header.height));
        cp_send_cmd(bitmap_size(NEAREST, BORDER, BORDER, bitmap_header.width, bitmap_header.height));
        cp_send_cmd(END);
    
        this.cs_l.write(1);
    }

    /* Decompress a JPEG image into RAM via the coprocessor and associate it with a bitmap handle.
     * The JPEG data is written straight into the command buffer as the coprocessor processes it.
     * The image can then be drawn to the screen by writing the associated bitmap handle into
     * a display list. 
     *
     * CMD_LOADIMAGE appends commands to display list memory by default to set the 
     * source, layout, and size of the resulting bitmap. OPT_NODL prevents this.
     * 
     * Input: 
     *      jpg_data: a binary blob of JPEG data, including the JPEG header.
     *      dest_offset: memory offset to unpack the image into.
     *          Set dest_offset to "-1" to tell the coprocessor to unload the image data 
     *          directly after the last image in RAM
     *      handle: bitmap handle to assign the resulting bitmap to.
     *      options: any of the following:
     *          OPT_RGB565: (default) loaded bitmap will be in RGB565 format
     *          OPT_MONO:   loaded bitmap will be in monochrome L8 format
     *          OPT_NODL:   prevent appending display list commands. Can be OR'd with
     *                      either of the above commands.
     * Return: (None)
     */
    function cp_load_jpg(jpg_data, dest_offset, handle, options = 0) {
        server.log(format("Unpacking %d bytes of JPEG data into 0x%02x with handle %d",jpg_data.len(),dest_offset,handle));
        
        // begin writing into the CMD buffer
        cp_stream();
        cp_send_cmd(bitmaphandle(handle));
        cp_send_cmd(CMD_LOADIMAGE);
        cp_send_cmd(dest_offset);
        cp_send_cmd(options);
        /*copy JPEG data straight into the CMD buffer in chunks (4096 bytes of CMD memory)*/
        local BLOCKSIZE = 2048;
        for (local i = 0; i < jpg_data.len(); i += BLOCKSIZE) {
            // cp_send_blob automatically makes sure we have free space for the block
            cp_send_blob(jpg_data.readblob(BLOCKSIZE));
        }
        this.cs_l.write(1);
        
        server.log("Done Unpacking JPG.")
    }
    
    /* Decompress a PNG image (they are compressed with DEFLATE) into RAM via the 
     * coprocessor and associate it with a bitmap handle.
     * The PNG data is written straight into the command buffer as the coprocessor processes it.
     * The image can then be drawn to the screen by writing the associated bitmap handle into
     * a display list. 
     *
     * This command is the preferred method for pre-loading graphics into the FT800 
     * for a given application because:
     *  - PNG provides lossless compression
     *  - graphics can be loaded with transparency (JPEG provides only RGB565 and L8 formats)
     *  - the operation is handled through the coprocessor, which simplifies RAM management
     *
     * Use the img_convert tool from FTDI to pre-parse .PNG files, then send the .bin output file
     * http://www.ftdichip.com/Support/Utilities.htm
     * 
     * The requester must provide some information about the files stored in the PNG blob,
     * because the blob cannot be parsed directly.
     *
     * Input: 
     *      png_data:       a binary blob of PNG data. No header.
     *      dest_offset:    memory offset to unpack the image into.
     *      handle:         bitmap handle to assign the resulting bitmap to.
     *      format:         graphics format to use for the resulting BMP data (e.g. ARGB1555)
     *      bitsperpx:      0-32
     *      width:          width of resulting BMP in pixels
     *      height:         height of resulting BMP in pixels
     * Return: (None)
     */
    function cp_load_png(png_data, dest_offset, handle, bmpformat, bitsperpx, width, height) {
        server.log(format("Unpacking %d bytes of PNG data into 0x%02x with handle %d",png_data.len(),dest_offset,handle));
        
        // begin writing into the CMD buffer
        cp_stream();
        cp_send_cmd(bitmaphandle(handle));
        cp_send_cmd(CMD_INFLATE);
        cp_send_cmd(dest_offset);
        local BLOCKSIZE = 2048;
        for (local i = 0; i < png_data.len(); i += BLOCKSIZE) {
            // cp_send_blob automatically makes sure we have free space for the block
            cp_send_blob(png_data.readblob(BLOCKSIZE));
        }
        // specify the resulting bmp source location, layout, and size.
        local stride = 4 * ((width * (bitsperpx / 8) + 3) / 4);
        cp_send_cmd(bitmap_source(dest_offset)); 
        cp_send_cmd(bitmap_layout(bmpformat, stride, height)); 
        cp_send_cmd(bitmap_size(NEAREST, BORDER, BORDER, width, height));
        this.cs_l.write(1);
        
        server.log("Done Unpacking PNG.");
    }
    
    /* Use the coprocessor to draw a specified bitmap handle at a specified offset.
     * Requires that the source and layout of the bitmap have already been set in display list memory. 
     * Input:
     *      handle: bitmap handle (0 to 14)
     *      source: location of image in memory 
     *      offset_x: x-coordinate of the image base (top left corner)
     *      offset_y: y-coordinate of the image base
     * Return: (None)
     */
    function cp_draw(handle,offset_x,offset_y) {
        server.log(format("Drawing Handle %d at (%d,%d)",handle,offset_x,offset_y));
        cp_stream();
        cp_send_cmd(clear_cst(1,1,1));
        cp_send_cmd(begin(BITMAPS));
        cp_send_cmd(vertex2ii(offset_x,offset_y,handle,0));
        cp_send_cmd(END);
        cp_swap();
    }
}

function calibrate() {
    server.log("Calibrating Touch Screen.");
    display.cp_stop();
    if (display.cp_calibrate(10)) {
        server.log("Calibration timed out!");
        display.cp_stop();
        display.cp_getfree(4);
    } else {
        server.log("Done Calibrating.");
    }
    example_dot();
}

function example_dot() {
    display.cp_clear_cst(1,1,1);
    // change the dot color every time we draw this frame
    local r = math.rand() % 255;
    local g = math.rand() % 255;
    local b = math.rand() % 255;
    display.cp_set_color(r,g,b);
    display.cp_set_tag(201, example_dot);
    display.cp_point(FT_DispWidth/2,FT_DispHeight/2,100);
    display.cp_swap();
}

function example_widgets() {
    display.cp_clear_to(0,0,0);
    // clear the color, stencil, and tag buffers
    display.cp_clear_cst(1,1,1);
    // draw a gradient in the background (x0, y0, r0, g0, b0, x1, y1, r1, g1, b1)
    display.cp_gradient(0,0,0,0,0,480,272,255,255,255);
    // set colors for different parts of widgets (r, g, b)
    display.cp_fgcolor(20,80,220);
    display.cp_bgcolor(20,80,220)
    display.cp_gradcolor(255,255,255);
    // set color for drawing text (green)
    display.cp_set_color(0,255,0);
    // draw a formatted string (x, y, font handle, options, string)
    display.cp_text(100, 25, 18, OPT_RIGHTX, "ft800:/$ _");
    // switch text color back to black for the rest of these objects
    display.cp_set_color(0,0,0);
    // draw a progress bar (x, y, width, height, value, range, [options])
    display.cp_progress(15,45,250,10,33,100,0);
    // draw a scroll bar (x, y, width, height, value, range, size, [options])
    display.cp_scroll(15,60,250,10,45,100,10,0);
    // draw a slider bar (x, y, width, height, value, range, [options])
    display.cp_slider(15,75,250,10,20,100,0);
    // draw a rotary dial (x, y, radius, value, [options])
    display.cp_dial(340, 50, 20, 0x8000, 0);
    // draw a toggle switch (x, y, width, font, state, labeltrue, labelfalse, [options])
    display.cp_toggle(20, 100, 30, 21, 1, "ON", "OFF", 0);
    // draw a row of keys (x, y, width, height, font handle, labels, [options]);
    display.cp_keys(10,135,316,60,30,"12345",0);
    // draw buttons (x, y, width, height, font handle, label, [options])
    display.cp_set_tag(201)
    display.cp_button(10,200,145,60,30,"<-",0);
    display.cp_set_tag(202);
    display.cp_button(165,200,145,60,30,"Start",0);
    display.cp_set_tag(203);
    display.cp_button(320,200,145,60,30,"->",0);
    display.cp_set_tag(204);
    // draw a clock (x, y, radius, hours, minutes, seconds, ms, [options])
    display.cp_clock(430, 50, 20, 12, 35, 15, 10, OPT_FLAT);
    display.cp_set_tag(205);
    // draw a gauge (x, y, radius, major divs, minor divs, value, range, [options]
    display.cp_gauge(430, 140, 20, 10, 5, 68, 100, OPT_FLAT);
    display.cp_swap();
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

agent.on("text", function(str) {
    display.cp_start();
    display.cp_clear_cst(1,1,1);
    display.cp_set_color(200,200,200);
    // X, Y, FONT, OPTIONS, STRING
    display.cp_cmd_text(FT_DispWidth/2, FT_DispHeight/2,31,OPT_CENTER,str);
    display.cp_swap();
});

agent.on("loadjpg", function(req) {
    local dest_offset = 0; // place in first free location in RAM
    if ("dest_offset" in req) {
        dest_offset = req.dest_offset;
    }
    local options = 0;
    display.cp_load_jpg(req.jpgdata,dest_offset,req.handle,options);
});

agent.on("loadpng", function(req) {
    local dest_offset = 0; // place in first free location in RAM
    if ("dest_offset" in req) {
        dest_offset = req.dest_offset;
    }
    display.cp_load_png(req.pngdata, dest_offset, req.handle, req.format, req.bitsperpx, req.width, req.height);
})

agent.on("loadbmp", function(req) {
    server.log(format("Got BMP, %d bytes.", req.bmpdata.len()));
    // header table, pixel field blob, bitmap handle, and offset to unpack data into
    display.cp_load_bmp(req.bmpheader, req.bmpdata, req.handle, 0);
});

agent.on("draw", function(req) {
    display.cp_draw(req.handle,req.xoffset,req.yoffset);
});

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

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

/* Beginning of execution */
display <- ft800(spi, cs_l_pin, pd_l_pin, int_pin);
display.power_down(function() {
    // initialize display
    server.log("Powered Down");
    
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
        // start calibration on any touch, and clear this callback as soon as it's called.
        display.on_any_touch(calibrate,1);
    });
});