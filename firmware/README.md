# firmware — Digispark başlatıcı (sabit)

Takılınca OS seçtiren (Num Lock) ve terminal açıp GitHub'daki dağıtıcıyı
çeken sabit firmware. İşlem mantığı burada değil, `../ops/` ve `../dispatch.*`
içinde — bu firmware'e normalde bir daha dokunulmaz.

## İçerik

- `launcher/launcher.ino` — ana firmware.
- `DigisparkKeyboard/` — Digispark klavye kütüphanesi (V-USB), **LED okuma için
  yamalı**: host'un Num Lock durumunu kart okuyabilsin diye rapor tanımlayıcısına
  OUTPUT öğesi + `usbFunctionWrite` eklendi (`getLEDs()`).
- `flash.sh` — derle + yükle yardımcısı.

## Kurulum (sunucuda bir kez)

```bash
arduino-cli core install digistump:avr   # index: digistump GitHub aynası
```
> Not: ATTinyCore DEĞİL, **digistump:avr** çekirdeği kullanılır (eski gcc, bu
> V-USB kütüphanesiyle uyumlu). FQBN: `digistump:avr:digispark-tiny`.

## Yükleme

```bash
bash firmware/flash.sh
```
Komut "plug in device" deyince Digispark'ı **çıkarıp yeniden tak** (bootloader
penceresi ~5 sn). udev kuralı (`16d0:0753`) kurulu olduğundan sudo gerekmez.

## Davranış

1. Takınca ~4 sn LED yanıp söner (seçim penceresi).
2. Num Lock'a bas: 0/1 kez → Windows, 2 kez → Linux. Onay: Windows 1 uzun flaş,
   Linux 2 kısa flaş.
3. Windows'ta Win+R → PowerShell ile `dispatch.ps1`; Linux'ta odaklı terminale
   `dispatch.sh`.

## Klavye düzeni uyarısı

Firmware **US** tarama-kodu tablosuyla yazar. Hedef Windows **TR** düzendeyse
`: / . | "` yanlış çıkabilir. TR düzende kullanılacaksa TR tablosu eklenmeli.
