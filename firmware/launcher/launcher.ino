/*
 * Digispark Başlatıcı — sabit firmware.
 *
 * Takılınca:
 *   1) ~4 sn'lik seçim penceresinde onboard LED yanıp söner.
 *   2) Kullanıcı Num Lock'a basarak OS seçer:
 *        0 veya 1 basış -> Windows (varsayılan)
 *        2 (veya daha fazla) basış -> Linux
 *      (Kart, host'un LED raporundan basışı okur.)
 *   3) Seçime göre terminali açıp GitHub'daki dağıtıcıyı çeken komutu yazar.
 *
 * İşlem mantığı kartta DEĞİL; GitHub deposundaki betiklerde. Bu firmware sabit.
 *
 * KLAVYE DÜZENİ:
 *  - Windows yolu özel karakterleri (: / . - | ") Alt+numpad kodlarıyla yazar;
 *    bu yöntem klavye düzeninden BAĞIMSIZDIR (TR-Q dahil). Harf/rakam/boşluk
 *    TR-Q'da US ile aynı tuşlarda olduğundan normal yazılır. Alt-kod için
 *    NumLock açık olmalı; firmware gerekirse açar.
 *  - Linux yolu şu an US tablosuyla yazar (asıl hedef Windows). TR düzenli bir
 *    Linux MASAÜSTÜ hedefi olursa tuş haritası donanımda ölçülüp eklenmeli.
 */

#include "DigiKeyboard.h"

#define LED_PIN      1          // Digispark onboard LED (bazı klon kartlarda P0)
#define SELECT_MS    4000UL     // OS seçim penceresi süresi
#define ENUM_MS      1500UL     // USB numaralandırma için bekleme
#define NUMLOCK_BIT  0x01

// Keypad HID tarama kodları (Alt+numpad için)
#define KEY_KP_NUMLOCK 0x53
static const uchar KP_DIGIT[10] = {
  0x62, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61 // 0..9
};

// GitHub ham taban URL'i firmware'e gömülü. Depo adı sabit kalırsa firmware'e
// bir daha dokunmaya gerek yok.
static const char CMD_WIN[] =
  "powershell -NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex\"";

static const char CMD_LINUX[] =
  "curl -fsSL "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.sh | bash";

// --- düşük seviye: tek HID raporu gönder (modifier + tuş), Alt'ı basılı tutmak için ---
static void rawReport(uchar mod, uchar key) {
  while (!usbInterruptIsReady()) { usbPoll(); _delay_ms(2); }
  DigiKeyboard.reportBuffer[0] = mod;
  DigiKeyboard.reportBuffer[1] = key;
  usbSetInterrupt(DigiKeyboard.reportBuffer, 2);
  while (!usbInterruptIsReady()) { usbPoll(); _delay_ms(2); }
}

// NumLock kapalıysa aç (Alt+numpad için gerekli).
static void ensureNumLock() {
  for (uint8_t i = 0; i < 40; i++) { DigiKeyboard.update(); _delay_ms(5); }
  if (!(DigiKeyboard.getLEDs() & NUMLOCK_BIT)) {
    DigiKeyboard.sendKeyStroke(KEY_KP_NUMLOCK);
    for (uint8_t i = 0; i < 40; i++) { DigiKeyboard.update(); _delay_ms(5); }
  }
}

// Windows Alt-kodu: ALT basılı tutulurken numpad'den 0NNN yazılır (ANSI/CP1252).
static void altCode(unsigned char ascii) {
  char buf[5];
  // 4 haneli: 0 + 3 basamak (örn. ':' = 58 -> "0058")
  buf[0] = '0';
  buf[1] = '0' + (ascii / 100) % 10;
  buf[2] = '0' + (ascii / 10) % 10;
  buf[3] = '0' + ascii % 10;
  buf[4] = 0;
  for (uint8_t i = 0; buf[i]; i++) {
    uchar kp = KP_DIGIT[buf[i] - '0'];
    rawReport(MOD_ALT_LEFT, kp);   // tuş bas (ALT basılı)
    rawReport(MOD_ALT_LEFT, 0);    // tuş bırak (ALT hâlâ basılı)
  }
  rawReport(0, 0);                 // ALT bırak -> karakter üretilir
}

// Windows için düzen-bağımsız yazım: harf/rakam/boşluk normal, gerisi Alt-kod.
static void typeWin(const char* s) {
  for (const char* p = s; *p; p++) {
    char c = *p;
    bool safe = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                (c >= '0' && c <= '9') || c == ' ';
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

  // 1) USB numaralandırmasının oturması için bekle (LED raporları bundan sonra gelir).
  unsigned long t0 = millis();
  while (millis() - t0 < ENUM_MS) { DigiKeyboard.update(); DigiKeyboard.delay(5); }

  // 2) Seçim penceresi: Num Lock bit değişimlerini (basışları) say, LED'i oynat.
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

  // 3) Seçimi LED ile onayla: Linux = 2 kısa flaş, Windows = 1 uzun flaş.
  if (isLinux) {
    blinkConfirm(2);
  } else {
    digitalWrite(LED_PIN, HIGH); DigiKeyboard.delay(500); digitalWrite(LED_PIN, LOW);
  }

  DigiKeyboard.delay(600); // kullanıcı tuşu bıraksın, odak otursun

  if (isLinux) {
    // Odaklı bir terminal varsayılır (US tablo; TR Linux masaüstü için not'a bak).
    DigiKeyboard.print(CMD_LINUX);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  } else {
    // Win+R -> Çalıştır kutusu; komutu düzen-bağımsız yaz ve çalıştır.
    DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
    DigiKeyboard.delay(800);
    ensureNumLock();
    typeWin(CMD_WIN);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  }
}

void loop() {
  DigiKeyboard.update(); // boşta USB'yi canlı tut
}
