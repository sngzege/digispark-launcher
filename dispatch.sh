#!/usr/bin/env bash
# Digispark başlatıcı — Linux dağıtıcı.
# Kart bunu çeker ve çalıştırır:
#   curl -fsSL https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.sh | bash
#
# Önce ops/0 çalışır, sonra 1-2-3 döngüsü (q = çıkış).
# İşlem mantığı ops/<N>.sh içinde; buraya sır YAZMA (depo public).

BASE="${BASE:-https://raw.githubusercontent.com/sngzege/digispark-launcher/main/}"
export BASE

# Verilen göreli yolu çeker ve stdout'a yazar. Testte ezilir.
fetch() { curl -fsSL "${BASE}$1"; }

# .env içindeki KEY=VALUE satırlarını güvenli şekilde ortama aktarır.
# Yalnız geçerli kabuk değişken adlarını (harf/alt çizgi ile başlayan) kabul
# eder; yorum (#) ve boş satırlar atlanır. Rastgele kod ÇALIŞTIRMAZ.
load_env() {
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    fi
  done <<< "$1"
}

# .env'den GH_OWNER/GH_REPO/GH_BRANCH geldiyse BASE'i onlardan yeniden kurar.
apply_env_base() {
  if [ -n "${GH_OWNER:-}" ] && [ -n "${GH_REPO:-}" ] && [ -n "${GH_BRANCH:-}" ]; then
    BASE="https://raw.githubusercontent.com/${GH_OWNER}/${GH_REPO}/${GH_BRANCH}/"
    export BASE
  fi
}

# Girdiyi doğrular: 1|2|3 → aynısı, q → "quit", aksi → boş.
read_choice() {
  case "$1" in
    1|2|3) printf '%s' "$1" ;;
    q|Q)   printf 'quit' ;;
    *)     printf '' ;;
  esac
}

# ops/<N>.sh'i çekip çalıştırır. Çekilemezse hata yazıp 1 döner (çökme yok).
run_op() {
  local n="$1" script
  if ! script="$(fetch "ops/${n}.sh")"; then
    echo "hata: ops/${n}.sh çekilemedi (ağ/erişim?)" >&2
    return 1
  fi
  bash -c "$script"
}

main() {
  # curl|bash ile çalışınca stdin borudur; girdiyi kontrol terminalinden oku.
  # tty'yi bir kez fd 3'e aç; her okuma sıradaki satırı alsın (dosyada da akışta da doğru).
  local TTY="${TTY:-/dev/tty}"
  echo "== Digispark başlatıcı =="
  local envtext
  if envtext="$(fetch ".env" 2>/dev/null)"; then
    load_env "$envtext"
    apply_env_base
  fi
  run_op 0 || echo "(işlem 0 çalıştırılamadı)"
  if ! exec 3<"$TTY" 2>/dev/null; then
    echo "girdi alınamıyor ($TTY yok); döngü atlanıyor." >&2
    return 0
  fi
  while true; do
    printf '\nİşlem seç [1-2-3, q=çıkış]: '
    read -r input <&3 || break
    choice="$(read_choice "$input")"
    case "$choice" in
      quit) echo "çıkılıyor."; break ;;
      "")   echo "geçersiz girdi; 1, 2, 3 veya q." ;;
      *)    run_op "$choice" || echo "(işlem $choice çalıştırılamadı)" ;;
    esac
  done
  exec 3<&-
}

# Doğrudan çalıştırıldığında döngüyü başlat; source edildiğinde (test) başlatma.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi
