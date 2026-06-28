# OpenClaw Android Universal Installer

Stable Termux installer for OpenClaw on Android without root, without proot, and without local models by default.

Target: Android 12+, Samsung One UI, and stock Pixel-class Android 17. Default flow is OpenClaw official latest/stable with Gemini or DeepSeek cloud.

## Install

Do not use `curl | bash` for this installer. It is interactive, and piping the script can make `read` consume script bytes instead of keyboard input.

Official main command:

```bash
curl -fsSL https://raw.githubusercontent.com/SauloTassara/openclaw-android-universal-installer/main/install.sh -o ~/install-openclaw-android.sh && chmod +x ~/install-openclaw-android.sh && bash ~/install-openclaw-android.sh
```

Branch test command:

```bash
curl -fsSL https://raw.githubusercontent.com/SauloTassara/openclaw-android-universal-installer/stabilize-latest-android-install/install.sh -o ~/install-openclaw-android.sh && chmod +x ~/install-openclaw-android.sh && RAW_BASE=https://raw.githubusercontent.com/SauloTassara/openclaw-android-universal-installer/stabilize-latest-android-install bash ~/install-openclaw-android.sh
```

When testing a branch, `install.sh` must receive `RAW_BASE` from that same branch. Otherwise it downloads helper scripts from `main`.

## Manual setup

1. Install Termux from F-Droid, not Play Store.
2. Install Termux:Boot from F-Droid.
3. Open Termux:Boot once. Its help screen is normal. Opening it once lets Android run `~/.termux/boot/*` at boot.
4. Install Termux:API app from F-Droid, recommended for reliable wake locks.
5. Install Shizuku.
6. Start Shizuku using Wireless Debugging.
7. In Shizuku, export terminal files: `Use Shizuku in terminal apps -> Export files -> /sdcard/Shizuku`.
8. Run the installer.

The installer creates:

```bash
~/.openclaw-android/bin/
~/.openclaw-android/logs/
~/.openclaw/workspace/
~/.termux/boot/00-openclaw
```

Boot script behavior:

```bash
termux-wake-lock  # if available
sleep 20
oc-start
```

`termux-wake-lock` needs both the Termux package `termux-api` and the Termux:API Android app. If missing, install continues and warns.

## OpenClaw version policy

Stable/latest is the target on Android.

Observed working stable:

```text
OpenClaw 2026.6.10 (aa69b12)
```

The installer does not attempt beta by default. In real Android 12 / Termux testing, beta update failed on native dependencies (`node-gyp`, `tree-sitter-bash`, Node v26.3.1). That is not a production path.

Manual experimental beta only:

```bash
openclaw update --channel beta --dry-run
openclaw update --channel beta --yes
```

Stable update:

```bash
openclaw update --channel stable --yes
```

## API keys

During install, choose:

- `gemini`
- `deepseek`
- `skip`

Keys are written to:

```bash
~/.openclaw/android-provider.env
```

Permissions:

```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/android-provider.env
```

The key file is sourced by gateway scripts. Keys are never printed by `oc-status`.

If provider onboarding is still needed:

```bash
openclaw onboard
openclaw doctor --fix
openclaw config validate
oc-restart
```

If onboarding says `Gateway service install not supported on android`, that is expected. Android uses tmux + Termux:Boot, not a system service.

## Gateway commands

Use these. Do not run `openclaw gateway` manually if tmux already has the gateway running, or you may see a false error like `Port 18789 is already in use`.

```bash
oc-start
oc-stop
oc-restart
oc-status
```

Success looks like:

```text
openclaw gateway started in tmux session: openclaw
openclaw: 1 windows
Config valid: ~/.openclaw/openclaw.json
```

`oc-start` runs `openclaw config validate` first and refuses to start if config is invalid.

## Phone control

```bash
setup-shizuku-rish
phone-control battery
phone-control ui-dump
phone-control screenshot
phone-control open-url https://openclaw.ai
phone-control open-app com.android.settings
phone-control tap 500 900
phone-control swipe 500 1500 500 500 400
phone-control text hello
phone-control brightness 120
```

`phone-control battery` working confirms the rish/adb path. Battery `temperature: 336` means 33.6 C.

No arbitrary shell, SMS, calls, WhatsApp, purchases, app uninstall, account changes, file deletion, or dangerous permissions are exposed.

If rish fails with:

```text
RISH_APPLICATION_ID is not set
```

Run:

```bash
echo 'export RISH_APPLICATION_ID=com.termux' >> ~/.bashrc
export RISH_APPLICATION_ID=com.termux
setup-shizuku-rish
```

`uid=2000(shell)` means success.

## Android hardening

```bash
android-hardening
```

It tries:

```bash
settings put global settings_enable_monitor_phantom_procs false
settings get global settings_enable_monitor_phantom_procs
cmd deviceidle whitelist +com.termux
cmd deviceidle whitelist +com.termux.boot
cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow
cmd appops set com.termux RUN_IN_BACKGROUND allow
```

Then it opens battery/app settings screens for manual confirmation. Android does not allow every battery restriction to be disabled by script.

## Samsung One UI permanence

Set these to Unrestricted battery:

- Termux
- Termux:Boot
- Termux:API
- Shizuku

Also:

- Remove them from Sleeping apps and Deep sleeping apps.
- Do not use Force stop.
- Removing Termux from recent apps is OK, but Force stop breaks background work.

Developer options:

- Stay awake: ON for testing
- USB debugging: ON
- Wireless debugging: ON
- Don't keep activities: OFF
- Background process limit: Standard limit
- Suspend execution for cached apps: OFF/Disabled if present

## Persistence test

1. Confirm:

```bash
oc-status
tmux ls
```

2. Send Telegram `/status`.
3. Turn screen off for 30-60 min, send `/status`.
4. Test again after 2-4 h.
5. Remove Termux from recent apps, wait 30 min, send `/status`.
6. Reboot, wait 1-2 min, send `/status`.

If it does not respond after reboot:

```bash
tmux ls
oc-status
tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log
```

If Telegram replies `You are not authorized to use this command`, gateway and token may be fine. Authorize your Telegram user ID. Get it with `@userinfobot`, then rerun `openclaw onboard` or edit OpenClaw config, then:

```bash
oc-stop
oc-start
```

## If curl is broken before install

Observed Termux error:

```text
CANNOT LINK EXECUTABLE "curl": cannot locate symbol "SSL_set_quic_tls_transport_params"
```

Repair:

```bash
pkg update -y
pkg upgrade -y
pkg reinstall -y openssl libngtcp2 libnghttp2 libnghttp3 libcurl curl
hash -r
curl --version
```

## If pacman/glibc-runner fails

Observed:

```text
failed to initialize alpm library
database is incorrect version
try running pacman-db-upgrade
failed retrieving file ... service.termux-pacman.dev : 403
failed to install glibc-runner
```

The installer calls:

```bash
fix-termux-pacman
```

You can rerun it manually. It backs up the mirrorlist, disables the known 403 mirror, writes known working mirrors, runs `pacman-db-upgrade` if available, and then `pacman -Syyu --noconfirm`.

## Shizuku after reboot

Nothing important is lost:

- OpenClaw install
- Termux install
- Termux:Boot install
- Autostart script
- OpenClaw workspace
- Usually Phantom Process Killer setting if written to global settings

OpenClaw Gateway can start without Shizuku.

What is unavailable until Shizuku is started again:

- `phone-control` through `rish`
- taps, swipes, screenshots, `uiautomator`, ADB-like commands

On non-root Android, Shizuku via Wireless Debugging must be started again after reboot.

## Experimental local embeddings

Do not enable during first install/test.

OpenClaw local embeddings can use `@openclaw/llama-cpp-provider` with GGUF models. Suggested experiment:

```text
EmbeddingGemma 300M Q8_0
hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf
```

Not enabled by default. It is manual-only:

```bash
oc-setup-local-embeddings
```

Reason: native deps can fail on Termux/Android. Also, current OpenClaw versions may not expose `openclaw memory`.

The setup script does not patch `~/.openclaw/openclaw.json` automatically. It writes:

```bash
~/.openclaw-android/local-embeddings-snippet.json5
```

using the current schema shape:

```text
agents.defaults.memorySearch
```

Then validate manually:

```bash
openclaw doctor --fix
openclaw config validate
```

## Troubleshooting commands

```bash
openclaw --version
openclaw config validate
oc-status
tmux ls
phone-control battery
phone-control ui-dump | head -n 20
tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log
```

## Uninstall helpers

```bash
oc-stop
rm -rf ~/.openclaw-android
rm -f ~/.termux/boot/00-openclaw
rm -f $PREFIX/bin/oc-start $PREFIX/bin/oc-stop $PREFIX/bin/oc-restart $PREFIX/bin/oc-status
rm -f $PREFIX/bin/phone-control $PREFIX/bin/android-hardening $PREFIX/bin/setup-shizuku-rish
rm -f $PREFIX/bin/fix-termux-pacman $PREFIX/bin/oc-setup-local-embeddings
```

OpenClaw itself may have its own uninstall/update method depending on the official installer version used.
