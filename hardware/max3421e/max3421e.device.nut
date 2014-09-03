
// -----------------------------------------------------------------------------
// USB Host Shield pinouts
//
// 1 - 
// 2 - MISO - SPI output
// 5 - SCLK - SPI clock
// 6 - TP1 - Test point 1 (not connected)
// 7 - MOSI - SPI input
// 8 - LED1 - Green LED 
// 9 - LED2 - Green LED
// A - CS_L - SPI cable select
// B - RES_L - USB Reset
// C - INT - USB Interrupt (input)
// D - 
// E - TP2 - Test point 2 (not connected)
//
// Maxim's product page
// http://www.maximintegrated.com/en/products/interface/controllers-expanders/MAX3421E.html
// 
// A really good USB primer
// http://www.beyondlogic.org/usbnutshell/usb5.shtml - The descriptors
// http://www.beyondlogic.org/usbnutshell/usb6.shtml - The packet structure
// http://www.usbmadesimple.co.uk/index.html
//
// Some of the official specs
// http://www.usb.org/developers/devclass_docs/
// http://www.usb.org/developers/hidpage/ 
// http://www.usb.org/developers/devclass_docs/HID1_11.
//
// Some vaguely useful source code. Much of this code was inspired by 
// https://github.com/felis/USB_Host_Shield_2.0/
//
// Notes:
// 
// While this code functions well, it needs a good clean up. It was written as part of an 
// exploration of the MAX3421e chip but without much knowledge about the chip and about the
// USB protocol.
//
// This code supports standard keyboard and mouse devices but only one at a time. 
//
// Hubs are not supported and this code will not function if a hub is connected.
// 
// I have some code that will extend this class for use with an FTDI cable or other 
// equivalent devices that use Bulk Transfer mode. But it is not ready yet.
//

// -----------------------------------------------------------------------------
function max_constants() {
    
    // From max3421e.h
    
    // MAX3421E command byte format: rrrrr0wa where 'r' is register number
    //
    // MAX3421E Registers in HOST mode.
    //
    const rRCVFIFO     = 0x08    //1<<3
    const rSNDFIFO     = 0x10    //2<<3
    const rSUDFIFO     = 0x20    //4<<3
    const rRCVBC       = 0x30    //6<<3
    const rSNDBC       = 0x38    //7<<3
    
    const rUSBIRQ      = 0x68    //13<<3
    // USBIRQ Bits  
    const bmVBUSIRQ    = 0x40    //b6
    const bmNOVBUSIRQ  = 0x20    //b5
    const bmOSCOKIRQ   = 0x01    //b0
    
    const rUSBIEN      = 0x70    //14<<3
    // USBIEN Bits  
    const bmVBUSIE     = 0x40    //b6
    const bmNOVBUSIE   = 0x20    //b5
    const bmOSCOKIE    = 0x01    //b0
    
    const rUSBCTL      = 0x78    //15<<3
    // USBCTL Bits  
    const bmCHIPRES    = 0x20    //b5
    const bmPWRDOWN    = 0x10    //b4
    
    const rCPUCTL      = 0x80    //16<<3
    // CPUCTL Bits  
    const bmPUSLEWID1  = 0x80    //b7
    const bmPULSEWID0  = 0x40    //b6
    const bmIE         = 0x01    //b0
    
    const rPINCTL      = 0x88    //17<<3
    // PINCTL Bits  
    const bmFDUPSPI    = 0x10    //b4
    const bmINTLEVEL   = 0x08    //b3
    const bmPOSINT     = 0x04    //b2
    const bmGPXB       = 0x02    //b1
    const bmGPXA       = 0x01    //b0
    // GPX pin selections
    const GPX_OPERATE  = 0x00
    const GPX_VBDET    = 0x01
    const GPX_BUSACT   = 0x02
    const GPX_SOF      = 0x03
    
    const rREVISION    = 0x90    //18<<3
    
    const rIOPINS1     = 0xa0    //20<<3
    
    // IOPINS1 Bits 
    const bmGPOUT0     = 0x01
    const bmGPOUT1     = 0x02
    const bmGPOUT2     = 0x04
    const bmGPOUT3     = 0x08
    const bmGPIN0      = 0x10
    const bmGPIN1      = 0x20
    const bmGPIN2      = 0x40
    const bmGPIN3      = 0x80
    
    const rIOPINS2     = 0xa8    //21<<3
    // IOPINS2 Bits 
    const bmGPOUT4     = 0x01
    const bmGPOUT5     = 0x02
    const bmGPOUT6     = 0x04
    const bmGPOUT7     = 0x08
    const bmGPIN4      = 0x10
    const bmGPIN5      = 0x20
    const bmGPIN6      = 0x40
    const bmGPIN7      = 0x80
    
    const rGPINIRQ     = 0xb0    //22<<3
    // GPINIRQ Bits 
    const bmGPINIRQ0  = 0x01
    const bmGPINIRQ1  = 0x02
    const bmGPINIRQ2  = 0x04
    const bmGPINIRQ3  = 0x08
    const bmGPINIRQ4  = 0x10
    const bmGPINIRQ5  = 0x20
    const bmGPINIRQ6  = 0x40
    const bmGPINIRQ7  = 0x80
    
    const rGPINIEN     = 0xb8    //23<<3
    // GPINIEN Bits 
    const bmGPINIEN0  = 0x01
    const bmGPINIEN1  = 0x02
    const bmGPINIEN2  = 0x04
    const bmGPINIEN3  = 0x08
    const bmGPINIEN4  = 0x10
    const bmGPINIEN5  = 0x20
    const bmGPINIEN6  = 0x40
    const bmGPINIEN7  = 0x80
    
    const rGPINPOL     = 0xc0    //24<<3
    // GPINPOL Bits 
    const bmGPINPOL0  = 0x01
    const bmGPINPOL1  = 0x02
    const bmGPINPOL2  = 0x04
    const bmGPINPOL3  = 0x08
    const bmGPINPOL4  = 0x10
    const bmGPINPOL5  = 0x20
    const bmGPINPOL6  = 0x40
    const bmGPINPOL7  = 0x80
    
    const rHIRQ        = 0xc8    //25<<3
    // HIRQ Bits 
    const bmBUSEVENTIRQ    = 0x01   // indicates BUS Reset Done or BUS Resume
    const bmRWUIRQ         = 0x02
    const bmRCVDAVIRQ      = 0x04
    const bmSNDBAVIRQ      = 0x08
    const bmSUSDNIRQ       = 0x10
    const bmCONDETIRQ      = 0x20
    const bmFRAMEIRQ       = 0x40
    const bmHXFRDNIRQ      = 0x80
    
    const rHIEN			 = 0xd0    //26<<3
    
    // HIEN Bits 
    const bmBUSEVENTIE     = 0x01
    const bmRWUIE          = 0x02
    const bmRCVDAVIE       = 0x04
    const bmSNDBAVIE       = 0x08
    const bmSUSDNIE        = 0x10
    const bmCONDETIE       = 0x20
    const bmFRAMEIE        = 0x40
    const bmHXFRDNIE       = 0x80
    
    const rMODE			 = 0xd8    //27<<3
    
    // MODE Bits 
    const bmHOST           = 0x01
    const bmLOWSPEED       = 0x02
    const bmHUBPRE         = 0x04
    const bmSOFKAENAB      = 0x08
    const bmSEPIRQ         = 0x10
    const bmDELAYISO       = 0x20
    const bmDMPULLDN       = 0x40
    const bmDPPULLDN       = 0x80
    
    const rPERADDR     = 0xe0    //28<<3
    
    const rHCTL        = 0xe8    //29<<3
    // HCTL Bits 
    const bmBUSRST         = 0x01
    const bmFRMRST         = 0x02
    const bmSAMPLEBUS      = 0x04
    const bmSIGRSM         = 0x08
    const bmRCVTOG0        = 0x10
    const bmRCVTOG1        = 0x20
    const bmSNDTOG0        = 0x40
    const bmSNDTOG1        = 0x80
    
    const rHXFR        = 0xf0    //30<<3
    // Host transfer token values for writing the HXFR register (R30)   
    // OR this bit field with the endpoint number in bits 3:0               
    const tokSETUP   = 0x10  // HS=0, ISO=0, OUTNIN=0, SETUP=1
    const tokIN      = 0x00  // HS=0, ISO=0, OUTNIN=0, SETUP=0
    const tokOUT     = 0x20  // HS=0, ISO=0, OUTNIN=1, SETUP=0
    const tokINHS    = 0x80  // HS=1, ISO=0, OUTNIN=0, SETUP=0
    const tokOUTHS   = 0xA0  // HS=1, ISO=0, OUTNIN=1, SETUP=0
    const tokISOIN   = 0x40  // HS=0, ISO=1, OUTNIN=0, SETUP=0
    const tokISOOUT  = 0x60  // HS=0, ISO=1, OUTNIN=1, SETUP=0
    
    const rHRSL        = 0xf8    //31<<3
    
    // HRSL Bits 
    const bmRCVTOGRD   = 0x10
    const bmSNDTOGRD   = 0x20
    const bmKSTATUS    = 0x40
    const bmJSTATUS    = 0x80
    const bmSE0        = 0x00    //SE0 - disconnect state
    const bmSE1        = 0xc0    //SE1 - illegal state
    
    // Host error result codes, the 4 LSB's in the HRSL register 
    const hrSUCCESS    = 0x00
    const hrBUSY       = 0x01
    const hrBADREQ     = 0x02
    const hrUNDEF      = 0x03
    const hrNAK        = 0x04
    const hrSTALL      = 0x05
    const hrTOGERR     = 0x06
    const hrWRONGPID   = 0x07
    const hrBADBC      = 0x08
    const hrPIDERR     = 0x09
    const hrPKTERR     = 0x0A
    const hrCRCERR     = 0x0B
    const hrKERR       = 0x0C
    const hrJERR       = 0x0D
    const hrTIMEOUT    = 0x0E
    const hrBABBLE     = 0x0F
    
    // I am not sure what these are yet
    const SE0     = 0
    const SE1     = 1
    const FSHOST  = 2
    const LSHOST  = 3
}

function usb_constants() {
    // From usb_ch9.h
            
    // Misc.USB constants 
    const DEV_DESCR_LEN   = 18      //device descriptor length
    const CONF_DESCR_LEN  = 9       //configuration descriptor length
    const INTR_DESCR_LEN  = 9       //interface descriptor length
    const EP_DESCR_LEN    = 7       //endpoint descriptor length
    
    // Standard Device Requests 
    
    const USB_REQUEST_GET_STATUS                  = 0       // Standard Device Request - GET STATUS
    const USB_REQUEST_CLEAR_FEATURE               = 1       // Standard Device Request - CLEAR FEATURE
    const USB_REQUEST_SET_FEATURE                 = 3       // Standard Device Request - SET FEATURE
    const USB_REQUEST_SET_ADDRESS                 = 5       // Standard Device Request - SET ADDRESS
    const USB_REQUEST_GET_DESCRIPTOR              = 6       // Standard Device Request - GET DESCRIPTOR
    const USB_REQUEST_SET_DESCRIPTOR              = 7       // Standard Device Request - SET DESCRIPTOR
    const USB_REQUEST_GET_CONFIGURATION           = 8       // Standard Device Request - GET CONFIGURATION
    const USB_REQUEST_SET_CONFIGURATION           = 9       // Standard Device Request - SET CONFIGURATION
    const USB_REQUEST_GET_INTERFACE               = 10      // Standard Device Request - GET INTERFACE
    const USB_REQUEST_SET_INTERFACE               = 11      // Standard Device Request - SET INTERFACE
    const USB_REQUEST_SYNCH_FRAME                 = 12      // Standard Device Request - SYNCH FRAME
    
    const USB_FEATURE_ENDPOINT_HALT               = 0       // CLEAR/SET FEATURE - Endpoint Halt
    const USB_FEATURE_DEVICE_REMOTE_WAKEUP        = 1       // CLEAR/SET FEATURE - Device remote wake-up
    const USB_FEATURE_TEST_MODE                   = 2       // CLEAR/SET FEATURE - Test mode
    
    // Setup Data Constants 
    
    const USB_SETUP_HOST_TO_DEVICE                = 0x00    // Device Request bmRequestType transfer direction - host to device transfer
    const USB_SETUP_DEVICE_TO_HOST                = 0x80    // Device Request bmRequestType transfer direction - device to host transfer
    const USB_SETUP_TYPE_STANDARD                 = 0x00    // Device Request bmRequestType type - standard
    const USB_SETUP_TYPE_CLASS                    = 0x20    // Device Request bmRequestType type - class
    const USB_SETUP_TYPE_VENDOR                   = 0x40    // Device Request bmRequestType type - vendor
    const USB_SETUP_RECIPIENT_DEVICE              = 0x00    // Device Request bmRequestType recipient - device
    const USB_SETUP_RECIPIENT_INTERFACE           = 0x01    // Device Request bmRequestType recipient - interface
    const USB_SETUP_RECIPIENT_ENDPOINT            = 0x02    // Device Request bmRequestType recipient - endpoint
    const USB_SETUP_RECIPIENT_OTHER               = 0x03    // Device Request bmRequestType recipient - other
    
    // USB descriptors  
    
    const USB_DESCRIPTOR_DEVICE           = 0x01    // bDescriptorType for a Device Descriptor.
    const USB_DESCRIPTOR_CONFIGURATION    = 0x02    // bDescriptorType for a Configuration Descriptor.
    const USB_DESCRIPTOR_STRING           = 0x03    // bDescriptorType for a String Descriptor.
    const USB_DESCRIPTOR_INTERFACE        = 0x04    // bDescriptorType for an Interface Descriptor.
    const USB_DESCRIPTOR_ENDPOINT         = 0x05    // bDescriptorType for an Endpoint Descriptor.
    const USB_DESCRIPTOR_DEVICE_QUALIFIER = 0x06    // bDescriptorType for a Device Qualifier.
    const USB_DESCRIPTOR_OTHER_SPEED      = 0x07    // bDescriptorType for a Other Speed Configuration.
    const USB_DESCRIPTOR_INTERFACE_POWER  = 0x08    // bDescriptorType for Interface Power.
    const USB_DESCRIPTOR_OTG              = 0x09    // bDescriptorType for an OTG Descriptor.
    
    const HID_DESCRIPTOR_HID			= 0x21
    
    
    
    // OTG SET FEATURE Constants    
    const OTG_FEATURE_B_HNP_ENABLE                = 3       // SET FEATURE OTG - Enable B device to perform HNP
    const OTG_FEATURE_A_HNP_SUPPORT               = 4       // SET FEATURE OTG - A device supports HNP
    const OTG_FEATURE_A_ALT_HNP_SUPPORT           = 5       // SET FEATURE OTG - Another port on the A device supports HNP
    
    // USB Endpoint Transfer Types  
    const USB_TRANSFER_TYPE_CONTROL               = 0x00    // Endpoint is a control endpoint.
    const USB_TRANSFER_TYPE_ISOCHRONOUS           = 0x01    // Endpoint is an isochronous endpoint.
    const USB_TRANSFER_TYPE_BULK                  = 0x02    // Endpoint is a bulk endpoint.
    const USB_TRANSFER_TYPE_INTERRUPT             = 0x03    // Endpoint is an interrupt endpoint.
    const bmUSB_TRANSFER_TYPE                     = 0x03    // bit mask to separate transfer type from ISO attributes
    
    
    // Standard Feature Selectors for CLEAR_FEATURE Requests    
    const USB_FEATURE_ENDPOINT_STALL              = 0       // Endpoint recipient
    const USB_FEATURE_DEVICE_REMOTE_WAKEUP        = 1       // Device recipient
    const USB_FEATURE_TEST_MODE                   = 2       // Device recipient
    

    // From UsbCore.h
    
    // Common setup data constant combinations  
    // bmREQ_GET_DESCR    = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_STANDARD|USB_SETUP_RECIPIENT_DEVICE     //get descriptor request type
    // bmREQ_SET          = USB_SETUP_HOST_TO_DEVICE|USB_SETUP_TYPE_STANDARD|USB_SETUP_RECIPIENT_DEVICE     //set request type for all but 'set feature' and 'set interface'
    // bmREQ_CL_GET_INTF  = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_CLASS|USB_SETUP_RECIPIENT_INTERFACE     //get interface request type
    
    // D7		data transfer direction (0 - host-to-device, 1 - device-to-host)
    // D6-5		Type (0- standard, 1 - class, 2 - vendor, 3 - reserved)
    // D4-0		Recipient (0 - device, 1 - interface, 2 - endpoint, 3 - other, 4..31 - reserved)
    
    // USB Device Classes
    const USB_CLASS_USE_CLASS_INFO		= 0x00	// Use Class Info in the Interface Descriptors
    const USB_CLASS_AUDIO				= 0x01	// Audio
    const USB_CLASS_COM_AND_CDC_CTRL	= 0x02	// Communications and CDC Control
    const USB_CLASS_HID					= 0x03	// HID
    const USB_CLASS_PHYSICAL			= 0x05	// Physical
    const USB_CLASS_IMAGE				= 0x06	// Image
    const USB_CLASS_PRINTER				= 0x07	// Printer
    const USB_CLASS_MASS_STORAGE		= 0x08	// Mass Storage
    const USB_CLASS_HUB					= 0x09	// Hub
    const USB_CLASS_CDC_DATA			= 0x0a	// CDC-Data
    const USB_CLASS_SMART_CARD			= 0x0b	// Smart-Card
    const USB_CLASS_CONTENT_SECURITY	= 0x0d	// Content Security
    const USB_CLASS_VIDEO				= 0x0e	// Video
    const USB_CLASS_PERSONAL_HEALTH		= 0x0f	// Personal Healthcare
    const USB_CLASS_DIAGNOSTIC_DEVICE	= 0xdc	// Diagnostic Device
    const USB_CLASS_WIRELESS_CTRL		= 0xe0	// Wireless Controller
    const USB_CLASS_MISC				= 0xef	// Miscellaneous
    const USB_CLASS_APP_SPECIFIC		= 0xfe	// Application Specific
    const USB_CLASS_VENDOR_SPECIFIC		= 0xff	// Vendor Specific
    
    // Additional Error Codes
    const USB_DEV_CONFIG_ERROR_DEVICE_NOT_SUPPORTED		= 0xD1
    const USB_DEV_CONFIG_ERROR_DEVICE_INIT_INCOMPLETE	= 0xD2
    const USB_ERROR_UNABLE_TO_REGISTER_DEVICE_CLASS		= 0xD3
    const USB_ERROR_OUT_OF_ADDRESS_SPACE_IN_POOL		= 0xD4
    const USB_ERROR_HUB_ADDRESS_OVERFLOW				= 0xD5
    const USB_ERROR_ADDRESS_NOT_FOUND_IN_POOL			= 0xD6
    const USB_ERROR_EPINFO_IS_NULL						= 0xD7
    const USB_ERROR_INVALID_ARGUMENT					= 0xD8
    const USB_ERROR_CLASS_INSTANCE_ALREADY_IN_USE		= 0xD9
    const USB_ERROR_INVALID_MAX_PKT_SIZE				= 0xDA
    const USB_ERROR_EP_NOT_FOUND_IN_TBL					= 0xDB
    const USB_ERROR_CONFIG_REQUIRES_ADDITIONAL_RESET    = 0xE0
    const USB_ERROR_FailGetDevDescr                     = 0xE1
    const USB_ERROR_FailSetDevTblEntry                  = 0xE2
    const USB_ERROR_FailGetConfDescr                    = 0xE3
    const USB_ERROR_TRANSFER_TIMEOUT					= 0xFF
    
    const USB_XFER_TIMEOUT		= 10000 //30000    // (5000) USB transfer timeout in milliseconds, per section 9.2.6.1 of USB 2.0 spec
    //const USB_NAK_LIMIT		= 32000   //NAK limit for a transfer. 0 means NAKs are not counted
    const USB_RETRY_LIMIT		= 3       // 3 retry limit for a transfer
    const USB_SETTLE_DELAY		= 200     //settle delay in milliseconds
    
    const USB_NUMDEVICES		= 16	//number of USB devices
    //const HUB_MAX_HUBS		= 7	// maximum number of hubs that can be attached to the host controller
    const HUB_PORT_RESET_DELAY	= 20	// hub port reset delay 10 ms recomended, can be up to 20 ms
    
    // USB state machine states 
    const USB_STATE_MASK                                      = 0xf0
    const USB_STATE_DETACHED                                  = 0x10
    const USB_DETACHED_SUBSTATE_INITIALIZE                    = 0x11
    const USB_DETACHED_SUBSTATE_WAIT_FOR_DEVICE               = 0x12
    const USB_DETACHED_SUBSTATE_ILLEGAL                       = 0x13
    const USB_ATTACHED_SUBSTATE_SETTLE                        = 0x20
    const USB_ATTACHED_SUBSTATE_RESET_DEVICE                  = 0x30
    const USB_ATTACHED_SUBSTATE_WAIT_RESET_COMPLETE           = 0x40
    const USB_ATTACHED_SUBSTATE_WAIT_SOF                      = 0x50
    const USB_ATTACHED_SUBSTATE_WAIT_RESET                    = 0x51
    const USB_ATTACHED_SUBSTATE_GET_DEVICE_DESCRIPTOR_SIZE    = 0x60
    const USB_STATE_ADDRESSING                                = 0x70
    const USB_STATE_CONFIGURING                               = 0x80
    const USB_STATE_RUNNING                                   = 0x90
    const USB_STATE_ERROR                                     = 0xa0

    // Made just for Squirrel from usb_ch9.h
    const USB_DEVICE_DESCRIPTOR_SIZE = 18;
    const USB_CONFIGURATION_DESCRIPTOR_SIZE = 9;
    const USB_INTERFACE_DESCRIPTOR_SIZE = 9;
    const USB_STRING_DESCRIPTOR_SIZE = 2;
}

function hid_constants() {

    /* HID Interface Class Protocol Codes */
    const HID_PROTOCOL_NONE                      = 0x00
    const HID_PROTOCOL_KEYBOARD                  = 0x01
    const HID_PROTOCOL_MOUSE                     = 0x02

    /* Class-Specific Requests */
    const HID_REQUEST_GET_REPORT   = 0x01
    const HID_REQUEST_GET_IDLE     = 0x02
    const HID_REQUEST_GET_PROTOCOL = 0x03
    const HID_REQUEST_SET_REPORT   = 0x09
    const HID_REQUEST_SET_IDLE     = 0x0A
    const HID_REQUEST_SET_PROTOCOL = 0x0B

    const UHS_HID_BOOT_KEY_ZERO          = 0x27
    const UHS_HID_BOOT_KEY_ENTER         = 0x28
    const UHS_HID_BOOT_KEY_SPACE         = 0x2c
    const UHS_HID_BOOT_KEY_CAPS_LOCK     = 0x39
    const UHS_HID_BOOT_KEY_SCROLL_LOCK   = 0x47
    const UHS_HID_BOOT_KEY_NUM_LOCK      = 0x53
    const UHS_HID_BOOT_KEY_ZERO2         = 0x62
    const UHS_HID_BOOT_KEY_PERIOD        = 0x63

    
}

function trace(str, label = "") {
    
    if (label == "CONFIG") {
    
        if (str == null) return;
        
        server.log("/================================")
        foreach (k,v in str) {
            if (typeof v == "array") {
                // This is a config array
                server.log(format("+-- configs"))
                foreach (k0,v0 in v) {
                    // This is a config descriptor
                    server.log(format("| +-- config.%d", k0))
                    foreach (k1,v1 in v0) {
                        if (typeof v1 == "array") {
                            // This is an interface array
                            server.log(format("|   +-- interfaces"))
                            foreach (k2,v2 in v1) {
                                // This is an interface descriptor
                                server.log(format("|     +-- interface.%d", k2))
                                foreach (k3,v3 in v2) {
                                    if (typeof v3 == "array") {
                                        // This is an endpoint array
                                        server.log(format("|       +-- endpoints"))
                                        foreach (k4,v4 in v3) {
                                            // This is an endpoint discriptor
                                            server.log(format("|         +-- endpoint.%d", k4))
                                            foreach (k5,v5 in v4) {
                                                if (typeof v5 == "string" || typeof v5 == "mbstring") {
                                                    server.log(format("|           +-- enddescr.%s = '%s'", k5, v5.tostring()))
                                                } else {
                                                    server.log(format("|           |-- enddescr.%s = 0x%02X", k5, v5))
                                                }  
                                            }
                                        }
                                    } else if (typeof v3 == "string" || typeof v3 == "mbstring") {
                                        server.log(format("|       |-- intdescr.%s = '%s'", k3, v3.tostring()))
                                    } else {
                                        server.log(format("|       |-- intdescr.%s = 0x%02X", k3, v3))
                                    }
                                }
                            }
                        } else if (typeof v1 == "string" || typeof v1 == "mbstring") {
                            server.log(format("|   | confdescr.%s = '%s'", k1, v1.tostring()))
                        } else {
                            server.log(format("|   | confdescr.%s = 0x%02X", k1, v1))
                        }
                    }
                }
            } else if (typeof v == "string" || typeof v == "mbstring") {
                server.log(format("| devdescr.%s = '%s'", k, v.tostring()))
            } else {
                server.log(format("| devdescr.%s = 0x%02X", k, v))
            }
        }
        server.log("\\================================")
        
        
        
        return;
    }
    
    
    if (typeof str == "mbstring") str = str.tostring();
    if (typeof str == "string" || typeof str == "blob") {
        if (str.len() == 0) {
            local dbg;
            if (label) dbg = format("%s (%s): (null)", label, typeof str); 
            else dbg = "(null)";
            server.log(dbg);
        } else {
            local hex = "", asc = "";
            for (local i = 0; i < str.len(); i++) {
                local ch = str[i];
                hex += format("%02X ", ch);
                if (ch >= 32 && ch <= 126) {
                    asc += format("%c", ch);
                } else {
                    asc += ".";
                }
                if ((i+1) % 16 == 0) {
                    server.log(format("%48s   %16s", hex, asc));
                    hex = ""; asc = "";
                }
            }
            if (hex != "") {
                server.log(format("%-48s   %-16s", hex, asc));
                server.log("--^^-----------[ " + label + " ]-----------^^--");
            }
        }
    }
    if (typeof str == "integer") {
        local dbg;
        if (label) dbg = format("%s (%s): 0x%02X", label, typeof str, str); 
        server.log(dbg);
    }
    
}



// -----------------------------------------------------------------------------
class mbstring {
    
    _str = null;
    
    constructor(str = "") {
        _str = [];
        
        switch (typeof str) {
            case "string": 
            case "blob":
                // Perfect
                break;
            case "integer":
                str = format("%d", str);
                break;
            case "float":
                str = format("%f", str);
                break;
            case "mbstring":
            case "array":
                foreach (ch in str) {
                    _str.push(ch);
                }
                return;
            default:
                throw format("Can't convert from '%s' to mbstring", typeof str);
        }
        
        for (local i = 0; i < str.len(); i++) {
            local ch1 = (str[i] & 0xFF);
            if ((ch1 & 0x80) == 0x00) {
                // 0xxxxxxx = 7 bit ASCII
                _str.push(format("%c", ch1));
            } else if ((ch1 & 0xE0) == 0xC0) {
                // 110xxxxx = 2 byte unicode
                local ch2 = (str[++i] & 0xFF);
                _str.push(format("%c%c", ch1, ch2));
            } else if ((ch1 & 0xF0) == 0xE0) {
                // 1110xxxx = 3 byte unicode   
                local ch2 = (str[++i] & 0xFF);
                local ch3 = (str[++i] & 0xFF);
                _str.push(format("%c%c%c", ch1, ch2, ch3));
            } else if ((ch1 & 0xF8) == 0xF0) {
                // 11110xxx = 4 byte unicode
                local ch2 = (str[++i] & 0xFF);
                local ch3 = (str[++i] & 0xFF);
                local ch4 = (str[++i] & 0xFF);
                _str.push(format("%c%c%c%c", ch1, ch2, ch3, ch4));
            }
        }
    }
    
    function _typeof() {
        return "mbstring";
    }
    
    function _add(op) {
        local new_str = mbstring(_str);
        foreach (ch in op) {
            new_str._str.push(ch);
        }
        return new_str;
    }
    
    function _cmp(other) {
        for (local i = 0; i < _str.len(); i++) {
            if (i < other._str.len()) {
                local ch1 = _str[i];
                local ch2 = other._str[i];
                if (ch1 > ch2) return 1;
                else if (ch1 < ch2) return -1;
            }
        }
        return _str.len() <=> other.len();
    }
    
    function _nexti(previdx) {
        if (_str.len() == 0) return null;
        else if (previdx == null) return 0;
        else if (previdx == _str.len()-1) return null;
        else return previdx+1;
    }
    
    function _get(idx) {
        if (typeof idx == "integer") {
            return _str[idx];
        } else {
            return ::getroottable()[idx];
        }
    }
    
    function _set(idx, val) {
        throw "mbstrings are immutable";
    }
    
    function tolatin() {
        local str = "";
        foreach (ch in _str) {
            local lch = ch[ch.len()-1];
            if (lch > 0x00) str += lch.tochar();
        }
        return str;
    }

    function tointeger() {
        return tolatin().tointeger();
    }
    
    function tofloat() {
        return tolatin().tofloat();
    }
    
    function tostring() {
        return tolatin();
    }
    
    function len() {
        return _str.len();
    }
    
    function slice(start, end = null) {
        local sliced = null;
        if (end == null) sliced = _str.slice(start)
        else             sliced = _str.slice(start, end)
        return mbstring(sliced);
    }
    
    function find(substr, startidx = null) {
        if (typeof substr != "mbstring") {
            substr = mbstring(substr);
        }
        if (startidx == null) startidx = 0;
        else if (startidx < 0) startidx = _str.len() + startidx;
        
        local match = null;
        local length = null;
        for (local i = startidx; i < _str.len() && i+substr.len() <= _str.len(); i++) {

            match = i;
            length = null;
            for (local j = 0; j < substr.len() && i+j < _str.len(); j++) {
                if (_str[i+j] != substr[j]) break;
                length = j+1;
            }
            
            // Check if we have a match
            if (match != null && length == substr.len()) {
                return match;
            }
        }
        
        return null;
    }
    
}


// -----------------------------------------------------------------------------
class MAX3421E {
    
    _spi = null;
    _cs_l = null;
    _rst_l = null;
    _int = null;
    
    _cb_connected = null;
    
    _running = false;
    _config = null;
    
    constructor(spi, cs_l, rst_l, int) {

        _spi = spi;
        _cs_l = cs_l;
        _rst_l = rst_l;
        _int = int;
        
        _spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 15000);
        _cs_l.configure(DIGITAL_OUT); _cs_l.write(1);
        _rst_l.configure(DIGITAL_OUT); _rst_l.write(1);
        _int.configure(DIGITAL_IN, interrupt.bindenv(this));
        
        max_constants();
        hard_reset();
        init();
        
    }
    
    function hard_reset() {
        _rst_l.write(0);
        imp.sleep(0.1);
        _rst_l.write(1);
    }
    
    function regRd(register, bytes = null) {
        
        _cs_l.write(0);
        _spi.write(register.tochar());
        local readBlob = _spi.readblob(bytes == null ? 1 : bytes);
        _cs_l.write(1);

        if (bytes == null) return readBlob[0];
        else return readBlob;
    }
    
    function bytesRd(register, bytes = 1) {
        return regRd(register, bytes);
    }

    function regWr(register, data) {
        local result = null;
        _cs_l.write(0);
        _spi.write((register | 0x02).tochar());
        if (typeof data == "integer") {
            result = _spi.write(data.tochar()) == 1;
        } else {
            result = _spi.write(data) == data.len();
        }
        _cs_l.write(1);
        
        return result;
    }
    
    function bytesWr(register, bytes, data) {
        return regWr(register, data);
    }

    function regRdWr(register, data, mask=0xFF) {
        local r = regRd(register);
        local w = (r & ~mask) | (data & mask);
        server.log(format("Register: 0x%02X, Data: 0x%02X, Mask: 0x%02X => Inital Value: 0x%02X => New Value: 0x%02X", register,data,mask,r,w));
        return regWr( register, w );
    }

    function init() {
        assert(regWr(rPINCTL, bmFDUPSPI | bmPOSINT)); // Full duplix SPI, edge-active, rising edges
        assert(chip_reset() != 0);
        assert(regWr(rMODE, bmDPPULLDN | bmDMPULLDN | bmHOST)); // set pull-downs, Host
        assert(regWr(rHIEN, bmCONDETIE | bmFRAMEIE)); //connection detection

        // check if device is connected 
        assert(regWr(rHCTL, bmSAMPLEBUS)); // sample USB bus
        while(!(regRd(rHCTL) & bmSAMPLEBUS)); //wait for sample operation to finish
        local probe_result = busprobe();

        regWr(rHIRQ, bmCONDETIRQ); //clear connection detect interrupt
        regWr(rCPUCTL, 0x01); //enable interrupt pin

        // Force the interrupt callback if the device is already connected
        if (probe_result == LSHOST || probe_result == FSHOST) {
            local lowspeed = (probe_result == LSHOST);
            imp.wakeup(0, function() {
                if (_cb_connected) {    
                    busreset(lowspeed);
                    _cb_connected(true, _config, lowspeed);
                }
            }.bindenv(this))
        }
    }
    
    function chip_reset() {
        assert(regWr(rUSBCTL, bmCHIPRES));
        assert(regWr(rUSBCTL, 0x00));
        local i = 0;
        while (++i) {
            if ((regRd(rUSBIRQ) & bmOSCOKIRQ)) {
                break;
            }
        }
        return i;
    }
    
    function busprobe() {
        
        local vbusState = null;
        local bus_sample = regRd(rHRSL); //Get J,K status
        bus_sample = bus_sample & (bmJSTATUS | bmKSTATUS); //zero the rest of the byte
        switch (bus_sample) { //start full-speed or low-speed host
            case bmJSTATUS:
                if((regRd(rMODE) & bmLOWSPEED) == 0) {
                    regWr(rMODE, bmDPPULLDN|bmDMPULLDN|bmHOST|bmSOFKAENAB); //start full-speed host
                    vbusState = FSHOST;
                } else {
                    regWr(rMODE, bmDPPULLDN|bmDMPULLDN|bmHOST|bmLOWSPEED|bmSOFKAENAB); //start low-speed host
                    vbusState = LSHOST;
                }
                break;
            case bmKSTATUS:
                if((regRd(rMODE) & bmLOWSPEED) == 0) {
                    regWr(rMODE, bmDPPULLDN|bmDMPULLDN|bmHOST|bmLOWSPEED|bmSOFKAENAB); //start low-speed host
                    vbusState = LSHOST;
                } else {
                    regWr(rMODE, bmDPPULLDN|bmDMPULLDN|bmHOST|bmSOFKAENAB); //start full-speed host
                    vbusState = FSHOST;
                }
                break;
            case bmSE1: //illegal state
                vbusState = SE1;
                server.error("Detected illegal host state");
                break;
            case bmSE0: //disconnected state
                regWr(rMODE, bmDPPULLDN | bmDMPULLDN | bmHOST | bmSEPIRQ);
                vbusState = SE0;
                break;
            default:
                server.error("Unknown bus state: " + bus_sample);
        }
        
        return vbusState;
    }
    
    function busreset(lowspeed) {
        
        // Let the bus settle
        imp.sleep(USB_SETTLE_DELAY / 1000.0);

        //issue bus reset
        regWr(rHCTL, bmBUSRST); 
        
        // Wait for a response
        while ((regRd(rHCTL) & bmBUSRST) != 0); 
        local tmpdata = regRd(rMODE) | bmSOFKAENAB; //start SOF generation
        regWr(rMODE, tmpdata);

        // when first SOF received _and_ 20ms has passed we can continue
        while ((regRd(rHIRQ) & bmFRAMEIRQ) == 0);
        imp.sleep(0.03);
        
        // Configure
        configuring(0, 0, lowspeed);
    }
    
    function interrupt(force = false) {
        // Rising edge
        if (force || _int.read() == 1) {
            local probe_result = null;
            local HIRQ_sendback = 0;
            local HIRQ = regRd(rHIRQ); //determine interrupt source
            if (HIRQ & bmCONDETIRQ) {
                probe_result = busprobe();
                HIRQ_sendback = HIRQ_sendback | bmCONDETIRQ;
            }
            
            // End HIRQ interrupts handling, clear serviced IRQs
            regWr(rHIRQ, HIRQ_sendback);

            // Call the registered callback if the state has changed
            local state_change = (probe_result != null);
            local connected = (probe_result != 0);
            local lowspeed = (probe_result == LSHOST);
            if (state_change && _cb_connected) {
                if (connected != _running) {
                    busreset(lowspeed);
                    _cb_connected(connected, _config, lowspeed);
                } 
                if (!connected) _running = false;
            }
        }
    }
    
    function revision() {
        local rev = regRd(rREVISION);
        return rev;
    }
    
    function configuring(parent, port, lowspeed) {
        
        _config = getDevDescr(0, 0)
        _running = (_config != null);
        if (_running) {
            // trace(_config, "CONFIG");
            server.log(lowspeed ? "Running at low speed" : "Running at full speed");
        }
    }
    
    function on_connected(callback) {
        _cb_connected = callback;
    }
    
    function is_running() {
        return _running;
    }
}


// -----------------------------------------------------------------------------
class USB extends MAX3421E {
    
    // Stores the toggle values for each endpoint
    toggles = null;
    lastAddrEp = null;

    // These should be constants
    bmREQ_GET_DESCR    = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_STANDARD|USB_SETUP_RECIPIENT_DEVICE     //get descriptor request type
    bmREQ_SET          = USB_SETUP_HOST_TO_DEVICE|USB_SETUP_TYPE_STANDARD|USB_SETUP_RECIPIENT_DEVICE     //set request type for all but 'set feature' and 'set interface'
    bmREQ_CL_GET_INTF  = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_CLASS|USB_SETUP_RECIPIENT_INTERFACE     //get interface request type
    
    
    constructor(spi, cs_l, rst_l, int) {

        base.constructor(spi, cs_l, rst_l, int);
        usb_constants();
        toggles = {};
        
    }

    function init() {
        base.init();
    }
    
    function SetAddress(addr, ep) {
        
        // Backup the toggle bits
        local curAddrEp = format("%d:%d", addr, ep&0x0F);
        if (lastAddrEp != null && lastAddrEp != curAddrEp) {
            local oldtoggle = regRd(rHRSL) & (bmRCVTOGRD | bmSNDTOGRD);
            local newtoggle = ((oldtoggle & bmRCVTOGRD) ? bmRCVTOG1 : bmRCVTOG0)
                            | ((oldtoggle & bmSNDTOGRD) ? bmSNDTOG1 : bmSNDTOG0);
            toggles[lastAddrEp] <- newtoggle;
            // server.log(format("*** Storing toggles 0x%02X for ep %s", toggles[lastAddrEp], lastAddrEp))
        }
        
        //set peripheral address
        regWr(rPERADDR, addr); 

        // Set bmLOWSPEED and bmHUBPRE in case of low-speed device, reset them otherwise
        local mode = regRd(rMODE);
        local lowspeed = (mode & 0x02) == 0x02;
        local bmHubPre = 0; // Not supporting hubs, so this should remain 0 for now
        regWr(rMODE, lowspeed ? (mode | bmLOWSPEED | bmHubPre) : (mode & ~(bmHUBPRE | bmLOWSPEED)));
        
        // Set the toggles, if required
        local newToggles = 0x00;
        if (curAddrEp == "0:0") {

            newToggles = bmRCVTOG1 | bmSNDTOG1;
            // server.log(format("*** Initialising toggles to 0x%02X for ep %s", newToggles, curAddrEp))

        } else if ((curAddrEp != lastAddrEp) && !(curAddrEp in toggles)) {
            
            // Set the new toggle bits
            newToggles = bmRCVTOG0 | bmSNDTOG0;
            // server.log(format("*** Initialising toggles to 0x%02X for ep %s", newToggles, curAddrEp))
            
        } else if ((lastAddrEp != curAddrEp) && (curAddrEp in toggles)) {
            
            // Restore the previous toggle bits for this AddrEp
            newToggles = toggles[curAddrEp];
            // server.log(format("*** Restoring toggles 0x%02X for ep %s", newToggles, curAddrEp))
            
        } 
        
        if (newToggles != 0x00) {
            // Now set the new toggles, if we have them
            regWr(rHCTL, newToggles);
        }
        lastAddrEp = curAddrEp;  
    }
    
    function ctrlReq(addr, ep, bmReqType, bRequest, wValLo, wValHi, wInd, total = 0, nBytes = null, data = null) {

        // Control transfer. Sets address, endpoint, fills control packet with necessary data, 
        // dispatches control packet, and initiates bulk IN transfer, depending on request. 
        SetAddress(addr, ep);
        local is_in_transfer = (bmReqType & 0x80) != 0;

        // fill in setup packet
        local setup_pkt = format("%c%c%c%c%c%c%c%c",
                                    bmReqType & 0xFF,
                                    bRequest & 0xFF,
                                    wValLo & 0xFF, wValHi & 0xFF,
                                    wInd & 0xFF, (wInd >> 8) & 0xFF, 
                                    total & 0xFF, (total >> 8) & 0xFF
                                    );
        assert(regWr(rSUDFIFO, setup_pkt)); //transfer to setup packet FIFO
        // trace(setup_pkt, "SETUP");

        // dispatch packet
        if (dispatchPkt(tokSETUP, ep) != 0) return false;
        
        local alldata = null;
        if (is_in_transfer) {
            // Get me some data
            if (nBytes == null) nBytes = total;
            // server.log("ctrlReq is requesting " + total + " bytes in " + nBytes + " byte chunks");
            
            alldata = blob(total);
            do {
                local alldata_before = alldata.tell();
                local rcode = inTransfer(addr, ep, alldata, nBytes, 8)
                // server.log("ctrlReq received " + alldata.tell() + " of " + total + " bytes")
                
                // Check if we have anything reasonable back.
                local nBytesRead = alldata.tell() - alldata_before;
                if (nBytesRead < nBytes) {
                    server.error(format("ctrlReq requested %d bytes but only read %d, error code = 0x%02X", nBytes, nBytesRead, rcode));
                    break;
                }
                if (rcode != hrSUCCESS) return;
                
            } while (alldata.tell() < total);
            alldata.resize(alldata.tell());
            
            // Clear the in fifo
            inClear(addr, ep);
            
        } else {
            // Send my data please
            if (data && data.len() > 0) outTransfer(addr, ep, data);
        }
        // if (alldata) trace(alldata, "RESPONSE");
        
        // Status stage
        local status = dispatchPkt(is_in_transfer ? tokOUTHS : tokINHS, ep); //GET if direction is inbound
        
        // Return the results
        return is_in_transfer ? alldata : status;
        
    }
    
    function dispatchPkt(token, ep) {
        
        local nak_limit = 10; // This should be calculated in SetAddress
        local rcode = hrSUCCESS, nak_count = 0, retry_count = 0;
        local timeout = hardware.millis() + USB_XFER_TIMEOUT;
        
        while (hardware.millis() < timeout) {
            
            //launch the transfer
            assert(regWr(rHXFR, (token | ep))); 
            rcode = USB_ERROR_TRANSFER_TIMEOUT;
            
            //wait for confirmation of arrival
            while (hardware.millis() < timeout) {
                if (regRd(rHIRQ) & bmHXFRDNIRQ) {
                    //clear the interrupt
                    regWr(rHIRQ, bmHXFRDNIRQ); 
                    rcode = hrSUCCESS;
                    break;
                }
            }
            
            // Abort if we have a timeout
            if (rcode == USB_ERROR_TRANSFER_TIMEOUT) {
                return rcode;
            }
            
            //analyze the result
            rcode = regRd(rHRSL) & 0x0F; 
            switch (rcode) {
                case hrNAK:
                    nak_count++;
                    if (nak_limit && (nak_count == nak_limit)) {
                        return rcode;
                    }
                    break;
                case hrTIMEOUT:
                    retry_count++;
                    if (retry_count == USB_RETRY_LIMIT) {
                        return rcode;
                    }
                    break;
                default:
                    return rcode;
            }
            
        }
        return rcode;
    }

    function inTransfer(addr, ep, data, nBytes=null, maxPktSize=null) {
        
        if (nBytes == null) nBytes = data.len();
        if (maxPktSize == null) maxPktSize = nBytes;
        
        local rcode = SetAddress(addr, ep);
        local left = nBytes;
        local epAddr = ep & 0x0F;
        
        while (true) {
            
            // Backup the current toggles for logging later
            local oldtoggle = regRd(rHRSL) & (bmRCVTOGRD|bmSNDTOGRD);
            local newtoggle = ((oldtoggle & bmRCVTOGRD) ? bmRCVTOG1 : bmRCVTOG0) | ((oldtoggle & bmSNDTOGRD) ? bmSNDTOG1 : bmSNDTOG0);
            
            // IN packet to EP-'endpoint'. 
            rcode = dispatchPkt(tokIN, epAddr); 
            if (rcode == hrTOGERR) {
                // server.error(format("Read toggle 0x%02X for ep %d:%d is ERROR", newtoggle, addr, ep&0x0F));
                continue;
            } else if (rcode == hrSUCCESS) {
                // server.error(format("Read toggle 0x%02X for ep %d:%d is OK", newtoggle, addr, ep&0x0F));
            } else if (rcode == hrNAK) {
                // server.log("NAK")
            } else {
                // server.error(format("inTransfer:dispatchPkt returned 0x%02X", rcode))
                break;
            }

            // check for RCVDAVIRQ and generate error if not present 
            // the only case when absence of RCVDAVIRQ makes sense is when toggle error occurred. Need to add handling for that 
            if ((regRd(rHIRQ) & bmRCVDAVIRQ) == hrSUCCESS) {
                rcode = 0xf0; //receive error
                break;
            }
            
            // number of bytes in the receive buffer
            local pktsize = regRd(rRCVBC); 
            if (pktsize > left) {
                // This can happen. So I will trim the value, and hope for the best.
                // server.error("Trimming packet size");
                pktsize = left;
            }

            // Read the data and add it to the buffer
            local newdata = bytesRd(rRCVFIFO, pktsize);

            // Clear the IRQ & free the buffer
            regWr(rHIRQ, bmRCVDAVIRQ); 

            // Record the new data
            if (data != null) data.writeblob(newdata);

            // The transfer is complete when left == 0.
            left -= newdata.len();
            // server.log(format("left (%d) <= 0 || pktsize (%d) < maxPktSize (%d) == %s", left, pktsize, maxPktSize, (left <= 0 || pktsize < maxPktSize).tostring()))

            if (left <= 0 || pktsize < maxPktSize) {
                // Save toggle value
                rcode = hrSUCCESS;
                break;
            }
        }
        
        return rcode;
    }
    
    function outTransfer(addr, ep, data, maxpktsize = 8) {

        local rcode = SetAddress(addr, ep), nak_limit = 10, nak_count = 0, retry_count = 0;
        local bytes_left = data.len();

        data.seek(0);        
        while (bytes_left > 0) {
            
            local bytes_tosend = (bytes_left >= maxpktsize) ? maxpktsize : bytes_left;
            local epAddr = ep & 0x0F;
            local timeout = hardware.millis() + USB_XFER_TIMEOUT;
            
            local sendbuf = blob(bytes_tosend);
            for (local i = 0; i < bytes_tosend; i++) {
                sendbuf.writen(data.readn('b'), 'b');
            }
        
            // Backup the old toggle value for later logging
            local oldtoggle = regRd(rHRSL) & (bmRCVTOGRD|bmSNDTOGRD);
            local newtoggle = ((oldtoggle & bmRCVTOGRD) ? bmRCVTOG1 : bmRCVTOG0) | ((oldtoggle & bmSNDTOGRD) ? bmSNDTOG1 : bmSNDTOG0);
            
            // Perform the write
            bytesWr(rSNDFIFO, bytes_tosend, sendbuf); // filling output FIFO
            regWr(rSNDBC, bytes_tosend);              // set number of bytes
            regWr(rHXFR, (tokOUT | epAddr));          // dispatch packet
            while(!(regRd(rHIRQ) & bmHXFRDNIRQ));     // wait for the completion IRQ
            regWr(rHIRQ, bmHXFRDNIRQ);                // clear IRQ

            // Check the result
            rcode = regRd(rHRSL) & 0x0F;
            if (rcode == hrSUCCESS) {
                // server.error(format("Send toggle 0x%02X for ep %d:%d is OK", newtoggle, addr, ep&0x0F));
            }
            
            while ((rcode != hrSUCCESS) && (timeout > hardware.millis())) {
                switch(rcode) {
                    case hrNAK:
                        nak_count++;
                        if (nak_limit && (nak_count == nak_limit)) {
                            return ( rcode);
                        }
                        break;
                    case hrTIMEOUT:
                        retry_count++;
                        if (retry_count == USB_RETRY_LIMIT) {
                            return ( rcode);
                        }
                        break;
                    case hrTOGERR:
                        // yes, we flip it wrong here so that next time it is actually correct!
                        // server.error(format("Send toggle 0x%02X for ep %d:%d is ERROR", newtoggle, addr, ep&0x0F));
                        break;
                    default:
                        return rcode;
                }//switch( rcode
    
                /* process NAK according to Host out NAK bug */
                regWr(rSNDBC, 0);
                regWr(rSNDFIFO, sendbuf[0]); // ??? regWr(rSNDFIFO, *data_p);
                regWr(rSNDBC, bytes_tosend);
                regWr(rHXFR, (tokOUT | epAddr)); //dispatch packet
                while(!(regRd(rHIRQ) & bmHXFRDNIRQ)); //wait for the completion IRQ
                regWr(rHIRQ, bmHXFRDNIRQ); //clear IRQ
                rcode = (regRd(rHRSL) & 0x0f);
            } //while( rcode && ....
            
            bytes_left -= bytes_tosend;
        } //while( bytes_left...

        return rcode;
        
    }

    
    function inClear(addr, ep) {
        // server.log("inClear()");
        local clear = blob(8);
        do {
            clear.seek(0);
            inTransfer(addr, ep, clear, 8, 8);
            if (clear.tell() == 0) return;
            trace(clear, "CLEAR");
        } while (true)
    }
    
    function getDevDescr(addr, ep) {
        
        local buf = ctrlReq(addr, ep, bmREQ_GET_DESCR, USB_REQUEST_GET_DESCRIPTOR, 0x00, USB_DESCRIPTOR_DEVICE, 0x0000, USB_DEVICE_DESCRIPTOR_SIZE);
        if (typeof buf != "blob") return null;
        if (buf.len() != USB_DEVICE_DESCRIPTOR_SIZE) return null;
        
        local devdescr = {};
        devdescr.bLength <- buf[0]; // Length of this descriptor.
        devdescr.bDescriptorType <- buf[1]; // DEVICE descriptor type (USB_DESCRIPTOR_DEVICE).
        devdescr.bcdUSB <- (buf[3] << 8) | (buf[2]); // USB Spec Release Number (BCD).
        devdescr.bDeviceClass <- buf[4]; // Class code (assigned by the USB-IF). 0xFF-Vendor specific.
        devdescr.bDeviceSubClass <- buf[5]; // Subclass code (assigned by the USB-IF).
        devdescr.bDeviceProtocol <- buf[6]; // Protocol code (assigned by the USB-IF). 0xFF-Vendor specific.
        devdescr.bMaxPacketSize0 <- buf[7]; // Maximum packet size for endpoint 0.
        devdescr.idVendor <- (buf[9] << 8) | (buf[8]); // Vendor ID (assigned by the USB-IF).
        devdescr.idProduct <- (buf[11] << 8) | (buf[10]); // Product ID (assigned by the manufacturer).
        devdescr.bcdDevice <- (buf[13] << 8) | (buf[12]); // Device release number (BCD).
        devdescr.iManufacturer <- buf[14]; // Index of String Descriptor describing the manufacturer.
        devdescr.iProduct <- buf[15]; // Index of String Descriptor describing the product.
        devdescr.iSerialNumber <- buf[16]; // Index of String Descriptor with the device's serial number.
        devdescr.bNumConfigurations <- buf[17]; // Number of possible configurations.

        devdescr.sManufacturer <- getStrDescr(addr, ep, devdescr.iManufacturer);
        devdescr.sProduct <- getStrDescr(addr, ep, devdescr.iProduct);
        devdescr.sSerialNumber <- getStrDescr(addr, ep, devdescr.iSerialNumber);
        
        devdescr.aConfigs <- [];
        for (local c = 0; c < devdescr.bNumConfigurations; c++) {
            local conf = getConfDescr(0, 0, c);
            if (conf) {
                devdescr.aConfigs.push(conf);
            }
        }
        
        return devdescr;
    }
 
    function getConfDescr(addr, ep, conf) {
        
        local buf = ctrlReq(addr, ep, bmREQ_GET_DESCR, USB_REQUEST_GET_DESCRIPTOR, conf, USB_DESCRIPTOR_CONFIGURATION, 0x0000, USB_CONFIGURATION_DESCRIPTOR_SIZE);
        if (typeof buf != "blob") return null;
        if (buf.len() != USB_CONFIGURATION_DESCRIPTOR_SIZE) return null;
        buf.seek(0);
        
        local confdescr = {};
        confdescr.bLength <- buf.readn('b'); // Length of this descriptor.
        confdescr.bDescriptorType <- buf.readn('b'); // CONFIGURATION descriptor type (USB_DESCRIPTOR_CONFIGURATION).
        confdescr.wTotalLength <- buf.readn('w'); // Total length of all descriptors for this configuration.
        confdescr.bNumInterfaces <- buf.readn('b'); // Number of interfaces in this configuration.
        confdescr.bConfigurationValue <- buf.readn('b'); // Value of this configuration (1 based).
        confdescr.iConfiguration <- buf.readn('b'); // Index of String Descriptor describing the configuration.
        confdescr.bmAttributes <-buf.readn('b'); // Configuration characteristics.
        confdescr.bMaxPower <- buf.readn('b'); // Maximum power consumed by this configuration.
        confdescr.sConfiguration <- getStrDescr(addr, ep, confdescr.iConfiguration);
        confdescr.aInterfaces <- [];
        

        // Now get the entire config descriptor which includes the interfaces and the endpoints
        if (confdescr.wTotalLength > confdescr.bLength) {
            local buf = ctrlReq(addr, ep, bmREQ_GET_DESCR, USB_REQUEST_GET_DESCRIPTOR, conf, USB_DESCRIPTOR_CONFIGURATION, 0x0000, confdescr.wTotalLength);
            if (typeof buf != "blob") return null;
            if (buf.len() != confdescr.wTotalLength) return null;
            // trace(buf, "BIG CONF");
            buf.seek(9);
            
            // Break out the interface and endpoint descriptors
            for (local i = 0; i < confdescr.bNumInterfaces; i++) {

                local bLength = buf.readn('b');
                local bDescriptorType = buf.readn('b');
                buf.seek(-2, 'c');
                if (bDescriptorType == 0x04) {

                    local intdescr = {};
                    intdescr.bLength <- buf.readn('b');
                    intdescr.bDescriptorType <- buf.readn('b');
                    intdescr.bInterfaceNumber <- buf.readn('b');
                    intdescr.bAlternateSetting <- buf.readn('b');
                    intdescr.bNumEndpoints <- buf.readn('b');
                    intdescr.bInterfaceClass <- buf.readn('b');
                    intdescr.bInterfaceSubClass <- buf.readn('b');
                    intdescr.bInterfaceProtocol <- buf.readn('b');
                    intdescr.iInterface <- buf.readn('b');
                    intdescr.sInterface <- getStrDescr(addr, ep, intdescr.iInterface);
                    intdescr.aEndPoints <- [];
                    
                    for (local e = 0; e < intdescr.bNumEndpoints; e++) {
                        local bLength = buf.readn('b');
                        local bDescriptorType = buf.readn('b');
                        buf.seek(-2, 'c');
                        if (bDescriptorType == 0x05) {
        
                            local enddescr = {};
                            enddescr.bLength <- buf.readn('b');
                            enddescr.bDescriptorType <- buf.readn('b');
                            enddescr.bEndpointAddress <- buf.readn('b');
                            enddescr.bmAttributes <- buf.readn('b');
                            enddescr.wMaxPacketSize <- buf.readn('w');
                            enddescr.bInterval <- buf.readn('b');
                            
                            intdescr.aEndPoints.push(enddescr);
                        } else {
                            // This is not an end point
                            server.error(format("Skipping configuration descriptor as it is not an end point: 0x%02X", bDescriptorType));
                            buf.seek(bLength, 'c');
                            e--;
                        }
                    }
                    
                    confdescr.aInterfaces.push(intdescr);
                    
                } else {
                    // This is not an interface
                    server.error(format("Skipping configuration descriptor as it is not an interface: 0x%02X", bDescriptorType));
                    buf.seek(bLength, 'c');
                    i--;
                }
            }
        }
        
        return confdescr;
    } 
    
    function getStrDescr(addr, ep, index, langid = 0x0409, previewLen = USB_STRING_DESCRIPTOR_SIZE) {

        if (index == 0 && langid != 0) return "(none)";
        
        // Read the length
        local buf = ctrlReq(addr, ep, bmREQ_GET_DESCR, USB_REQUEST_GET_DESCRIPTOR, index, USB_DESCRIPTOR_STRING, langid, previewLen);
        if (typeof buf != "blob" || buf.len() < 1) return "";
        local bLength = buf[0]; // Length of this descriptor.
        if (bLength <= 2) return "(none)";

        // Now read the whole lot
        local buf = ctrlReq(addr, ep, bmREQ_GET_DESCR, USB_REQUEST_GET_DESCRIPTOR, index, USB_DESCRIPTOR_STRING, langid, bLength);
        if (typeof buf != "blob" || buf.len() < 3) return "";

        local strdescr = {};
        strdescr.bLength <- buf[0]; // Length of this descriptor.
        strdescr.bDescriptorType <- buf[1]; // STRING descriptor type (USB_DESCRIPTOR_STRING).
        buf.seek(2);
        strdescr.bString <- mbstring(buf.readblob(strdescr.bLength));
        if (strdescr.bLength == 0) return "(unknown)";

        return strdescr.bString;
    }
    
    function setAddressAndConfig(addr, configuration) {
        
        // Set the address
        ctrlReq(0, 0, bmREQ_SET, USB_REQUEST_SET_ADDRESS, addr, 0x00, 0x0000);
        imp.sleep(0.3);
        
        // Remove the old toggle
        if ("0:0" in toggles) delete toggles["0:0"];
        
        // Set the configuration
        ctrlReq(addr, 0, bmREQ_SET, USB_REQUEST_SET_CONFIGURATION, configuration, 0x00, 0x0000, 0x0000, 0x0000);

    }

    
}


// -----------------------------------------------------------------------------
class HIDBoot {

    _usb = null;
    _poller = null;
    _drivers = null;
    _driver = null;
    _config = null;

    /* HID requests */
    bmREQ_HIDOUT      = USB_SETUP_HOST_TO_DEVICE|USB_SETUP_TYPE_CLASS|USB_SETUP_RECIPIENT_INTERFACE;
    bmREQ_HIDIN       = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_CLASS|USB_SETUP_RECIPIENT_INTERFACE;
    bmREQ_HIDREPORT   = USB_SETUP_DEVICE_TO_HOST|USB_SETUP_TYPE_STANDARD|USB_SETUP_RECIPIENT_INTERFACE;
        
    
    constructor(usb) {
        
        const POLL_RATE = 1;
        
        _usb = usb;
        _usb.on_connected(connect.bindenv(this))
        _drivers = [];
        _poller = imp.wakeup(POLL_RATE, poll.bindenv(this))

    }    
    
    function connect(connected, config, lowspeed) {
        if (connected && config) {
            _driver = null;
            _config = config;
            _usb.setAddressAndConfig(1, 1);

            // Find the right driver and throw the connect event
            foreach (driver in _drivers) {
                if (driver.match(_config)) {
                    _driver = driver;
                    _driver.connect(true, _config);
                    break;
                }
            }
            
            if (!_driver) {
                server.error("Failed to locate a matching driver");
            }
            
        } else if (_driver) {
            // Disconnect the driver
            _driver.connect(false);
            _driver = null;
            _config = null;
        }
    }
    
    function poll() {
        local interval = POLL_RATE;
        if (_driver && _usb.is_running()) {
            local i = _driver.poll();
            if (typeof i == "integer" || typeof i == "float") interval = i;
        }
        _poller = imp.wakeup(interval, poll.bindenv(this));
    }
    
    function register(driver) {
        _drivers.push(driver);
    }

    function setReport(addr, ep, iface, report_type, report_id, data) {
        return _usb.ctrlReq(addr, ep, bmREQ_HIDOUT, HID_REQUEST_SET_REPORT, report_id, report_type, iface, data.len(), data.len(), data);
    }
    
    
}


// -----------------------------------------------------------------------------
class HIDDriver {

    _hid = null;
    _registration = null;
    _poller_endpoint = null;
    _config = null;
    
    constructor(hid) {

        _hid = hid;
        register();
    }
    
    function register() {
        _hid.register(this);
    }
    
    function match(config) {
        return false;
    }

    function connect(connected, config=null) {
        server.log("Unhandled connect event")
    }
    
    function poll() {
        
    }

    function response(buf) {
        server.log("Unhandled response event")
    }
    
}


// -----------------------------------------------------------------------------
class Keyboard extends HIDDriver {

    _last_scan = null;
    _mods = null;

    _on_control_keys_changed = null;
    _on_key_down = null;
    _on_key_up = null;

    constructor(hid) {
        base.constructor(hid);
        _last_scan = blob(8);
        _mods = {num=false, caps=false, scroll=false};
    }
    
    
    function match(config) {
        
        if (!config || !("aConfigs" in config)) return false;
        if (config.aConfigs.len() == 0 || config.aConfigs[0].aInterfaces.len() == 0 || config.aConfigs[0].aInterfaces[0].aEndPoints.len() == 0) return false;
        
        foreach (intdescr in config.aConfigs[0].aInterfaces) {
            if (   intdescr.bInterfaceProtocol == HID_PROTOCOL_KEYBOARD
                && intdescr.bInterfaceClass == USB_CLASS_HID) {
                _poller_endpoint = config.aConfigs[0].aInterfaces[0].aEndPoints[0];
                return true;
            }
        }
        return false;
        
    }

    function connect(connected, config=null) {
        if (connected) {
            _config = config;
            for (local i = 0; i < _last_scan.len(); i++) _last_scan[i] = 0x00;
            _mods = {num=false, caps=false, scroll=false};
            animate_leds();
            server.log("Keyboard driver loaded")
        } else {
            _config = null;
            _poller_endpoint = null;
            server.log("Keyboard driver unloaded")
        }
    }
    
    function poll() {
        
        local bEndpointAddress = _poller_endpoint.bEndpointAddress;
        local wMaxPacketSize = _poller_endpoint.wMaxPacketSize;
        local data = blob(_config.bMaxPacketSize0);
        
        if (_hid._usb.inTransfer(1, bEndpointAddress, data, wMaxPacketSize, wMaxPacketSize) == hrSUCCESS) {
            response(data);
        }
        
        return _poller_endpoint.bInterval / 1000.0;
    }
    
    function response(buf) {
        
        if (buf.tostring() != _last_scan.tostring()) {
            // trace(buf, "POLL");
            parse(buf);
            _last_scan = clone buf;
        }

    }
    
    function parse(buf) {
        if (buf[2] == 0x01) return; // error
        if (buf[0] != _last_scan[0]) {
            // The modifier keys have changed
            if (_on_control_keys_changed) _on_control_keys_changed(_last_scan[0], buf[0]);
        }
        for (local i = 2; i < _last_scan.len(); i++) {
            local down = false, up = false;
            for (local j = 2; j < _last_scan.len(); j++) {
                if (buf[i] == _last_scan[j] && buf[i] != 0x01) down = true;
                if (buf[j] == _last_scan[i] && _last_scan[i] != 0x01) up = true;
            }
            if (!down) {
                // This key has been pressed
                local last_mods = clone _mods;
                switch (buf[i]) {
                    case UHS_HID_BOOT_KEY_NUM_LOCK:
                        _mods.num = !_mods.num;
                        break;
                    case UHS_HID_BOOT_KEY_CAPS_LOCK:
                        _mods.caps = !_mods.caps;
                        break;
                    case UHS_HID_BOOT_KEY_SCROLL_LOCK:
                        _mods.scroll = !_mods.scroll;
                        break;
                }
                if (_mods.num != last_mods.num || _mods.caps != last_mods.caps || _mods.scroll != last_mods.scroll) {
                    // Update the LED lights
                    set_leds();
                }
                if (_on_key_down) _on_key_down(buf[0], buf[i]);
            }
            if (!up) {
                // This key has been released
                if (_on_key_up) _on_key_up(buf[0], _last_scan[i]);
            }
        }
    }
    
    function animate_leds() {
        _mods = {num=true, caps=false, scroll=false};
        set_leds(); imp.sleep(0.05);
        _mods = {num=false, caps=true, scroll=false};
        set_leds(); imp.sleep(0.05);
        _mods = {num=false, caps=false, scroll=true};
        set_leds(); imp.sleep(0.05);
        _mods = {num=false, caps=false, scroll=false};
        set_leds(); 
    }
    
    function set_leds() {
        local _leds = blob(1);
        _leds[0] = 0x00;
        if (_mods.num) _leds[0] = _leds[0] | 0x01;
        if (_mods.caps) _leds[0] = _leds[0] | 0x02;
        if (_mods.scroll) _leds[0] = _leds[0] | 0x04;
        
        local addr = 1;
        _hid.setReport(addr, 0, 0, 2, 0, _leds);
    }
    
    function VALUE_WITHIN(val, min, max) {
        return val >= min && val <= max;
    }
    
    function oem_to_ascii(mod, key) {

        local shift = (mod & 0x22) != 0;

        // [a-z]
        if (VALUE_WITHIN(key, 0x04, 0x1d)) {
            // Upper case letters
            if ((!_mods.caps && shift) || (_mods.caps && !shift)) return (key - 0x04 + 'A');
            // Lower case letters
            else return (key - 0x04 + 'a');
        
        // Number bar
        } else if (VALUE_WITHIN(key, 0x1E, 0x27)) {
            if (shift)
                return ['!','@','#','$','%','^','&','*','(',')'][key - 0x1E];
            else
                return ((key == UHS_HID_BOOT_KEY_ZERO) ? '0' : key - 0x1E + '1');
        } else if (VALUE_WITHIN(key, 0x2D, 0x38)) {
            return shift ? ['_','+','{','}','|','~',':','"','~','<','>','?'][key - 0x2D] 
                         : ['-','=','[',']','\\','`',';','\'','`',',','.','/'][key - 0x2D];

        // Keypad Numbers
        } else if (VALUE_WITHIN(key, 0x59, 0x61)) {
            if (_mods.num) return (key - 0x59 + '1');
        } else if (VALUE_WITHIN(key, 0x54, 0x58)) {
            return ['/','*','-','+',0x13][key - 0x54];
        } else {
            switch(key) {
                case UHS_HID_BOOT_KEY_SPACE: return 0x20;
                case UHS_HID_BOOT_KEY_ENTER: return 0x13;
                case UHS_HID_BOOT_KEY_ZERO2: return _mods.num ? '0' : null;
                case UHS_HID_BOOT_KEY_PERIOD: return _mods.num ? '.' : null;
            }
        }
        return null;
    }
    
    function on_control_keys_changed(callback) {
        _on_control_keys_changed = callback;
    }
    function on_key_down(callback) {
        _on_key_down = callback;
    }
    function on_key_up(callback) {
        _on_key_up = callback;
    }


}


// -----------------------------------------------------------------------------
class Mouse extends HIDDriver {

    _last_scan = null;
    _buttons = null;

    _on_move = null;
    _on_scroll = null;
    _on_button_down = null;
    _on_button_up = null;

    constructor(hid) {
        base.constructor(hid);
        _last_scan = blob(4);
        _buttons = {left=false, right=false, middle=false};
    }
    
    
    function match(config) {

        if (!config || !("aConfigs" in config)) return false;
        if (config.aConfigs.len() == 0 || config.aConfigs[0].aInterfaces.len() == 0 || config.aConfigs[0].aInterfaces[0].aEndPoints.len() == 0) return false;
        
        foreach (intdescr in config.aConfigs[0].aInterfaces) {
            if (   intdescr.bInterfaceProtocol == HID_PROTOCOL_MOUSE
                && intdescr.bInterfaceClass == USB_CLASS_HID) {
                _poller_endpoint = config.aConfigs[0].aInterfaces[0].aEndPoints[0];
                return true;
            }
        }
        return false;
        
    }
    
    function connect(connected, config=null) {
        
        if (connected) {
            _config = config;
            for (local i = 0; i < _last_scan.len(); i++) _last_scan[i] = 0x00;
            _buttons = {left=false, right=false, middle=false};
            server.log("Mouse driver loaded")
        } else {
            _config = null;
            _poller_endpoint = null;
            server.log("Mouse driver unloaded")
        }

    }
    
    function poll() {
        
        local bEndpointAddress = _poller_endpoint.bEndpointAddress;
        local wMaxPacketSize = _poller_endpoint.wMaxPacketSize;
        local data = blob(_config.bMaxPacketSize0);
        
        if (_hid._usb.inTransfer(1, bEndpointAddress, data, wMaxPacketSize, wMaxPacketSize) == hrSUCCESS) {
            response(data);
        }
        
        return _poller_endpoint.bInterval / 1000.0;
    }
    
    function response(buf) {
        
        // trace(buf, "POLL");
        parse(buf);
        _last_scan = clone buf;

    }
    
    function parse(buf) {

        local left = (buf[0] & 0x01) == 0x01;
        local right = (buf[0] & 0x02) == 0x02;
        local middle = (buf[0] & 0x04) == 0x04;
        
        local last_buttons = clone _buttons;
        if (!last_buttons.left && left) if (_on_button_down) _on_button_down(1);
        if (last_buttons.left && !left) if (_on_button_up) _on_button_up(1);
        if (!last_buttons.right && right) if (_on_button_down) _on_button_down(2);
        if (last_buttons.right && !right) if (_on_button_up) _on_button_up(2);
        if (!last_buttons.middle && middle) if (_on_button_down) _on_button_down(3);
        if (last_buttons.middle && !middle) if (_on_button_up) _on_button_up(3);
        
        if (_last_scan[1] != buf[1] || _last_scan[2] != buf[2]) if (_on_move) {
            buf.seek(1);
            local dx = buf.readn('c');
            local dy = buf.readn('c');
            _on_move(dx, dy);
        }
        if (_last_scan[3] != 0x00) if (_on_scroll) {
            buf.seek(3);
            local scroll = buf.readn('c');
            _on_scroll(scroll);
        }
        
        _buttons = {left=left, right=right, middle=middle};
    }
    
    
    function on_move(callback) {
        _on_move = callback;
    }
    function on_scroll(callback) {
        _on_scroll = callback;
    }
    function on_button_down(callback) {
        _on_button_down = callback;
    }
    function on_button_up(callback) {
        _on_button_up = callback;
    }
    
}



// -----------------------------------------------------------------------------
spi <- hardware.spi257;
cs <- hardware.pinA;
reset <- hardware.pinB;
int <- hardware.pinC;
imp.enableblinkup(true);

// Load the main USB host controller and the HID interface
usb <- USB(spi, cs, reset, int);
hid <- HIDBoot(usb);


// Keyboard driver
keyboard <- Keyboard(hid);
keyboard.on_key_down(function(mod, key) {
    local asc = keyboard.oem_to_ascii(mod, key);
    if (asc != null) server.log(format("Key pressed: %c", asc))
    else server.log(format("Key pressed: 0x%02X, modifiers 0x%02X", key, mod))
})


// Mouse driver
mouse <- Mouse(hid);
mouse.on_move(function(x, y) {
    server.log("Move: " + x + ", " + y)  
})
mouse.on_scroll(function(dir) {
    server.log("Scroll: " + dir)
})
mouse.on_button_down(function(btn) {
    server.log("Down: " + btn)
})
mouse.on_button_up(function(btn) {
    server.log("Up: " + btn)
})

server.log("Imp USB host ready");
