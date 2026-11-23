# digispark-launcher

Digispark (ATtiny85) tak-çalıştır başlatıcısı için betik deposu.

Kart sabit bir firmware taşır; takılınca işletim sistemini seçtirir (Num Lock),
bir terminal açar ve buradaki **dağıtıcı** betiği çekip çalıştırır. İşlem mantığı
kartta değil, bu depodaki betiklerdedir — geliştirmeyi burada yaparsın, karta
dokunmadan.

## Akış

1. Dağıtıcı (`dispatch.ps1` / `dispatch.sh`) önce `ops/0`'ı çalıştırır.
2. Sonra döngüde `1-2-3` sorar (`q` = çıkış), seçilen `ops/<N>`'i çekip çalıştırır.

## Yapı

```
dispatch.ps1   Windows dağıtıcı (PowerShell)
dispatch.sh    Linux dağıtıcı (bash)
ops/0.*        takılınca otomatik çalışan işlem
ops/1.* 2.* 3.* döngüde seçilen işlemler
tests/         dispatch.sh birim testleri
```

## Geliştirme

- Bir işlemi değiştirmek: ilgili `ops/<N>.sh` ve/veya `ops/<N>.ps1` dosyasını düzenle, `main`'e it. Kart her çalıştığında güncel sürümü çeker.
- Windows için `.ps1`, Linux için `.sh` sürümünü birlikte güncel tut.

## Testler

```bash
bash tests/test_dispatch.sh
```

## Güvenlik

Bu depo **public**. Betiklere **asla** parola/token/anahtar yazma. Kart tak-anında
kod çalıştırır (BadUSB deseni); yalnızca kendi makinelerinde kullan.
