#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
Usage: phone-control <command> [args]

Safe commands:
  home | back | recent
  tap X Y
  swipe X1 Y1 X2 Y2 [duration_ms]
  text TEXT
  open-app PACKAGE
  open-url URL
  screenshot [PATH_ON_SDCARD]
  ui-dump
  battery
  brightness VALUE_0_255
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
is_uint() { case "${1:-}" in ""|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
valid_package() { printf "%s" "$1" | grep -Eq '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$'; }
valid_url() { printf "%s" "$1" | grep -Eq '^(https?://|geo:|market:|intent:)[^[:space:]`$\\]+$'; }
valid_screenshot_path() {
  case "$1" in *".."*) return 1 ;; esac
  printf "%s" "$1" | grep -Eq '^/sdcard/[A-Za-z0-9._/-]+\.png$'
}
quote_shell() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
have_adb_device() { command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; }

run_android() {
  local cmd="$*"
  export RISH_APPLICATION_ID="${RISH_APPLICATION_ID:-com.termux}"
  if command -v rish >/dev/null 2>&1 && RISH_APPLICATION_ID=com.termux rish -c 'id' >/dev/null 2>&1; then
    RISH_APPLICATION_ID=com.termux rish -c "$cmd"
  elif have_adb_device; then
    adb shell "$cmd"
  else
    sh -c "$cmd" 2>/dev/null || die "No rish/adb available. Start Shizuku or connect adb wireless debugging."
  fi
}

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 1; }
shift || true

case "$cmd" in
  home) run_android "input keyevent 3" ;;
  back) run_android "input keyevent 4" ;;
  recent) run_android "input keyevent 187" ;;
  tap)
    [ $# -eq 2 ] || die "tap needs X Y"
    is_uint "$1" && is_uint "$2" || die "tap coordinates must be non-negative integers"
    run_android "input tap $1 $2"
    ;;
  swipe)
    [ $# -ge 4 ] || die "swipe needs X1 Y1 X2 Y2 [duration_ms]"
    is_uint "$1" && is_uint "$2" && is_uint "$3" && is_uint "$4" && is_uint "${5:-300}" || die "swipe values must be non-negative integers"
    run_android "input swipe $1 $2 $3 $4 ${5:-300}"
    ;;
  text)
    [ $# -ge 1 ] || die "text needs text"
    encoded="$(printf "%s" "$*" | sed 's/%/%25/g; s/ /%s/g')"
    run_android "input text '$(quote_shell "$encoded")'"
    ;;
  open-app)
    [ $# -eq 1 ] || die "open-app needs package"
    valid_package "$1" || die "invalid Android package name"
    run_android "monkey -p '$(quote_shell "$1")' -c android.intent.category.LAUNCHER 1"
    ;;
  open-url)
    [ $# -eq 1 ] || die "open-url needs URL"
    valid_url "$1" || die "URL scheme must be http://, https://, geo:, market:, or intent:"
    run_android "am start -a android.intent.action.VIEW -d '$(quote_shell "$1")'"
    ;;
  screenshot)
    path="${1:-/sdcard/openclaw_screenshot_$(date +%Y%m%d_%H%M%S).png}"
    valid_screenshot_path "$path" || die "screenshot path must be /sdcard/...png and must not contain .."
    run_android "screencap -p '$(quote_shell "$path")'"
    echo "$path"
    ;;
  ui-dump)
    remote="/sdcard/openclaw_window_dump.xml"
    run_android "uiautomator dump '$remote' >/dev/null"
    run_android "cat '$remote'"
    ;;
  battery) run_android "dumpsys battery" ;;
  brightness)
    [ $# -eq 1 ] || die "brightness needs 0..255"
    is_uint "$1" || die "brightness must be numeric"
    [ "$1" -ge 0 ] && [ "$1" -le 255 ] || die "brightness must be 0..255"
    run_android "settings put system screen_brightness $1"
    ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
