#!/usr/bin/env bash
# Digispark başlatıcı firmware'ini derleyip karta yükler.
# Kullanım: bash firmware/flash.sh
# İstendiğinde ("Please plug in the device") Digispark'ı çıkarıp yeniden tak.
#
# NOT: Bu kartın bootloader'ı yeni (Micronucleus 2.2). digistump çekirdeğinin
# paketlediği yükleyici (2.0a4) bunu tanımıyor; bu yüzden derlemeyi digistump
# gcc'si ile yapıp YÜKLEMEYİ ATTinyCore'un micronucleus 2.5'i ile yapıyoruz.
# Gereken bir kerelik: arduino-cli, digistump:avr + ATTinyCore:avr çekirdekleri,
# ve `libusb-compat-0.1` (libusb-0.1.so.4) paketi.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="${ARDUINO_CLI:-$HOME/.local/bin/arduino-cli}"
FQBN="digistump:avr:digispark-tiny"
BUILD="$(mktemp -d)"

# micronucleus 2.5 ikilisini bul (ATTinyCore ile gelir)
MN="$(find "$HOME/.arduino15/packages/ATTinyCore/tools/micronucleus" -name micronucleus -type f 2>/dev/null | sort | tail -1)"
if [ -z "${MN:-}" ]; then
  echo "HATA: micronucleus 2.5 bulunamadı. Kur: arduino-cli core install ATTinyCore:avr" >&2
  exit 1
fi

echo ">>> Derleniyor..."
"$CLI" compile --fqbn "$FQBN" --libraries "$DIR" --output-dir "$BUILD" "$DIR/launcher"

HEX="$(ls "$BUILD"/*.hex | head -1)"
echo ">>> Yükleniyor. İSTENDİĞİNDE Digispark'ı çıkarıp yeniden tak (60 sn)."
"$MN" --run --type intel-hex --timeout 60 "$HEX"

rm -rf "$BUILD"
echo ">>> Bitti."
