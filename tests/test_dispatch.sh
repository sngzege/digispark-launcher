#!/usr/bin/env bash
# dispatch.sh için birim testleri.
# Çalıştır: bash tests/test_dispatch.sh  (depo kökünden)
set -u

fails=0
assert_eq() { # <gerçek> <beklenen> <ad>
  if [ "$1" = "$2" ]; then
    echo "ok   - $3"
  else
    echo "FAIL - $3 (beklenen '$2', gelen '$1')"
    fails=$((fails + 1))
  fi
}

# Test edilecek birimleri yükle (döngüyü çalıştırmadan).
# shellcheck disable=SC1091
. ./dispatch.sh

# --- read_choice: girdi doğrulama ---
assert_eq "$(read_choice 1)" "1"    "read_choice: '1' geçerli"
assert_eq "$(read_choice 2)" "2"    "read_choice: '2' geçerli"
assert_eq "$(read_choice 3)" "3"    "read_choice: '3' geçerli"
assert_eq "$(read_choice q)" "quit" "read_choice: 'q' çıkış"
assert_eq "$(read_choice x)" ""     "read_choice: geçersiz → boş"
assert_eq "$(read_choice '')" ""    "read_choice: boş girdi → boş"
assert_eq "$(read_choice 4)" ""     "read_choice: aralık dışı → boş"

# --- run_op: başarı (fetch yerel fixture'dan okur) ---
fetch() { cat ./tests/fixtures/op.sh; }
out="$(run_op 1)"; rc=$?
assert_eq "$rc" "0"          "run_op: başarı → 0 döner"
assert_eq "$out" "op çalıştı" "run_op: çekilen betiği çalıştırır"

# --- run_op: ağ yok / çekilemedi → çökme yok, 1 döner ---
fetch() { return 1; }
run_op 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "1"         "run_op: fetch başarısız → 1 döner"

# --- main: girdiyi borudan DEĞİL $TTY'den okur (curl|bash senaryosu) ---
# fetch, çekilen yolu yankılayan bir betik döndürür; böylece hangi op'un
# çalıştığını görebiliriz. Girdi $TTY dosyasından gelir, stdin'den değil.
fetch() { echo "echo RAN:$1"; }
ttyfile="$(mktemp)"; printf '2\nq\n' > "$ttyfile"
# stdin'e kasten çöp koy; doğru uygulama bunu YOK saymalı ($TTY'den okumalı).
out="$(TTY="$ttyfile" main <<<'9')"
rm -f "$ttyfile"
case "$out" in
  *RAN:ops/0.sh*) assert_eq "ok" "ok" "main: ops/0 otomatik çalışır" ;;
  *) assert_eq "$out" "RAN:ops/0.sh (içerir)" "main: ops/0 otomatik çalışır" ;;
esac
case "$out" in
  *RAN:ops/2.sh*) assert_eq "ok" "ok" "main: \$TTY'den '2' okunup ops/2 çalışır" ;;
  *) assert_eq "$out" "RAN:ops/2.sh (içerir)" "main: \$TTY'den '2' okunup ops/2 çalışır" ;;
esac

# --- load_env: .env içeriğini güvenli şekilde export eder ---
unset TEST_KEY_X TEST_KEY_Y BAD 2>/dev/null
load_env $'# yorum satiri\n\nTEST_KEY_X=deger1\nBAD KEY=nope\nTEST_KEY_Y=deger2'
assert_eq "${TEST_KEY_X:-}" "deger1" "load_env: gecerli KEY=VALUE export edilir"
assert_eq "${TEST_KEY_Y:-}" "deger2" "load_env: ikinci gecerli satir da export edilir"
assert_eq "${BAD:-}" ""        "load_env: bosluklu/gecersiz anahtar atlanir"

# --- apply_env_base: GH_OWNER/GH_REPO/GH_BRANCH varsa BASE'i yeniden kurar ---
GH_OWNER=foo; GH_REPO=bar; GH_BRANCH=dev
apply_env_base
assert_eq "$BASE" "https://raw.githubusercontent.com/foo/bar/dev/" "apply_env_base: GH_* degerlerinden BASE kurulur"
unset GH_OWNER GH_REPO GH_BRANCH

echo "---"
if [ "$fails" -eq 0 ]; then echo "TÜM TESTLER GEÇTİ"; else echo "$fails test başarısız"; exit 1; fi
