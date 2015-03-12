// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Description: Example using VS10XX with AudioDownloader Class

/* GLOBALS AND CONSTS --------------------------------------------------------*/

const SPICLK_LOW = 937.5;
const SPICLK_HIGH = 3750;
const UARTBAUD = 115200;
const VOLUME = -70.0; //dB
const RECORD_TIME = 30; //seconds
const BITRATE_KBPS = 15; // recording sample rate in kilobits per second
const SAMPLERATE_HZ = 8000;
const MAX_GAIN = 64; // max gain for AGC in V/V
const VS10XX_CLOCK_MULT = 5; // clock multiplier for VS10XX; can be set after init
// VS10XX uses 4096-byte buffers internally and can run over
// leave some headroom in the send buffer so agent.send never blocks
const SEND_BUFFER_SIZE = 30000; 

_hm <- hardware.micros.bindenv(hardware);

/* FUNCTION AND CLASS DEFS ---------------------------------------------------*/

class VS10XX {
    static VS10XX_READ          = 0x03;
    static VS10XX_WRITE         = 0x02;
    static VS10XX_SCI_MODE      = 0x00;
    static VS10XX_SCI_STATUS    = 0x01;
    static VS10XX_SCI_BASS      = 0x02;
    static VS10XX_SCI_CLOCKF    = 0x03;
    static VS10XX_SCI_DECODE_TIME = 0x04; 
    static VS10XX_SCI_AUDATA    = 0x05;
    static VS10XX_SCI_WRAM      = 0x06;
    static VS10XX_SCI_WRAMADDR  = 0x07;
    static VS10XX_SCI_HDAT0     = 0x08;
    static VS10XX_SCI_HDAT1     = 0x09;
    static VS10XX_SCI_AIADDR    = 0x0A;
    static VS10XX_SCI_VOL       = 0x0B;
    static VS10XX_SCI_AICTRL0   = 0x0C;
    static VS10XX_SCI_AICTRL1   = 0x0D;
    static VS10XX_SCI_AICTRL2   = 0x0E;
    static VS10XX_SCI_AICTRL3   = 0x0F;
    
    //static VS10XX_CHIP_ID_ADDR  = 0x1E00;
    static VS10XX_CHIP_ID_ADDR = 0xC0C0;
    //static VS10XX_VERSION_ADDR  = 0x1E02;
    static VS10XX_VERSION_ADDR  = 0xC0C2;
    //static VS10XX_CONFIG1_ADDR  = 0x1E03;
    static VS10XX_CONFIG1_ADDR  = 0xC0C3;
    //static VS10XX_TX_UART_DIV_ADDR = 0x1E2A;
    static VS10XX_TX_UART_DIV_ADDR = 0xC0EA;
    //static VS10XX_TX_UART_BYTE_SPEED_ADDR = 0x1E2B;
    static VS10XX_TX_UART_BYTE_SPEED_ADDR = 0xC0EB;
    //static VS10XX_TX_PAUSE_GPIO_ADDR = 0x1E2C;
    static VS10XX_TX_PAUSE_GPIO_ADDR = 0xC0EC;
    
    static ENC_PATCH_COMP = [
        0x0007,0x0001, /*copy 1*/
        0x8050,
        0x0006,0x05da, /*copy 1498*/
        0x0000,0x0000,0x0006,0x8155,0x3d00,0x0024,0x0006,0x2016,
        0x000f,0xd9cf,0x0000,0x160e,0x280f,0xd1c0,0x0000,0x004d,
        0x280f,0xdb45,0x0000,0x0dc0,0x0031,0xb4cf,0x0000,0x17ce,
        0x0000,0x004d,0x2908,0x73c0,0x0030,0x0480,0x3463,0x0024,
        0x2900,0xb240,0x34a0,0x8024,0x0031,0xbd0f,0x0000,0x198e,
        0x2831,0xb500,0x0000,0x004d,0x0006,0x9a17,0x3701,0x0024,
        0x0008,0x7a17,0x449a,0x1fc4,0x0000,0x0024,0x2800,0x1d15,
        0x448a,0x1cc4,0x3463,0x0024,0x2800,0x1d04,0x34a1,0x4024,
        0x0000,0x0400,0x3f00,0x0024,0x2908,0xf780,0x3613,0x0024,
        0x3100,0x0024,0xf200,0x0024,0xf200,0x0024,0xf200,0x0024,
        0xf200,0x0024,0x0031,0xc98f,0x0000,0x1f4e,0x2831,0xbd40,
        0x0000,0x004d,0x2935,0x74c0,0x0000,0x0024,0x0000,0x20d5,
        0x0008,0xdfd7,0x2831,0xccc0,0x3f05,0x4024,0x0006,0x0017,
        0x3f12,0x184c,0x3f13,0x7800,0x0000,0x0740,0x2911,0xa7c0,
        0x3f13,0x8024,0x4080,0x3c0f,0x0000,0x0024,0x2800,0x2e15,
        0x3009,0x1bc0,0x0000,0x2e08,0x0000,0x004d,0x0035,0xe5cf,
        0x2835,0xb7c0,0x0000,0x248e,0x0000,0x008d,0x0035,0xc6cf,
        0x0000,0x290e,0x2835,0xc241,0x0000,0x0041,0x4190,0x110c,
        0xb886,0xb300,0x0000,0x04cd,0x0035,0xee0f,0x2835,0xe780,
        0x0000,0x274e,0x0000,0x0485,0x635a,0x0024,0x0000,0x248e,
        0x2800,0x2695,0x0035,0xe5cf,0x0000,0x0805,0x2a35,0xee40,
        0x0000,0x008d,0x0000,0x248e,0x0035,0xe5cf,0x2835,0xc988,
        0x0000,0x0024,0x0000,0x03d5,0x3483,0x184c,0x003f,0xfc55,
        0xb888,0x4511,0x0000,0x2fce,0x0039,0xaf0f,0x0000,0x058d,
        0x2939,0x87c0,0x3483,0x0024,0x2900,0x3200,0x3613,0x0024,
        0x0000,0x008d,0x0000,0x248e,0x0035,0xe5cf,0x2a35,0xc980,
        0x0006,0x0017,0x3712,0x0024,0x3713,0x4024,0x3713,0x8024,
        0x3703,0xc024,0x2000,0x0000,0x0000,0x0024,0x000d,0x91d7,
        0x3700,0x4024,0x2938,0x3c80,0x3000,0x7841,0x000d,0x91d7,
        0x3009,0x1bc0,0x3f00,0x0024,0x2839,0xafc0,0x0000,0x058d,
        0x0037,0x010f,0x0000,0x004d,0x2836,0xfd80,0x0000,0x330e,
        0x2800,0x38d5,0x0000,0x0024,0x0000,0x0002,0x0008,0xe110,
        0x3000,0x184c,0x6200,0x0024,0x0008,0xe690,0x2800,0x3901,
        0x3010,0x4024,0x0000,0x010d,0x36f3,0x0024,0x0000,0x0001,
        0x0037,0xdfcf,0x2837,0xd280,0x0000,0x36ce,0x2837,0xd280,
        0x0000,0x374e,0x2837,0xd280,0x0000,0x37ce,0x2837,0xd280,
        0x0000,0x384e,0x2800,0x33c0,0x6294,0x0024,0x3010,0x584c,
        0x3000,0x0024,0x0037,0x224f,0x0000,0x004d,0x2837,0x0240,
        0x0000,0x3a4e,0x2800,0x7685,0x0000,0x0024,0x2800,0x3b80,
        0xb88c,0x0024,0x669c,0x0024,0x0008,0xe310,0x3000,0x0024,
        0x6600,0x0024,0x0000,0x0024,0x2800,0x4a98,0x0000,0x0024,
        0x0000,0x0003,0x0008,0xe110,0x3000,0x0024,0x6300,0x0024,
        0x0000,0x0024,0x2800,0x3b41,0x0000,0x0024,0x0037,0x330f,
        0x0000,0x004d,0x2837,0x2700,0x0000,0x3fce,0x2800,0x46c5,
        0x0000,0x0024,0x2936,0x99c0,0xb880,0x184c,0x0000,0x0002,
        0x0000,0x008d,0x0037,0x394f,0x2837,0x3500,0x0000,0x420e,
        0x2837,0x3500,0x0000,0x428e,0x0000,0x0002,0x0000,0x00cd,
        0x0037,0x3d8f,0x2837,0x3a40,0x0000,0x43ce,0x2837,0x3a40,
        0x0000,0x444e,0x2837,0x3a40,0x0000,0x44ce,0x0037,0x434f,
        0x0000,0x004d,0x2837,0x3dc0,0x0000,0x45ce,0x2936,0x99c0,
        0x3000,0x0024,0x2800,0x3d40,0x6396,0x0024,0x0000,0x0002,
        0x0000,0x00cd,0x0037,0x498f,0x2837,0x4540,0x0000,0x480e,
        0x2837,0x4540,0x0000,0x488e,0x2837,0x4540,0x0000,0x490e,
        0x0037,0x4d0f,0x0000,0x004d,0x2837,0x49c0,0x0000,0x4a0e,
        0x2936,0x99c0,0x0000,0x44c8,0x0037,0x500f,0x0000,0x004d,
        0x2837,0x4dc0,0x0000,0x4b8e,0x2800,0x4c55,0x0000,0x0024,
        0x0000,0x0a80,0x2936,0xc4c0,0x3613,0x0024,0x2800,0x4d80,
        0xb88e,0x0024,0x679e,0x0024,0x0008,0xe310,0x3000,0x0024,
        0x6700,0x0024,0x0000,0x0024,0x2837,0x8398,0x0000,0x0024,
        0x2800,0x5bc0,0xb88c,0x0024,0x0037,0x5bcf,0x0000,0x004d,
        0x2837,0x5440,0x0000,0x508e,0x4182,0x0024,0x0008,0xe817,
        0x2800,0x5509,0x4216,0x1c05,0x0000,0x1204,0x000d,0x8215,
        0xfe4a,0x0024,0x48ba,0x0024,0x0011,0x00c5,0x4458,0x1405,
        0x4458,0x0024,0xf400,0x4115,0x3501,0x0024,0x6348,0x0024,
        0x0000,0x0024,0x2800,0x5509,0x0000,0x0101,0x6316,0x0024,
        0x6306,0x0024,0xf136,0x0024,0xf136,0x0024,0x0000,0x0002,
        0x2800,0x5849,0x4396,0x0024,0x2400,0x5803,0x0000,0x0024,
        0xf400,0x4411,0xf400,0x44d2,0x293a,0x7ac0,0x3613,0x0024,
        0x3343,0x0024,0x2936,0xb440,0x3613,0x0024,0x3423,0x184c,
        0x4082,0x1380,0x6106,0x0024,0x4770,0x0024,0x0008,0xeb41,
        0x4100,0x0024,0x0000,0x0301,0x4060,0x0024,0x4380,0x4010,
        0x2936,0xbd40,0x3000,0x8024,0x669c,0x2003,0x0008,0xe110,
        0x3000,0x0024,0x6600,0x0024,0x0000,0x0024,0x2800,0x4d41,
        0x0000,0x0024,0x2936,0xb440,0x3613,0x0024,0x0025,0xa350,
        0xb888,0x108c,0xb884,0x3380,0x0000,0x0100,0x6400,0x0024,
        0x0000,0x0180,0x2800,0x6c98,0x0000,0x0024,0x4660,0x0045,
        0x4002,0x0024,0x0008,0xe940,0x4010,0x0024,0x4040,0x0024,
        0xf400,0x4012,0x3200,0x0024,0x6080,0x0024,0x0000,0x0024,
        0x2800,0x6445,0x0000,0x0024,0x678e,0x0024,0x0000,0x0024,
        0x2800,0x6445,0x0000,0x0024,0x6594,0x0024,0x2800,0x5e80,
        0x6498,0x0024,0x6520,0x0024,0x0000,0x0024,0x2800,0x6388,
        0x0000,0x0024,0x2400,0x6bc0,0x0000,0x0024,0x0000,0x0200,
        0x0000,0x0583,0x3413,0x184c,0xfe0f,0xc4c5,0x48b2,0x0024,
        0x0008,0xf041,0x4102,0x0024,0x4660,0x0024,0x4000,0x0024,
        0x4100,0x0024,0x4040,0x0024,0x4330,0x4012,0xfe0e,0x0801,
        0x0009,0x0540,0x48ba,0x0024,0x4040,0x0024,0xfe3c,0x0024,
        0x48ba,0x0024,0xf400,0x4103,0x4040,0x1004,0x4020,0x93c5,
        0xf400,0x4012,0x2936,0x99c0,0x3200,0x0024,0x6294,0x0024,
        0x2800,0x6380,0x0000,0x0024,0x0037,0x7c0f,0x0000,0x004d,
        0x2837,0x7480,0x0000,0x6d8e,0x0000,0x00c1,0x6212,0x0024,
        0x0000,0x0024,0x2800,0x4f98,0x6052,0x0024,0x0000,0x0024,
        0x2800,0x4f98,0x0000,0x0024,0x3300,0x510c,0x6156,0x984c,
        0x0000,0x0024,0x2800,0x7108,0x0000,0x0024,0xf400,0x4141,
        0x3c01,0xb347,0x6107,0xc2c4,0x0000,0x0180,0xf134,0x0044,
        0xfe08,0x9004,0x0024,0x0000,0x48be,0x4112,0x4060,0x0024,
        0x4280,0x4011,0x3430,0x8024,0x003a,0x588f,0x0000,0x320d,
        0x0000,0x750e,0x3401,0x9307,0x293a,0x4700,0x0000,0x75c8,
        0x0001,0xffc1,0x283a,0x58c0,0xb010,0x0024,0x4438,0x0c4c,
        0x2800,0x6d80,0x6294,0x4040,0x0000,0x0002,0x0008,0xe110,
        0x3000,0x0024,0x6200,0x0024,0x0000,0x0024,0x2800,0x3ac1,
        0x0000,0x0024,0x0000,0x00cd,0x2400,0x7b0d,0x0000,0x0003,
        0x4220,0x984c,0x4002,0x0024,0x0008,0xe940,0x4010,0x0024,
        0x4030,0x0024,0x6892,0x4010,0x2936,0x99c0,0x3000,0x0024,
        0x6396,0x0024,0x2800,0x76c0,0x6294,0x0024,0x3e12,0x3817,
        0x3e12,0xb809,0x0030,0x0717,0x3f05,0xc024,0x3e11,0xb811,
        0x3e15,0x7810,0x3e18,0xb823,0x3e18,0x3821,0x3e10,0x3801,
        0x48b2,0x0024,0x3e10,0x3801,0x3e11,0x3802,0x3009,0x3814,
        0x0030,0x10d4,0x0006,0x9a50,0x0006,0xa591,0x2913,0x65c0,
        0x3410,0x188c,0x0006,0x9b10,0x0006,0xa591,0x2913,0x65c0,
        0x4088,0x1000,0x0006,0x6694,0xbc82,0x4006,0x0030,0x0351,
        0x3100,0x0024,0x4080,0x0024,0x0030,0x10d1,0x2800,0x8605,
        0x0001,0x800a,0x0030,0x0351,0x3100,0x8024,0xfea8,0x0024,
        0x5ca2,0x0024,0x0000,0x0182,0xac22,0x0024,0xf7c8,0x0024,
        0x48b2,0x0024,0xac22,0x0024,0x2800,0x8940,0xf7cc,0x1002,
        0x0030,0x0394,0x3400,0x4024,0x4480,0x984c,0x0006,0xa651,
        0x2923,0x3380,0x0006,0x6410,0x4088,0x1001,0x4680,0x984c,
        0x0006,0xa651,0x2923,0x3380,0x0006,0x6550,0x0006,0x6694,
        0x408c,0x1002,0xf224,0x0024,0x0006,0xc3d7,0x2800,0x8d55,
        0x0000,0x0024,0x2800,0x8f81,0x0006,0x6410,0x3050,0x0024,
        0x3000,0x4024,0x6014,0x0024,0x0000,0x0024,0x2800,0x8c99,
        0x0000,0x0024,0xf400,0x4040,0x38b0,0x0024,0x2800,0x8f80,
        0x3800,0x0024,0x2800,0x8f41,0xf224,0x0024,0xf400,0x4182,
        0x2800,0x8f85,0xf400,0x4106,0xf12c,0x0024,0xf148,0x0024,
        0x846c,0x0024,0xf400,0x4184,0x0006,0x9a15,0x3500,0x1c91,
        0xf200,0x9f90,0x0000,0x0024,0x2800,0x9391,0x0006,0x9c95,
        0x3504,0x0024,0x0006,0x9c15,0x3504,0x4024,0xf200,0x2604,
        0x3981,0x8024,0x2800,0x9451,0x3d04,0x4024,0x0006,0xc3d7,
        0x3009,0x1c91,0x3009,0x1f90,0x3009,0x2604,0x3009,0x2606,
        0x3009,0x3c11,0x3009,0x1bd4,0x36f1,0x1802,0x36f0,0x1801,
        0x2210,0x0000,0x36f0,0x1801,0x36f8,0x1821,0x36f8,0x9823,
        0x36f5,0x5810,0x36f1,0x9811,0x36f2,0x9808,0x2000,0x0000,
        0x36f2,0x1817,0xfe10,0x4095,0x48b2,0x0024,0x0000,0x0182,
        0xac22,0x0024,0x2000,0x0000,0xf7c0,0x4542,0x3613,0x0024,
        0x3e10,0x3801,0x3e12,0x3802,0x2911,0x8bc0,0x3e04,0x3811,
        0x0006,0x9f50,0x3009,0x0040,0x3009,0x03c1,0x6102,0x0024,
        0x0001,0x0001,0x2800,0x9f04,0x4012,0x4002,0x3009,0x2001,
        0x2925,0x7d80,0x0000,0x0024,0x2911,0x8d40,0x0000,0x0024,
        0x4290,0x0024,0x0001,0x0010,0x2914,0xb354,0x0000,0x0011,
        0x36f4,0x1811,0x36f2,0x1802,0x2000,0x0000,0x36f0,0x1801,
        0x2925,0x7d80,0x0000,0x0024,0x2911,0x8d40,0x0000,0x9e08,
        0x3613,0x0024,0x3e22,0xb815,0x3e05,0xb814,0x3615,0x0024,
        0x0000,0x800a,0x3e10,0x3801,0x0000,0x0440,0x0000,0x0081,
        0x3e10,0xb803,0x3e11,0x3805,0x3e11,0xb807,0x0003,0x8006,
        0x3e14,0x3811,0x0006,0xc951,0x0030,0x1090,0x3e14,0xb80d,
        0x0030,0x0052,0x3e03,0xf80e,0xb887,0x0415,0xc408,0x0800,
        0xff6a,0x0024,0x48be,0x0024,0xb010,0x4185,0x0000,0x0024,
        0x2800,0xa6c5,0x0000,0x0024,0x455a,0x0024,0x0000,0x0000,
        0x0030,0x1090,0x6396,0x2004,0x6052,0x0024,0x0000,0x0024,
        0x2800,0xa981,0x4592,0x0024,0x2400,0xa941,0x3013,0x0024,
        0x6090,0x0001,0x3000,0x4024,0x0020,0x0000,0x0030,0x10d0,
        0x3000,0x8024,0x6200,0x0024,0x0000,0x1000,0x2800,0xac85,
        0x0000,0x0024,0xf290,0x0024,0x6200,0x0024,0x0000,0x1000,
        0x2800,0xae95,0x0000,0x0024,0x6300,0x03cc,0x003f,0xff81,
        0x2800,0xae81,0x0000,0x0024,0x3000,0x0024,0xb012,0x0024,
        0x2800,0xa6c0,0x3800,0x4024,0x0030,0x1090,0x003f,0xfbc0,
        0xb400,0x980e,0x3800,0x0024,0x36f3,0xc024,0x36f4,0x980d,
        0x36f4,0x1811,0x36f1,0x9807,0x36f1,0x1805,0x36f0,0x9803,
        0x36f0,0x1801,0x3405,0x9014,0x36e3,0x0024,0x2000,0x0000,
        0x36f2,0x9815,0x3613,0x0024,0x3e12,0xb817,0x3e12,0x3815,
        0x3e05,0xb814,0x3615,0x0024,0x0000,0x800a,0x3e10,0x3801,
        0x3e10,0xf804,0x3e11,0x7810,0x0006,0xc790,0x3e14,0x7812,
        0x0006,0xa351,0x0006,0x9a12,0x3e04,0xc000,0x3200,0x2400,
        0x4090,0x0024,0x000f,0xa000,0x2800,0xbbd5,0x0000,0x0024,
        0x6200,0x0024,0x0020,0x0611,0x2800,0xb945,0x0000,0x0081,
        0x001f,0x4000,0x6200,0x0024,0x0000,0x0024,0x2800,0xbbd5,
        0x0000,0x0024,0x0030,0x1090,0x6190,0x0024,0x0008,0x7953,
        0x3b00,0x0024,0x3000,0x0024,0x6012,0x0024,0x0000,0x00c0,
        0x3800,0x4024,0x2927,0x9940,0x0006,0xa590,0x0006,0xeb50,
        0x0006,0xc951,0x2900,0xa000,0x0006,0xc793,0x3009,0x0000,
        0x0006,0xc750,0x3009,0x0401,0x4100,0x0024,0x003f,0xfdc1,
        0x3009,0x2400,0x0000,0x0000,0x2900,0x0b80,0x3009,0x0c05,
        0x3009,0x2000,0x0030,0x0050,0x3000,0x0024,0xb012,0x0024,
        0x3800,0x4024,0x3200,0x0024,0x4090,0x0024,0x0030,0x0690,
        0x2800,0xccd5,0x0000,0x0240,0x0000,0x0101,0x0006,0xc411,
        0x2911,0x8d40,0x3800,0x0024,0x0000,0x0010,0x3009,0x2410,
        0x0006,0xc410,0x3009,0x0000,0x6016,0x0024,0x0000,0x0101,
        0x2800,0xc355,0x0006,0xc410,0x003f,0xfc01,0x0030,0x0511,
        0x0006,0x9c13,0x0001,0x0012,0x0006,0x9c10,0x3100,0x0024,
        0xb012,0x0024,0xb880,0x27c1,0x0001,0x0101,0x3900,0x0024,
        0x3b04,0x8024,0x3000,0x0024,0x6016,0x0024,0x0001,0x0101,
        0x2800,0xc755,0x0006,0x9c10,0x0001,0x0013,0x0006,0x9c50,
        0x0030,0x04d2,0x0006,0xc611,0x2911,0x8bc0,0x003f,0xfc01,
        0x3009,0x0440,0x3a10,0x07c5,0x3200,0x0024,0xb010,0x0024,
        0xc050,0x0024,0x3a00,0x0024,0x3804,0xc024,0x0006,0x9c10,
        0x3804,0xc024,0x0008,0x0cd0,0x3804,0xc024,0x36f4,0xc024,
        0x36f4,0x5812,0x36f1,0x5810,0x36f0,0xd804,0x36f0,0x1801,
        0x3405,0x9014,0x36f3,0x0024,0x36f2,0x1815,0x2000,0x0000,
        0x36f2,0x9817,
        0x0007,0x0001, /*copy 1*/
        0x8023,
        0x0006,0x0002, /*copy 2*/
        0x2a00,0x7bce,
        0x000a,0x0001, /*copy 1*/
        0x0050]
    
    static REC_STOP_TIMEOUT     = 0.5; // seconds
    static UART_BAUD            = 38400;
    static ENDFILLBYTE_PADDING  = 2048;
    static BYTES_PER_DREQ       = 32; // min space available when DREQ asserted
    static INITIAL_BYTES        = 2048; // number of bytes to load when starting playback (FIFO size 2048)
    static RX_WATERMARK    = 4096;
    
    queued_buffers          = []; // array of chunks sent from agent to be loaded and played
    rx_buffer               = null;
    playback_in_progress    = false;
    dreq_cb_set             = false;
    endfillbytes_sent       = 0; 
    
    spi     = null;
    xcs_l   = null;
    xdcs_l  = null;
    dreq    = null;
    rst_l   = null;
    uart    = null;
    
    dreq_cb = null;
    buffer_consumed_cb  = null;
    buffer_ready_cb     = null;
    recording_done_cb   = null;
    
    constructor(_spi, _xcs_l, _xdcs_l, _dreq, _rst_l, _uart, _buffer_consumed_cb, _buffer_ready_cb) {
        spi     = _spi;
        xcs_l   = _xcs_l;
        xdcs_l  = _xdcs_l;
        dreq    = _dreq;
        rst_l   = _rst_l;
        uart    = _uart;
        buffer_consumed_cb = _buffer_consumed_cb;
        buffer_ready_cb    = _buffer_ready_cb;
        
        init();
    }
    
    function init() {
        rst_l.write(0);
        rst_l.write(1);
        _clearDreqCallback();
        rx_buffer = blob(2);
        rx_buffer.seek('b');
        dreq.configure(DIGITAL_IN, _callDreqCallback.bindenv(this));
        uart.configure(UART_BAUD, 8, PARITY_NONE, 1, NO_CTSRTS | CALLBACK_WITH_FLAGS, _uartCb.bindenv(this));
    
        // load the encoding patches in compressed format from 
        // http://www.vlsi.fi/en/support/software/vs10xxpatches.html
        //server.log("Loading Encoding Patch");
        _loadPlugin(ENC_PATCH_COMP);
        //server.log("Done loading patch");
    }
    
    function _loadPlugin(plugin) {
        local i = 0;
        local addr = 0;
        local n = 0;
        local val = 0;
        while (i < plugin.len()) {
            addr = plugin[i++];
            n = plugin[i++];
            if (n & 0x8000) { /* RLE run, replicate n samples */
                n = n & 0x7FFF;
                val = plugin[i++];
                while (n--) {
                    _setReg(addr, val);
                }
            } else { /* Copy run, copy n samples */
                while (n--) {
                    val = plugin[i++];
                    _setReg(addr, val);
                }
            }
        }
    }
    
    function _getReg(addr) {
        local msg = blob(2);
        msg.writen(VS10XX_READ, 'b');
        msg.writen(addr,'b');
        msg.writen(0x0000,'w');
        xcs_l.write(0);
        local data = spi.writeread(msg);
        xcs_l.write(1);
        data.seek(2, 'b');
        data.swap2();
        return data.readn('w');
    }
    
    // Data is masked to 16 bits, as all SCI registers are 16 bits wide
    function _setReg(addr, data) {
        local msg = blob(4);
        msg.writen(VS10XX_WRITE, 'b');
        msg.writen(addr, 'b');
        msg.writen((data & 0xFF00) >> 8, 'b');
        msg.writen(data & 0x00FF, 'b');
        xcs_l.write(0);
        spi.write(msg);
        xcs_l.write(1);
    }
    
    function _setRegBit(addr, bit, state) {
        local data = _getReg(addr);
        if (state) { data = (data | (0x01 << bit)); }
        else { data = (data & ~(0x01 << bit)); }
        _setReg(addr, data);
    }
    
    function _setRamAddr(addr) {
        addr = addr & 0xFFFF;
        _setReg(VS10XX_SCI_WRAMADDR, addr);
    }
    
    function _getRamAddr() {
        return _getReg(VS10XX_SCI_WRAMADDR);
    }
    
    function _writeRam(addr, data, words = 1) {
        _setRamAddr(addr);
        if (!dreq.read()) {
            server.log("busy after setting WRAMADDR for first word");
        }
        if (words > 1) {
            _setReg(VS10XX_SCI_WRAM, (data & 0xFFFF0000) >> 16);
            if (!dreq.read()) {
                server.log("busy after writing high byte");
            }
            _setRamAddr(addr + 1);
            if (!dreq.read()) {
                server.log("busy after setting WRAMADDR for second word");
            }
        }
        _setReg(VS10XX_SCI_WRAM, data & 0xFFFF);
    }
    
    function _readRam(addr, words = 1) {
        local data = blob(words * 2);
        _setRamAddr(addr);
        while(!data.eos()) {
            data.writen(_getReg(VS10XX_SCI_WRAM), 'w');
        }
        //data.swap2();
        data.seek(0,'b');
        if (words > 1) {
            // 32 bits is the largest word suppored in VS10XX memory
            return data.readn('i');
        } else {
            return data.readn('w');
        }
    }
    
    function _callDreqCallback() {
        if (dreq.read()) { dreq_cb(); }
    }
    
    function _setDreqCallback(cb) {
        if (cb) {dreq_cb_set = true;}
        else {dreq_cb_set = false;}
        dreq_cb = cb.bindenv(this);
    }
    
    function _clearDreqCallback() {
        dreq_cb = function() { return; }.bindenv(this);
        dreq_cb_set = false;
    }
        
    function _dreqCallbackIsSet() {
        return dreq_cb_set;
    }
    
    function _canAcceptData() {
        return dreq.read();
    }

    function _loadData(data) {
        xdcs_l.write(0);
        spi.write(data);
        xdcs_l.write(1);
    }
    
    function _sendEndFillBytes() {
        while(_canAcceptData() && (endfillbytes_sent < ENDFILLBYTE_PADDING)) {
            _loadData("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00");
            endfillbytes_sent += 32;
        }
        if (endfillbytes_sent < ENDFILLBYTE_PADDING) {
            _setDreqCallback(sendEndFillBytes);
        } else {
            endfillbytes_sent = 0;
            _clearDreqCallback();
            server.log("Playback Complete");
        }
    }
    
    function _finishPlaying() {
        _clearDreqCallback();
        endfillbytes_sent = 0;
        _sendEndFillBytes();
    }
    
    function _fillAudioFifo() {
        _clearDreqCallback();
        local buffer = null;
        local bytes_available = 0;
        local bytes_loaded = 0;
        local bytes_to_load = BYTES_PER_DREQ;
        
        if (queued_buffers.len() > 0) {
            buffer = queued_buffers.top();
            bytes_available = (buffer.len() - buffer.tell());
        } else {
            // done (or buffer underrun)
            playback_in_progress = false;
            _finishPlaying();
            return;
        }
        
        try {
            while(_canAcceptData() && (bytes_loaded < bytes_available)) {
                bytes_to_load = bytes_available - bytes_loaded;
                if (bytes_to_load >= BYTES_PER_DREQ) bytes_to_load = BYTES_PER_DREQ;
                _loadData(buffer.readblob(bytes_to_load));
                bytes_loaded += bytes_to_load;
                // server.log("Loading..."+audioChunks.top().tell());
                // server.log(format("VS10XX HDAT0: 0x%04X",audio.getHDAT0()));
                // server.log(format("VS10XX HDAT1: 0x%04X",audio.getHDAT1()));
            }
        } catch (err) {
            server.log("Error Loading Data: "+err);
            server.log(format("bytes_available at start: %d", bytes_available));
            server.log(format("bytes_to_load on last try: %d", bytes_to_load));
            server.log(format("bytes_loaded at error: %d", bytes_loaded));
            server.log(format("buffer ptr: %d",buffer.tell()));
            server.log(format("buffer len: %d",buffer.len()));
        }
        
        //server.log("top buffer: "+audioChunks.top().tell()+" / "+audioChunks.top().len());
        
        if (queued_buffers.top().eos()) {
            //server.log("finished buffer");
            queued_buffers.pop();
            // bartender!
            buffer_consumed_cb()
        } 
        
        if (_canAcceptData()) {
            // we just emptied a buffer; get back to work immediately
            _fillAudioFifo();
        } else {
            // we caught up. Yield for a moment so we can get new buffers
            _setDreqCallback(_fillAudioFifo.bindenv(this));
        }
    }
    
    function _uartCb(flags) {
        rx_buffer.writeblob(uart.readblob());
        if (rx_buffer.tell() > RX_WATERMARK) {
            // schedule the data ready callback to happen after we exit the UART callback 
            // so we don't block on it
            buffer_ready_cb(rx_buffer);
            rx_buffer = blob(2);
            rx_buffer.seek(0,'b');
        }
        // check flags
        if (flags & 0x40) { server.error("UART Overrun"); }
    }
    
    function getMode() {
        return _getReg(VS10XX_SCI_MODE);
    }
    
    function getStatus() {
        return _getReg(VS10XX_SCI_STATUS);
    }
    
    function getChipID() {
        return _readRam(VS10XX_CHIP_ID_ADDR, 2);
    }
    
    function getVersion() {
        return _readRam(VS10XX_VERSION_ADDR);
    }
    
    function getConfig1() {
        return _readRam(VS10XX_CONFIG1_ADDR);
    }
    
    function getHDAT0() {
        return _getReg(VS10XX_SCI_HDAT0);
    }
    
    function getHDAT1() {
        return _getReg(VS10XX_SCI_HDAT1);
    }
    
    function getAICTRL3() {
        return _getReg(VS10XX_SCI_AICTRL3);
    }
    
    function softReset() {
        _setRegBit(VS10XX_SCI_MODE, 2, 1);
        imp.sleep(0.002);
    }
    
    function setClockMultiplier(mult) {
        local mask = (mult * 2) << 12;
        local clockf_val = _getReg(VS10XX_SCI_CLOCKF);
        _setReg(VS10XX_SCI_CLOCKF, (clockf_val & 0x0FFF) | mask);
        return ((_getReg(VS10XX_SCI_CLOCKF) & 0xF000) >> 12) / 2;
    }
    
    function setVolume(left, right = null) {
        if (right == null) right = left;
        left = (-0.5 * left).tointeger();
        right = (-0.5 * right).tointeger();
        _setReg(VS10XX_SCI_VOL, ((left & 0xFF) << 8) | (right & 0xFF));
    }
    
    function queueData(data) {
        queued_buffers.insert(0, data);
        //server.log(format("Got buffer (%d buffers ready)",audioChunks.len()));
        if (!playback_in_progress) {
            playback_in_progress = true;
            // just loaded the first chunk (we quit on buffer underrun)
            // load a chunk from our in-memory buffer to start the VS10XX
            _loadData(queued_buffers.top().readblob(INITIAL_BYTES));
            // start the loop that keeps the data going into the FIFO
            _fillAudioFifo();
        }
    }
    
    function setSampleRate(samplerate) {
        if (samplerate < 8000) samplerate = 8000;
        if (samplerate > 48000) samplerate = 48000;
        _setReg(VS10XX_SCI_AICTRL0, samplerate & 0xFFFF);
    }
    
    function setRecordGain(gain) {
        if (gain < 1) gain = 1;
        if (gain > 64) gain = 64;
        _setReg(VS10XX_SCI_AICTRL1, (gain * 1024) & 0xFFFF);
    }
    
    function setRecordAGC(state, max) {
        if (state) {
            _setReg(VS10XX_SCI_AICTRL1, 0x0000);
            if (max > 64) max = 64;
            if (max < 1) max = 1;
            _setReg(VS10XX_SCI_AICTRL2, (max * 1024) & 0xFFFF);
        } else {
            setRecordGain(1);
        }
    }
    
    function setRecordInputMic() {
        _setRegBit(VS10XX_SCI_MODE, 14, 0);
    }
    
    function setRecordInputLine() {
        _setRegBit(VS10XX_SCI_MODE, 14, 1);
    }
    
    function setChJointStereo() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // bits 2 to 0 determine the ADC setting
        // 0b000 = joint stereo (shared AGC)
        _setReg(VS10XX_SCI_AICTRL3, val & 0xFFF8);
    }
    
    function setChDual() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b001 = dual (independent AGC)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0001);
    }
    
    function setChLeft() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b010 = left (set to this for Mic)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0002);
    }
    
    function setChRight() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b011 = right (line in only)
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0003);
    }
    
    function setChDownmix() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b100 = stereo downmix to mono
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFFF8) | 0x0004);
    }
    
    function setRecordFormatPCM() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // bits 4 to 7 determine the encoding format
        // 0b0001 = PCM
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0010);
    }
    
    function setRecordFormatULaw() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0010 = u-law
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0020);
    }
    
    function setRecordFormatALaw() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0011 = a-law
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0030);
    }
    
    function setRecordFormatOgg() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        // 0b0101 = Ogg Vorbis
         _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0050);
    }

    function setRecordFormatMP3() {
        local val = _getReg(VS10XX_SCI_AICTRL3);
        //server.log(format("setting VS10XX_SCI_AICTRL3 from 0x%04X to 0x%04X", val, (val & 0xFF0F) | 0x0060));
        // 0b0110 = MP3
        _setReg(VS10XX_SCI_AICTRL3, (val & 0xFF0F) | 0x0060);
    }
    
    function setRecordBitrate(rate_kbps) {
        // Bits 15:14 set VBR / CBR / ABR. Only VBR used here. Only applies to MP3 and Ogg Vorbis.
        // Bits 13:12 set bitrate multiplier, which is fixed at 1000 here.
        _setReg(VS10XX_SCI_WRAMADDR, (0x6000 | (rate_kbps & 0x01FF)));
        //server.log(format("Writing 0x%04X to WRAMADDR",(0x6000 | (rate_kbps & 0x01FF))));
        //server.log(format("Read back from WRAMADDR: 0x%04X",_getReg(VS10XX_SCI_WRAMADDR)));
    }
    
    function setUartBaud(baud) {
        // set UART clock divider to 0 to use "byte speed" to set UART baud
        _writeRam(VS10XX_TX_UART_DIV_ADDR, 0);
        // "Byte Speed" in the datasheet apparently means "baud / bits (incl start, stop, and parity bits)"
        _writeRam(VS10XX_TX_UART_BYTE_SPEED_ADDR, baud / 10);
        // disable flow control (*shrug*)
        _writeRam(VS10XX_TX_PAUSE_GPIO_ADDR, 0);
        // configure the imp side of this mess
        uart.configure(baud, 8, PARITY_NONE, 2, NO_CTSRTS | CALLBACK_WITH_FLAGS, _uartCb.bindenv(this));
    }
    
    function setUartTxEn(state) {
        if (state) {
            _setRegBit(VS10XX_SCI_AICTRL3, 13, 1);
        } else {
            _setRegBit(VS10XX_SCI_AICTRL3, 13, 0);
        }
    }
    
    function startRecording() {
        local val = _getReg(VS10XX_SCI_MODE); 
        // set the Encoding and SW_Reset bits in the same transaction to activate codec mode
        _setReg(VS10XX_SCI_MODE, val | 0x1004);
    }
    
    function stopRecording(cb) {
        // set SM_CANCEL bit
        _setRegBit(VS10XX_SCI_MODE, 3, 1);
        imp.wakeup(REC_STOP_TIMEOUT, function() {
            rx_buffer.writeblob(uart.readblob());
            buffer_ready_cb(rx_buffer);
            rx_buffer = blob(2);
            rx_buffer.seek(0,'b');
            cb();
        }.bindenv(this));
    }
    
    function recordingIsDone() {
        // Check SM_ENCODE bit to see if we're done encoding
        if (_getReg(VS10XX_SCI_MODE) & 0x1000) return false;
        return true;
    }
}

function requestBuffer() {
    agent.send("pull", 0);
}

function sendBuffer(buffer) {
    agent.send("push", buffer);
}

function record() {
    // set up VS10XX recording settings
    audio.setSampleRate(SAMPLERATE_HZ);
    audio.setRecordInputMic();
    audio.setChLeft();
    audio.setRecordFormatALaw();
    //audio.setRecordFormatOgg();
    audio.setRecordAGC(1, MAX_GAIN);
    audio.setUartBaud(UARTBAUD);
    audio.setUartTxEn(1);
    // have to load bitrate *after* setting up UART
    // bitrate lives in the reg we use to set RAM addr during r/w
    // need to r/w RAM to configure UART; do that first
    //audio.setRecordBitrate(BITRATE_KBPS);
    imp.wakeup(RECORD_TIME, function() {
        audio.stopRecording(function() {
            agent.send("recording_done", 0);
        });
    }.bindenv(this));
    server.log("Starting Recording...");
    audio.startRecording();
}

/* AGENT CALLBACKS -----------------------------------------------------------*/

// queue data from the agent in memory to be fed to the VS10XX
agent.on("push", function(chunk) {
    audio.queueData(chunk);
});

/* RUNTIME START -------------------------------------------------------------*/

imp.enableblinkup(true);
server.log("Running "+imp.getsoftwareversion());
server.log("Memory Free: "+imp.getmemoryfree());

spi     <- hardware.spi257;
cs_l    <- hardware.pin6;
dcs_l   <- hardware.pinC;
rst_l   <- hardware.pinE;
dreq_l  <- hardware.pinD;
uart    <- hardware.uart1289;

cs_l.configure(DIGITAL_OUT, 1);
dcs_l.configure(DIGITAL_OUT, 1);
rst_l.configure(DIGITAL_OUT, 1);
dreq_l.configure(DIGITAL_IN);
spi.configure(CLOCK_IDLE_LOW, SPICLK_LOW);

audio <- VS10XX(spi, cs_l, dcs_l, dreq_l, rst_l, uart, requestBuffer, sendBuffer);
server.log(format("VS10XX Clock Multiplier set to %d",audio.setClockMultiplier(VS10XX_CLOCK_MULT)));
spi.configure(CLOCK_IDLE_LOW, SPICLK_HIGH);
server.log(format("Imp SPI Clock set to %0.3f MHz", SPICLK_HIGH / 1000.0));
server.log(format("VS10XX Chip ID: 0x%08X",audio.getChipID()));
server.log(format("VS10XX Version: 0x%04X",audio.getVersion()));
server.log(format("VS10XX Config1: 0x%04X",audio.getConfig1()));
audio.setVolume(VOLUME);
server.log(format("Volume set to %0.1f dB", VOLUME));

// our callback passes data straight to the agent
// if the TCP buffer is smaller than the buffer to be sent, agent.send will block
// this will cause UART overruns. So we need to increase the send buffer size.
imp.setsendbuffersize(SEND_BUFFER_SIZE);

imp.wakeup(1.0, record);
