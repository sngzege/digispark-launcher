#!/usr/bin/env bash
# Digispark launcher - Linux dispatcher.
# Card fetches and runs this:
#   curl -fsSL https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.sh | bash
# Runs ops/0, then an interactive named menu (q = quit). Op logic lives in
# ops/<N>.sh. Never put secrets here (public repo).

BASE="${BASE:-https://raw.githubusercontent.com/sngzege/digispark-launcher/main/}"
export BASE

fetch() { curl -fsSL "${BASE}$1"; }

# Export KEY=VALUE lines from .env into the environment. Ignores comments/blank
# lines and anything that is not a valid shell variable name. Runs no code.
load_env() {
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    fi
  done <<< "$1"
}

# Rebuild BASE from GH_OWNER/GH_REPO/GH_BRANCH when all are set.
apply_env_base() {
  if [ -n "${GH_OWNER:-}" ] && [ -n "${GH_REPO:-}" ] && [ -n "${GH_BRANCH:-}" ]; then
    BASE="https://raw.githubusercontent.com/${GH_OWNER}/${GH_REPO}/${GH_BRANCH}/"
    export BASE
  fi
}

# Parse an ops/menu manifest ('N=Label' lines) into 'N<TAB>Label' rows.
parse_menu() {
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ ^([1-9])=(.*)$ ]]; then
      printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    fi
  done <<< "$1"
}

# Render a manifest as a human menu: "  N - Label".
render_menu() {
  local n label
  while IFS=$'\t' read -r n label; do
    [ -n "$n" ] && printf '  %s - %s\n' "$n" "$label"
  done <<< "$(parse_menu "$1")"
}

# Validate choice: 1-4 -> itself, q -> quit, anything else -> empty.
read_choice() {
  case "$1" in
    1|2|3|4) printf '%s' "$1" ;;
    q|Q)     printf 'quit' ;;
    *)       printf '' ;;
  esac
}

# Fetch and run ops/<N>.sh. On fetch failure, print an error and return 1.
run_op() {
  local n="$1" script
  if ! script="$(fetch "ops/${n}.sh")"; then
    echo "error: could not fetch ops/${n}.sh (network/access?)" >&2
    return 1
  fi
  bash -c "$script"
}

main() {
  local TTY="${TTY:-/dev/tty}"
  echo "== Digispark launcher =="
  local envtext
  if envtext="$(fetch ".env" 2>/dev/null)"; then
    load_env "$envtext"
    apply_env_base
  fi
  run_op 0 || echo "(op 0 failed)"

  local menu
  menu="$(fetch "ops/menu" 2>/dev/null)"

  if ! exec 3<"$TTY" 2>/dev/null; then
    echo "no input available ($TTY missing); skipping menu." >&2
    return 0
  fi
  while true; do
    echo
    echo "Select an operation:"
    if [ -n "$menu" ]; then render_menu "$menu"; else printf '  1  2  3  4\n'; fi
    printf '  q - Quit\n> '
    read -r input <&3 || break
    choice="$(read_choice "$input")"
    case "$choice" in
      quit) echo "bye."; break ;;
      "")   echo "invalid input; choose a listed number or q." ;;
      *)    run_op "$choice" || echo "(op $choice failed)" ;;
    esac
  done
  exec 3<&-
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi
