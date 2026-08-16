# pkg-notify

A lightweight Arch Linux package update checker that runs automatically with a systemd user timer and sends desktop notifications when updates are available.

`pkg-notify` checks both the official Arch Linux repositories and the AUR. It supports both `paru` and `yay`, preferring `paru` when both are installed.

## Features

- Checks official Arch Linux repositories for updates
- Checks the AUR for updates
- Supports both `paru` and `yay`
- Prefers `paru` if both are installed
- Runs automatically using a systemd user timer
- Distinguishes update results from genuine check failures
- Persistent notifications for updates and errors
- Update notifications stay visible until you close them
- Repeated update/error checks replace the existing notification instead of stacking indefinitely
- "System up to date" notifications disappear automatically after a few seconds
- Prevents overlapping script executions with `flock`
- Uses timeouts for package update checks
- Maintains a local log file
- Automatically limits the log file to approximately 10 MB
- Does not require root privileges to run the checker

## Requirements

- Arch Linux
- `bash`
- `pacman-contrib`
- `libnotify`
- `coreutils`
- `util-linux`
- One of:
  - `paru`
  - `yay`
- KDE Plasma or another desktop environment providing `notify-send`

Install the required packages with:

```bash
sudo pacman -S pacman-contrib libnotify
```

## How it works

The package checker is run by a **systemd user timer**, so it can check for updates automatically in the background without requiring a system-wide service or root privileges.

When updates are found, `pkg-notify` sends a persistent desktop notification. The notification remains on screen until you dismiss it.

If no updates are available, a normal notification is shown briefly and then disappears automatically.

Update and error notifications use stable notification IDs. If another check finds the same type of notification later, it replaces the existing notification rather than creating an unlimited stack of persistent notifications.

A lock file prevents multiple instances of the checker from running at the same time.

## Logging

The checker writes its log to:

```text
~/.local/share/pkg-notify.log
```

The log is automatically truncated when it reaches approximately 10 MB.

## systemd

`pkg-notify` uses a user service and timer:

```text
pkg-notify.service
pkg-notify.timer
```

The service runs the checker, while the timer controls how often it is run.

## License

See [LICENSE](LICENSE).
