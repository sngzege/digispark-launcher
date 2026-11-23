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

echo "---"
if [ "$fails" -eq 0 ]; then echo "TÜM TESTLER GEÇTİ"; else echo "$fails test başarısız"; exit 1; fi
