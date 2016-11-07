#define VERSION "0.0.3"

#define BAUD_RATE 115200
#define DELAY_WRITE 50

#define MASK_OP 0xF0
#define OP_CONFIGURE 0x80
#define OP_DIGITAL_READ 0x90
#define OP_DIGITAL_WRITE_0 0xA0
#define OP_DIGITAL_WRITE_1 0xB0
#define OP_ANALOG 0xC0
#define OP_ARB 0xD0
#define OP_CALL0 0xE0
#define OP_CALL1 0xF0

#define MASK_CONFIG 0x0F
#define CONFIG_INPUT 0x00
#define CONFIG_INPUT_PULLUP 0x01
#define CONFIG_OUTPUT 0x02
#define CONFIG_OUTPUT_PWM 0x03

#define MASK_DIGITAL_ADDR 0x0F
#define MASK_DIGITAL_WRITE 0x10
#define MASK_ANALOG_W 0x08
#define MASK_ANALOG_ADDR 0x07
#define MASK_CALL 0x1F

const int PWM_PINMAP[6] = {3, 5, 6, 9, 10, 11};

unsigned int rxByte = 0;
unsigned int rxOp = 0;
char rxbuffer[1024];
int rxbufferindex = 0;

// ========== USER-DEFINED FUNCTIONS ========== //
char* function01(char* buf) {
  // Send back data from the Arduino
  Serial.print(millis());
  return "";
}
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

void setup() {
    Serial.begin(BAUD_RATE);
    Serial.print("Impeeduino Version: ");
    Serial.println(VERSION);
    Serial.write(OP_CALL0);
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
                if (rxByte & MASK_ANALOG_W) {
                    int addr = rxByte & MASK_ANALOG_ADDR;
                    // Wait for value bytes to arrive
                    while(Serial.available() < 2);
                    // Lowest order bits (3-0)
                    char value = Serial.read() & 0x0F;
                    // Higest order bits (7-4)
                    value = value | ((Serial.read() & 0x0F) << 4);
                    //Serial.write(value);
                    analogWrite(PWM_PINMAP[addr], value);
                } else {
                    Serial.write(rxByte);
                    int analogvalue = analogRead(rxByte & MASK_ANALOG_ADDR);
                    // Lowest order bits (3-0)
                    Serial.write(OP_ARB | (analogvalue & 0x0F));
                    // Middle bits (7-4)
                    Serial.write(OP_ARB | ((analogvalue >> 4) & 0x0F));
                    // Highest order bits (9-8)
                    Serial.write(OP_ARB | ((analogvalue >> 8) & 0x0F));
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
                // Call Function Op: 111X
                rxbuffer[rxbufferindex] = '\0';
                switch (rxByte & MASK_CALL) {
                case 0x00: Serial.write(rxbuffer); break;
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

