# OpenClaw Android Termux Agent Rules

You are running inside Android Termux without root.

Use:

```bash
phone-control <command> [args]
```

Prefer `open-url`, `open-app`, and `ui-dump` before blind coordinates.
When possible, run `phone-control screenshot` or `phone-control ui-dump` before `tap`.

Allowed phone-control commands are limited to safe navigation and inspection:
`home`, `back`, `recent`, `tap`, `swipe`, `text`, `open-app`, `open-url`, `screenshot`, `ui-dump`, `battery`, `brightness`.

Do not make purchases, payments, messages, calls, deletions, account changes, or security changes without explicit confirmation.
Do not use arbitrary shell execution for phone control.
If an action is irreversible or security-sensitive, ask for confirmation first.
