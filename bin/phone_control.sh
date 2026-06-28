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

quote_shell() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

have_adb_device() {
  command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1
}

run_android() {
  local cmd="$*"
  if command -v rish >/dev/null 2>&1 && rish -c 'id' >/dev/null 2>&1; then
    rish -c "$cmd"
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
    run_android "input tap $1 $2"
    ;;
  swipe)
    [ $# -ge 4 ] || die "swipe needs X1 Y1 X2 Y2 [duration_ms]"
    run_android "input swipe $1 $2 $3 $4 ${5:-300}"
    ;;
  text)
    [ $# -ge 1 ] || die "text needs text"
    encoded="$(printf "%s" "$*" | sed 's/%/%25/g; s/ /%s/g')"
    run_android "input text '$(quote_shell "$encoded")'"
    ;;
  open-app)
    [ $# -eq 1 ] || die "open-app needs package"
    run_android "monkey -p '$(quote_shell "$1")' -c android.intent.category.LAUNCHER 1"
    ;;
  open-url)
    [ $# -eq 1 ] || die "open-url needs URL"
    run_android "am start -a android.intent.action.VIEW -d '$(quote_shell "$1")'"
    ;;
  screenshot)
    path="${1:-/sdcard/openclaw_screenshot_$(date +%Y%m%d_%H%M%S).png}"
    run_android "screencap -p '$(quote_shell "$path")'"
    echo "$path"
    ;;
  ui-dump)
    remote="/sdcard/openclaw_window_dump.xml"
    run_android "uiautomator dump '$remote' >/dev/null"
    if have_adb_device; then
      adb shell "cat '$remote'"
    else
      run_android "cat '$remote'"
    fi
    ;;
  battery)
    run_android "dumpsys battery"
    ;;
  brightness)
    [ $# -eq 1 ] || die "brightness needs 0..255"
    case "$1" in *[!0-9]*|"") die "brightness must be numeric" ;; esac
    [ "$1" -ge 0 ] && [ "$1" -le 255 ] || die "brightness must be 0..255"
    run_android "settings put system screen_brightness $1"
    ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
