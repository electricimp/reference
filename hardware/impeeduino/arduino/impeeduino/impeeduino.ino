#define VERSION "0.0.0"

#define DELAY_WRITE 50

#define MASK_OP 0xF0
#define OP_CONFIGURE 0x80
#define OP_DIGITAL_READ 0x90
#define OP_DIGITAL_WRITE_0 0xA0
#define OP_DIGITAL_WRITE_1 0xB0
#define OP_ANALOG 0xE0
#define OP_ARB 0xF0

#define MASK_CONFIG 0x0F
#define CONFIG_INPUT 0x00
#define CONFIG_INPUT_PULLUP 0x01
#define CONFIG_OUTPUT 0x02

#define MASK_DIGITAL_ADDR 0x0F
#define MASK_ANALOG_RW 0x08
#define MASK_ANALOG_ADDR 0x07
#define MASK_CALL 0x1F

unsigned int rxByte = 0;
unsigned int rxOp = 0;
char rxbuffer[128];
int rxbufferindex = 0;

char* function00(char* buf) { return buf; }
char* function01(char* buf) { return buf; }
char* function02(char* buf) { return buf; }
char* function03(char* buf) { return buf; }
char* function04(char* buf) { return buf; }
char* function05(char* buf) { return buf; }
char* function06(char* buf) { return buf; }
char* function07(char* buf) { return buf; }
char* function08(char* buf) { return buf; }
char* function09(char* buf) { return buf; }
char* function0A(char* buf) { return buf; }
char* function0B(char* buf) { return buf; }
char* function0C(char* buf) { return buf; }
char* function0D(char* buf) { return buf; }
char* function0E(char* buf) { return buf; }
char* function0F(char* buf) { return buf; }

char* function10(char* buf) { return buf; }
char* function11(char* buf) { return buf; }    
char* function12(char* buf) { return buf; }
char* function13(char* buf) { return buf; }
char* function14(char* buf) { return buf; }
char* function15(char* buf) { return buf; }
char* function16(char* buf) { return buf; }
char* function17(char* buf) { return buf; }
char* function18(char* buf) { return buf; }
char* function19(char* buf) { return buf; }
char* function1A(char* buf) { return buf; }
char* function1B(char* buf) { return buf; }
char* function1C(char* buf) { return buf; }
char* function1D(char* buf) { return buf; }
char* function1E(char* buf) { return buf; }
char* function1F(char* buf) { return buf; }


void setup() {
    // put your setup code here, to run once:
    Serial.begin(115200);
    Serial.print("Impeeduino Version: ");
    Serial.println(VERSION);
    Serial.flush();
}

void loop() {
    if (Serial.available()) {
        // get the new byte:
        
        rxByte = (char)Serial.read();
        if (rxByte & 0x80) {
            // Not ASCII text, attempt to decode opcode
            rxOp = rxByte & MASK_OP;
            if (rxOp == OP_DIGITAL_READ) {
                if (digitalRead(rxByte & MASK_DIGITAL_ADDR) == HIGH) {
                    //Serial.println("Digital HIGH");
                    Serial.write((rxByte & MASK_DIGITAL_ADDR) | OP_DIGITAL_WRITE_1); 
                } else {
                    //Serial.println("Digital LOW");
                    Serial.write((rxByte & MASK_DIGITAL_ADDR) | OP_DIGITAL_WRITE_0); 
                }
            } else if (rxOp == OP_DIGITAL_WRITE_0) {
                //Serial.println("Writing LOW");
                digitalWrite(rxByte & MASK_DIGITAL_ADDR, LOW);
                delay(DELAY_WRITE);
            } else if (rxOp == OP_DIGITAL_WRITE_1) {
                //Serial.println("Writing HIGH");
                digitalWrite(rxByte & MASK_DIGITAL_ADDR, HIGH);
                delay(DELAY_WRITE);
            } else if (rxOp == OP_ANALOG) {
                if (rxByte & MASK_ANALOG_RW) {
                    analogWrite(rxByte & MASK_ANALOG_ADDR, Serial.read());
                } else {
                    analogRead(rxByte & MASK_ANALOG_ADDR);
                    // return 10 bit val, TBD
                }
                
            } else if (rxOp == OP_CONFIGURE) {
                switch (Serial.read() & MASK_CONFIG) {
                case CONFIG_INPUT:
                    pinMode(rxByte & MASK_DIGITAL_ADDR, INPUT);
                    break;
                case CONFIG_INPUT_PULLUP:
                    pinMode(rxByte & MASK_DIGITAL_ADDR, INPUT_PULLUP);
                    break;
                case CONFIG_OUTPUT:
                    pinMode(rxByte & MASK_DIGITAL_ADDR, OUTPUT);
                    break;
                }
            } else if (rxOp == OP_ARB) {
                
            } else {
                // Call Function Op: 10X
                rxbuffer[rxbufferindex] = '\0';
                switch (rxByte & MASK_CALL) {
                case 0x00: Serial.write(function00(rxbuffer)); break;
                case 0x01: Serial.write(function01(rxbuffer)); break;
                case 0x02: Serial.write(function02(rxbuffer)); break;
                case 0x03: Serial.write(function03(rxbuffer)); break;
                case 0x04: Serial.write(function04(rxbuffer)); break;
                case 0x05: Serial.write(function05(rxbuffer)); break;
                case 0x06: Serial.write(function06(rxbuffer)); break;
                case 0x07: Serial.write(function07(rxbuffer)); break;
                case 0x08: Serial.write(function08(rxbuffer)); break;
                case 0x09: Serial.write(function09(rxbuffer)); break;
                case 0x0A: Serial.write(function0A(rxbuffer)); break;
                case 0x0B: Serial.write(function0B(rxbuffer)); break;
                case 0x0C: Serial.write(function0C(rxbuffer)); break;
                case 0x0D: Serial.write(function0D(rxbuffer)); break;
                case 0x0E: Serial.write(function0E(rxbuffer)); break;
                case 0x0F: Serial.write(function0F(rxbuffer)); break;
                                                           
                case 0x10: Serial.write(function10(rxbuffer)); break;
                case 0x11: Serial.write(function11(rxbuffer)); break;
                case 0x12: Serial.write(function12(rxbuffer)); break;
                case 0x13: Serial.write(function13(rxbuffer)); break;
                case 0x14: Serial.write(function14(rxbuffer)); break;
                case 0x15: Serial.write(function15(rxbuffer)); break;
                case 0x16: Serial.write(function16(rxbuffer)); break;
                case 0x17: Serial.write(function17(rxbuffer)); break;
                case 0x18: Serial.write(function18(rxbuffer)); break;
                case 0x19: Serial.write(function19(rxbuffer)); break;
                case 0x1A: Serial.write(function1A(rxbuffer)); break;
                case 0x1B: Serial.write(function1B(rxbuffer)); break;
                case 0x1C: Serial.write(function1C(rxbuffer)); break;
                case 0x1D: Serial.write(function1D(rxbuffer)); break;
                case 0x1E: Serial.write(function1E(rxbuffer)); break;
                case 0x1F: Serial.write(function1F(rxbuffer)); break;
                }
                Serial.write(rxByte);
                Serial.flush();
                rxbufferindex = 0;
            }
        } else {
            // Received ASCII text, insert into rxbuffer
            rxbuffer[rxbufferindex] = char(rxByte);
            rxbufferindex++;
        }
    }
}
