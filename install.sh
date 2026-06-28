#!/usr/bin/env bash
set -u

LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/openclaw-android-installer.log"
BASE_DIR="$HOME/.openclaw-android"
BIN_DIR="$BASE_DIR/bin"
OC_WORKSPACE="$HOME/.openclaw/workspace"
BOOT_DIR="$HOME/.termux/boot"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

mkdir -p "$LOG_DIR" "$BIN_DIR" "$BASE_DIR/logs" "$OC_WORKSPACE" "$BOOT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

say() { printf "\n==> %s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }
ask_default_yes() {
  printf "%s [Y/n]: " "$1"
  read -r ans || ans=""
  case "${ans:-y}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

append_once() {
  file="$1"; line="$2"
  touch "$file"
  grep -Fqx "$line" "$file" || printf "\n%s\n" "$line" >> "$file"
}

install_script() {
  name="$1"
  target="$BIN_DIR/$name"
  cat > "$target"
  chmod +x "$target"
}

say "OpenClaw Android universal installer"
echo "Log: $LOG_FILE"
echo "Android: $(getprop ro.build.version.release 2>/dev/null || echo unknown)"
echo "Arch: $(uname -m)"

if [ ! -d "$PREFIX" ]; then
  echo "This installer is intended for Termux from F-Droid."
  exit 1
fi

export NODE_OPTIONS=--dns-result-order=ipv4first
append_once "$HOME/.bashrc" 'export NODE_OPTIONS=--dns-result-order=ipv4first'
append_once "$HOME/.profile" 'export NODE_OPTIONS=--dns-result-order=ipv4first'

say "Updating Termux packages"
pkg update -y || warn "pkg update failed; continuing"
pkg upgrade -y || warn "pkg upgrade failed; continuing"

say "Installing dependencies"
pkg install -y curl git nodejs openssh tmux nano android-tools nmap jq coreutils procps termux-api || {
  warn "Some packages failed. Re-run install.sh after checking Termux mirrors."
}

say "Installing OpenClaw official Android method"
if command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw already installed: $(openclaw --version 2>/dev/null || true)"
else
  curl -sL https://myopenclawhub.com/install | bash || warn "OpenClaw installer failed. Check $LOG_FILE."
fi

if ask_default_yes "Try OpenClaw beta update now?"; then
  say "OpenClaw beta dry-run"
  openclaw update --channel beta --dry-run || warn "Beta dry-run failed; keeping current install"
  say "OpenClaw beta update"
  openclaw update --channel beta --yes || warn "Beta update failed; stable/latest remains usable if installed"
fi

say "Writing helper scripts"
install_script phone_control.sh <<'PHONE'
#!/usr/bin/env bash
set -u
usage(){ cat <<'EOF'
Usage: phone-control <command> [args]
home | back | recent | tap X Y | swipe X1 Y1 X2 Y2 [duration_ms] | text TEXT
open-app PACKAGE | open-url URL | screenshot [PATH_ON_SDCARD] | ui-dump | battery | brightness VALUE_0_255
EOF
}
die(){ echo "ERROR: $*" >&2; exit 1; }
quote_shell(){ printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
have_adb_device(){ command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; }
run_android(){
  cmd="$*"
  if command -v rish >/dev/null 2>&1 && rish -c 'id' >/dev/null 2>&1; then rish -c "$cmd"
  elif have_adb_device; then adb shell "$cmd"
  else sh -c "$cmd" 2>/dev/null || die "No rish/adb available. Start Shizuku or connect adb."
  fi
}
cmd="${1:-}"; [ -n "$cmd" ] || { usage; exit 1; }; shift || true
case "$cmd" in
  home) run_android "input keyevent 3" ;;
  back) run_android "input keyevent 4" ;;
  recent) run_android "input keyevent 187" ;;
  tap) [ $# -eq 2 ] || die "tap needs X Y"; run_android "input tap $1 $2" ;;
  swipe) [ $# -ge 4 ] || die "swipe needs X1 Y1 X2 Y2 [duration_ms]"; run_android "input swipe $1 $2 $3 $4 ${5:-300}" ;;
  text) [ $# -ge 1 ] || die "text needs text"; encoded="$(printf "%s" "$*" | sed 's/%/%25/g; s/ /%s/g')"; run_android "input text '$(quote_shell "$encoded")'" ;;
  open-app) [ $# -eq 1 ] || die "open-app needs package"; run_android "monkey -p '$(quote_shell "$1")' -c android.intent.category.LAUNCHER 1" ;;
  open-url) [ $# -eq 1 ] || die "open-url needs URL"; run_android "am start -a android.intent.action.VIEW -d '$(quote_shell "$1")'" ;;
  screenshot) path="${1:-/sdcard/openclaw_screenshot_$(date +%Y%m%d_%H%M%S).png}"; run_android "screencap -p '$(quote_shell "$path")'"; echo "$path" ;;
  ui-dump) remote="/sdcard/openclaw_window_dump.xml"; run_android "uiautomator dump '$remote' >/dev/null"; run_android "cat '$remote'" ;;
  battery) run_android "dumpsys battery" ;;
  brightness) [ $# -eq 1 ] || die "brightness needs 0..255"; case "$1" in *[!0-9]*|"") die "brightness numeric" ;; esac; [ "$1" -ge 0 ] && [ "$1" -le 255 ] || die "brightness 0..255"; run_android "settings put system screen_brightness $1" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
PHONE

install_script setup-shizuku-rish <<'RISH'
#!/usr/bin/env bash
set -u
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
for dir in /sdcard/Shizuku "$HOME/storage/shared/Shizuku"; do
  if [ -f "$dir/rish" ] && [ -f "$dir/rish_shizuku.dex" ]; then
    cp -f "$dir/rish" "$PREFIX/bin/rish"
    cp -f "$dir/rish_shizuku.dex" "$PREFIX/bin/rish_shizuku.dex"
    chmod +x "$PREFIX/bin/rish"
    chmod 0444 "$PREFIX/bin/rish_shizuku.dex" 2>/dev/null || true
    grep -q "RISH_APPLICATION_ID" "$PREFIX/bin/rish" 2>/dev/null || sed -i '2i [ -z "$RISH_APPLICATION_ID" ] && export RISH_APPLICATION_ID="com.termux"' "$PREFIX/bin/rish" 2>/dev/null || true
    echo "Installed rish from $dir"
    rish -c 'id' || { echo "rish installed, but Shizuku is not running/authorized."; exit 2; }
    exit 0
  fi
done
cat <<'EOF'
rish files not found.
Shizuku -> Use Shizuku in terminal apps -> Export files -> /sdcard/Shizuku
Then run: setup-shizuku-rish
EOF
exit 1
RISH

install_script android-hardening <<'HARDEN'
#!/usr/bin/env bash
set -u
run_android(){ cmd="$*"; if command -v rish >/dev/null 2>&1 && rish -c 'id' >/dev/null 2>&1; then rish -c "$cmd"; elif command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then adb shell "$cmd"; else return 127; fi; }
try(){ echo "+ $*"; run_android "$@" || echo "WARN: failed/unsupported: $*"; }
run_android 'id' >/dev/null 2>&1 || { echo "No rish/adb. Start Shizuku or adb, then rerun android-hardening."; exit 1; }
try settings put global settings_enable_monitor_phantom_procs false
try settings get global settings_enable_monitor_phantom_procs
try cmd deviceidle whitelist +com.termux
try cmd deviceidle whitelist +com.termux.boot
try cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow
try cmd appops set com.termux RUN_IN_BACKGROUND allow
try am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS
try am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux
HARDEN

install_script start-openclaw-gateway <<'START'
#!/usr/bin/env bash
set -u
BASE="$HOME/.openclaw-android"
LOG="$BASE/logs/openclaw-gateway.log"
mkdir -p "$BASE/logs"
tmux has-session -t openclaw 2>/dev/null && { echo "openclaw gateway already running"; exit 0; }
tmux new-session -d -s openclaw "bash -lc 'source ~/.bashrc 2>/dev/null || true; export NODE_OPTIONS=--dns-result-order=ipv4first; openclaw gateway >> \"$LOG\" 2>&1'"
echo "openclaw gateway started in tmux session: openclaw"
START

install_script stop-openclaw-gateway <<'STOP'
#!/usr/bin/env bash
tmux kill-session -t openclaw 2>/dev/null && echo "openclaw gateway stopped" || echo "openclaw gateway not running"
STOP

install_script status-openclaw-gateway <<'STATUS'
#!/usr/bin/env bash
echo "tmux:"
tmux ls 2>/dev/null || true
echo
echo "openclaw:"
openclaw --version 2>/dev/null || true
echo
echo "log:"
tail -n 80 "$HOME/.openclaw-android/logs/openclaw-gateway.log" 2>/dev/null || echo "No gateway log yet"
STATUS

install_script restart-openclaw-gateway <<'RESTART'
#!/usr/bin/env bash
stop-openclaw-gateway
sleep 1
start-openclaw-gateway
RESTART

cat > "$OC_WORKSPACE/AGENTS.md" <<'AGENTS'
# OpenClaw Android Termux Agent Rules

You are running inside Android Termux without root.
Use: phone-control <command> [args]

Prefer open-url/open-app/ui-dump before blind coordinates.
Run screenshot or ui-dump before tap when possible.
Do not make purchases, payments, messages, calls, deletions, account changes, or security changes without explicit confirmation.
Do not use arbitrary shell execution for phone control.
If an action is irreversible or security-sensitive, ask for confirmation first.
AGENTS

say "Linking commands"
ln -sf "$BIN_DIR/start-openclaw-gateway" "$PREFIX/bin/oc-start"
ln -sf "$BIN_DIR/stop-openclaw-gateway" "$PREFIX/bin/oc-stop"
ln -sf "$BIN_DIR/restart-openclaw-gateway" "$PREFIX/bin/oc-restart"
ln -sf "$BIN_DIR/status-openclaw-gateway" "$PREFIX/bin/oc-status"
ln -sf "$BIN_DIR/phone_control.sh" "$PREFIX/bin/phone-control"
ln -sf "$BIN_DIR/android-hardening" "$PREFIX/bin/android-hardening"
ln -sf "$BIN_DIR/setup-shizuku-rish" "$PREFIX/bin/setup-shizuku-rish"

cat > "$BOOT_DIR/00-openclaw" <<'BOOT'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock >/dev/null 2>&1 || true
sleep 20
exec /data/data/com.termux/files/usr/bin/oc-start >/dev/null 2>&1
BOOT
chmod +x "$BOOT_DIR/00-openclaw"

say "Shizuku rish setup"
if ask_default_yes "Try setup-shizuku-rish now?"; then
  setup-shizuku-rish || warn "rish not ready; export it from Shizuku and rerun setup-shizuku-rish"
fi

say "API key setup"
printf "Configure API key now? [gemini/deepseek/skip]: "
read -r provider || provider="skip"
case "$provider" in
  gemini|deepseek)
    printf "%s API key: " "$provider"
    stty -echo 2>/dev/null || true
    read -r api_key || api_key=""
    stty echo 2>/dev/null || true
    printf "\n"
    mkdir -p "$HOME/.openclaw"
    chmod 700 "$HOME/.openclaw"
    key_file="$HOME/.openclaw/android-provider.env"
    if [ "$provider" = "gemini" ]; then
      printf "export GEMINI_API_KEY='%s'\n" "$api_key" > "$key_file"
    else
      printf "export DEEPSEEK_API_KEY='%s'\n" "$api_key" > "$key_file"
    fi
    chmod 600 "$key_file"
    append_once "$HOME/.bashrc" 'source ~/.openclaw/android-provider.env 2>/dev/null || true'
    echo "Saved provider env in ~/.openclaw/android-provider.env"
    if command -v openclaw >/dev/null 2>&1; then
      echo "Run openclaw onboard if provider-specific onboarding is still needed."
    fi
    ;;
  *) echo "Skipping API key setup. Run openclaw onboard later." ;;
esac

if ask_default_yes "Run android-hardening now if rish/adb is available?"; then
  android-hardening || warn "android-hardening skipped or partially failed"
fi

if ask_default_yes "Start OpenClaw Gateway now?"; then
  oc-start || warn "gateway start failed"
fi

say "Done"
cat <<EOF
Commands:
  oc-status
  phone-control battery
  phone-control ui-dump
  android-hardening
  tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log

Log:
  $LOG_FILE
EOF
