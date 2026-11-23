/*
 * Digispark Başlatıcı — sabit firmware.
 *
 * Takılınca:
 *   1) ~4 sn'lik seçim penceresinde onboard LED yanıp söner.
 *   2) Kullanıcı Num Lock'a basarak OS seçer:
 *        0 veya 1 basış -> Windows (varsayılan)
 *        2 (veya daha fazla) basış -> Linux
 *      (Kart, host'un tüm klavyelere yolladığı LED raporundan basışı okur.)
 *   3) Seçime göre terminali açıp GitHub'daki dağıtıcıyı çeken komutu yazar.
 *
 * İşlem mantığı kartta DEĞİL; GitHub deposundaki betiklerde. Bu firmware sabit.
 *
 * NOT (klavye düzeni): DigiKeyboard varsayılan US tarama-kodu tablosunu kullanır.
 * Hedef makinede Türkçe (TR) düzen varsa ': / . | "' gibi karakterler yanlış
 * yazılabilir. Donanım testinde doğrula; gerekirse TR tablosu eklenir.
 */

#include "DigiKeyboard.h"

#define LED_PIN      1          // Digispark onboard LED (bazı klon kartlarda P0)
#define SELECT_MS    4000UL     // OS seçim penceresi süresi
#define ENUM_MS      1500UL     // USB numaralandırma için bekleme
#define NUMLOCK_BIT  0x01

// GitHub ham taban URL'i firmware'e gömülü tek değişken. Depo adı sabit kalırsa
// bu firmware'e bir daha dokunmaya gerek yok.
static const char CMD_WIN[] =
  "powershell -NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex\"";

static const char CMD_LINUX[] =
  "curl -fsSL "
  "https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.sh | bash";

static bool done = false;

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
    digitalWrite(LED_PIN, ((millis() / 150) % 2) ? HIGH : LOW); // yavaş yanıp sönme
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

  // Kullanıcının Num Lock'tan elini çekmesi ve odağın oturması için kısa bekleme.
  DigiKeyboard.delay(600);

  if (isLinux) {
    // Odaklı bir terminal varsayılır; komutu yaz ve çalıştır.
    DigiKeyboard.print(CMD_LINUX);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  } else {
    // Win+R ile Çalıştır kutusunu aç, PowerShell komutunu yaz ve çalıştır.
    DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT);
    DigiKeyboard.delay(800);
    DigiKeyboard.print(CMD_WIN);
    DigiKeyboard.sendKeyStroke(KEY_ENTER);
  }

  done = true;
}

void loop() {
  // Tek sefer çalışır; sonrası boşta USB'yi canlı tut.
  DigiKeyboard.update();
  (void)done;
}
