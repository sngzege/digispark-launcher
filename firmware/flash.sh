#!/usr/bin/env bash
# Digispark başlatıcı firmware'ini derleyip karta yükler.
# Kullanım: bash firmware/flash.sh
# Yükleme sırasında micronucleus kartı bekler → istendiğinde kartı ÇIKAR-TAK.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="${ARDUINO_CLI:-$HOME/.local/bin/arduino-cli}"
FQBN="digistump:avr:digispark-tiny"

echo ">>> Derleniyor..."
"$CLI" compile --fqbn "$FQBN" --libraries "$DIR" "$DIR/launcher"

echo ">>> Yükleme başlıyor. İSTENDİĞİNDE Digispark'ı çıkarıp yeniden tak (60 sn)."
"$CLI" upload --fqbn "$FQBN" --libraries "$DIR" "$DIR/launcher"
echo ">>> Bitti."
