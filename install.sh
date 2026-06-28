#!/usr/bin/env bash
set -u

# Interactive installer. Download to a file and run with bash; do not use curl | bash.
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/SauloTassara/openclaw-android-universal-installer/main}"
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/openclaw-android-installer.log"
BASE_DIR="$HOME/.openclaw-android"
BIN_DIR="$BASE_DIR/bin"
OC_DIR="$HOME/.openclaw"
OC_WORKSPACE="$OC_DIR/workspace"
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

ask_default_no() {
  printf "%s [y/N]: " "$1"
  read -r ans || ans=""
  case "${ans:-n}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

append_once() {
  file="$1"
  line="$2"
  touch "$file"
  grep -Fqx "$line" "$file" || printf "\n%s\n" "$line" >> "$file"
}

download_bin() {
  name="$1"
  url="$RAW_BASE/bin/$name"
  target="$BIN_DIR/$name"
  say "Installing $name"
  if ! curl -fsSL "$url" -o "$target"; then
    echo "ERROR: failed to download $url" >&2
    return 1
  fi
  chmod +x "$target"
}

link_bin() {
  source="$1"
  target="$2"
  ln -sf "$BIN_DIR/$source" "$PREFIX/bin/$target"
}

say "OpenClaw Android universal installer"
echo "Log: $LOG_FILE"
echo "Android: $(getprop ro.build.version.release 2>/dev/null || echo unknown)"
echo "Arch: $(uname -m)"
echo "RAW_BASE: $RAW_BASE"

if [ ! -d "$PREFIX" ]; then
  echo "This installer is intended for Termux from F-Droid."
  exit 1
fi

export NODE_OPTIONS=--dns-result-order=ipv4first
append_once "$HOME/.bashrc" 'export NODE_OPTIONS=--dns-result-order=ipv4first'
append_once "$HOME/.profile" 'export NODE_OPTIONS=--dns-result-order=ipv4first'
append_once "$HOME/.bashrc" 'export RISH_APPLICATION_ID=com.termux'
append_once "$HOME/.profile" 'export RISH_APPLICATION_ID=com.termux'

say "Updating Termux packages"
pkg update -y || warn "pkg update failed; continuing"
pkg upgrade -y || warn "pkg upgrade failed; continuing"

say "Installing dependencies"
pkg install -y curl git nodejs openssh tmux nano android-tools nmap jq coreutils procps termux-api termux-exec || {
  warn "Some packages failed. Re-run install.sh after checking Termux mirrors."
}

if ! command -v termux-wake-lock >/dev/null 2>&1; then
  warn "termux-wake-lock not found. Install Termux:API app from F-Droid for reliable wake locks."
fi

say "Downloading helper scripts from repo"
download_bin phone_control.sh || exit 1
download_bin setup-shizuku-rish || exit 1
download_bin android-hardening || exit 1
download_bin fix-termux-pacman || exit 1
download_bin start-openclaw-gateway || exit 1
download_bin run-openclaw-gateway || exit 1
download_bin stop-openclaw-gateway || exit 1
download_bin restart-openclaw-gateway || exit 1
download_bin status-openclaw-gateway || exit 1
download_bin setup-local-embeddings || exit 1

say "Linking commands"
link_bin start-openclaw-gateway oc-start
link_bin stop-openclaw-gateway oc-stop
link_bin restart-openclaw-gateway oc-restart
link_bin status-openclaw-gateway oc-status
link_bin phone_control.sh phone-control
link_bin android-hardening android-hardening
link_bin setup-shizuku-rish setup-shizuku-rish
link_bin fix-termux-pacman fix-termux-pacman
link_bin setup-local-embeddings oc-setup-local-embeddings

if command -v pacman >/dev/null 2>&1; then
  say "Termux pacman preflight"
  fix-termux-pacman || warn "pacman preflight failed; OpenClaw installer may still repair or fail with details"
fi

say "Installing OpenClaw official latest/stable"
if command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw already installed: $(openclaw --version 2>/dev/null || true)"
else
  curl -fsSL https://myopenclawhub.com/install | bash || warn "OpenClaw core install failed. Check $LOG_FILE."
fi

if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
  openclaw config validate || true
else
  warn "OpenClaw core not installed; gateway will not work until fixed."
fi

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

# Keep Termux:Boot simple and deterministic. Do not call oc-start here: boot
# sessions may not have interactive profile fixes loaded yet, and npm binaries
# with /usr/bin/env shebangs can fail unless termux-exec/node fallback is set.
cat > "$BOOT_DIR/00-openclaw" <<'BOOT'
#!/data/data/com.termux/files/usr/bin/sh

PREFIX="/data/data/com.termux/files/usr"
BASE="$HOME/.openclaw-android"
LOG="$BASE/logs/boot.log"
TERMUX_EXEC_LIB="$PREFIX/lib/libtermux-exec.so"

if [ -x "$PREFIX/bin/termux-wake-lock" ]; then
  "$PREFIX/bin/termux-wake-lock" >/dev/null 2>&1 || true
fi

# Android can report boot completed before networking, storage, or package
# manager state is stable. 60s is conservative for Android 12 through stock
# Pixel-class Android 17.
sleep "${OPENCLAW_BOOT_DELAY:-60}"

export PATH="$PREFIX/bin:$HOME/.local/bin:$BASE/bin:$PATH"
export NODE_OPTIONS="${NODE_OPTIONS:-} --dns-result-order=ipv4first"
export RISH_APPLICATION_ID="${RISH_APPLICATION_ID:-com.termux}"

if [ -f "$TERMUX_EXEC_LIB" ]; then
  LD_PRELOAD="$TERMUX_EXEC_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
  export LD_PRELOAD
fi

mkdir -p "$BASE/logs"
printf '%s [boot] starting 00-openclaw\n' "$(date -Iseconds)" >> "$LOG"
"$BASE/bin/start-openclaw-gateway" >> "$LOG" 2>&1
code="$?"
printf '%s [boot] finished with code %s\n' "$(date -Iseconds)" "$code" >> "$LOG"
exit "$code"
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
    if [ -z "$api_key" ]; then
      warn "Empty key; existing provider env was not modified."
    else
      mkdir -p "$OC_DIR"
      chmod 700 "$OC_DIR"
      key_file="$OC_DIR/android-provider.env"
      if [ "$provider" = "gemini" ]; then
        printf 'export GEMINI_API_KEY=%q\n' "$api_key" > "$key_file"
      else
        printf 'export DEEPSEEK_API_KEY=%q\n' "$api_key" > "$key_file"
      fi
      chmod 600 "$key_file"
      append_once "$HOME/.bashrc" 'source ~/.openclaw/android-provider.env 2>/dev/null || true'
      echo "Saved provider env in ~/.openclaw/android-provider.env"
      echo "Run openclaw onboard if provider-specific onboarding is still needed."
    fi
    ;;
  *) echo "Skipping API key setup. Existing env was not modified." ;;
esac

if ask_default_yes "Run android-hardening now if rish/adb is available?"; then
  android-hardening || warn "android-hardening skipped or partially failed"
fi

if command -v openclaw >/dev/null 2>&1; then
  if ask_default_yes "Start OpenClaw Gateway now?"; then
    oc-start || warn "gateway start failed"
  fi
  echo "Experimental local embeddings are not recommended during first install/test."
  if ask_default_no "Configure experimental local embeddings now?"; then
    oc-setup-local-embeddings || warn "local embeddings setup failed"
  else
    echo "Later: run oc-setup-local-embeddings"
  fi
else
  warn "Skipping gateway start and local embeddings because openclaw is not installed."
fi

say "Done"
cat <<EOF
Commands:
  openclaw --version
  openclaw config validate
  oc-status
  phone-control battery
  phone-control ui-dump
  android-hardening
  tmux ls
  tail -n 100 ~/.openclaw-android/logs/boot.log
  tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log

Log:
  $LOG_FILE
EOF
