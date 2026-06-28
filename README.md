# OpenClaw Android Universal Installer

Universal Termux installer for OpenClaw on Android without root and without a full proot Linux distro.

Target: Android 12+, including stock Pixel-class Android 17, Termux from F-Droid, Termux:Boot, Shizuku, Gemini first, DeepSeek later.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/SauloTassara/openclaw-android-universal-installer/main/install.sh | bash
```

## Manual steps that cannot be fully automated

1. Install Termux from F-Droid.
2. Install Termux:Boot from F-Droid.
3. Install Shizuku.
4. Start Shizuku using Wireless Debugging.
5. In Shizuku, export terminal files: `Use Shizuku in terminal apps -> Export files -> /sdcard/Shizuku`.
6. Run `install.sh`.

The installer then creates OpenClaw helpers, Termux:Boot autostart, `phone-control`, `android-hardening`, and tmux gateway scripts.

## What gets installed

- OpenClaw using the official Android-friendly installer path: `curl -sL https://myopenclawhub.com/install | bash`
- Optional beta update:

```bash
openclaw update --channel beta --dry-run
openclaw update --channel beta --yes
```

If beta fails, install does not abort. Stable/latest remains the fallback.

Dependencies: `curl`, `git`, `nodejs`, `openssh`, `tmux`, `nano`, `android-tools`, `nmap`, `jq`, `coreutils`, `procps`.

`NODE_OPTIONS=--dns-result-order=ipv4first` is added for Termux DNS stability.

## API keys

During install, choose:

- `gemini`
- `deepseek`
- `skip`

Keys are stored in:

```bash
~/.openclaw/android-provider.env
```

For Gemini:

```bash
export GEMINI_API_KEY='...'
openclaw onboard
```

For DeepSeek later:

```bash
export DEEPSEEK_API_KEY='...'
openclaw onboard
```

OpenClaw provider support can change, so `openclaw onboard` is the canonical final provider setup path.

## Gateway commands

```bash
oc-start
oc-stop
oc-restart
oc-status
```

Gateway runs in tmux session `openclaw`:

```bash
tmux ls
tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log
```

Termux:Boot script:

```bash
~/.termux/boot/00-openclaw
```

It takes a wake lock, waits 20 seconds, and starts the gateway.

## Phone control

```bash
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

It prefers `rish`, then connected `adb shell`, then limited local fallback.

No arbitrary shell, SMS, calls, WhatsApp, purchases, app uninstall, account changes, file deletion, or dangerous permissions are exposed by default.

## Android hardening

Run:

```bash
android-hardening
```

It tries, tolerantly:

```bash
settings put global settings_enable_monitor_phantom_procs false
settings get global settings_enable_monitor_phantom_procs
cmd deviceidle whitelist +com.termux
cmd deviceidle whitelist +com.termux.boot
cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow
cmd appops set com.termux RUN_IN_BACKGROUND allow
```

Then it opens Android battery/app settings screens for manual confirmation when Android blocks command-only changes:

```bash
am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS
am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux
```

Android does not allow every battery restriction to be disabled 100% by script on every device.

## If Shizuku or the phone restarts, is everything lost?

No.

Not lost:

- OpenClaw install
- Termux install
- Termux:Boot install
- Autostart script
- OpenClaw workspace
- Usually the Phantom Process Killer setting if it was written to `settings global`

OpenClaw Gateway can start with Termux:Boot without Shizuku.

What is lost until you start Shizuku again:

- `phone-control` through `rish`
- taps, swipes, screenshots, `uiautomator`, and ADB-like commands through Shizuku

On non-root Android, Shizuku started via Wireless Debugging must be started again after reboot.

## Update OpenClaw

```bash
openclaw update --channel beta --dry-run
openclaw update --channel beta --yes
```

Fallback stable:

```bash
openclaw update --channel stable --yes
```

## Uninstall

```bash
oc-stop
rm -rf ~/.openclaw-android
rm -f ~/.termux/boot/00-openclaw
rm -f $PREFIX/bin/oc-start $PREFIX/bin/oc-stop $PREFIX/bin/oc-restart $PREFIX/bin/oc-status
rm -f $PREFIX/bin/phone-control $PREFIX/bin/android-hardening $PREFIX/bin/setup-shizuku-rish
```

OpenClaw itself may have its own uninstall/update method depending on the official installer version used.

## Troubleshooting

Check installer log:

```bash
tail -n 200 ~/.logs/openclaw-android-installer.log
```

Check gateway:

```bash
oc-status
tmux ls
tail -n 100 ~/.openclaw-android/logs/openclaw-gateway.log
```

If `rish` is missing:

```bash
termux-setup-storage
setup-shizuku-rish
```

Then in Shizuku export files to `/sdcard/Shizuku` and rerun `setup-shizuku-rish`.

If `phone-control ui-dump` fails, restart Shizuku and authorize Termux.

If Android kills background tasks, run:

```bash
android-hardening
```

Then manually set Termux battery usage to unrestricted in Android settings.
