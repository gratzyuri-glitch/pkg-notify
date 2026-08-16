# update-check

A lightweight Arch Linux update checker that monitors both official repositories and the AUR, then sends KDE Plasma desktop notifications when updates are available.

It supports both **paru** and **yay** and automatically selects the available AUR helper.

## Features

- Checks official Arch Linux repositories for updates
- Checks the AUR for updates
- Supports both `paru` and `yay`
- Prefers `paru` if both are installed
- Distinguishes update results from genuine check failures
- Persistent notifications for updates and errors
- Repeated update/error notifications replace the previous notification instead of stacking indefinitely
- Short-lived notification when the system is up to date
- Prevents overlapping script executions with `flock`
- Uses timeouts for package update checks
- Maintains a local log file
- Automatically limits the log file to approximately 10 MB
- Runs automatically using a systemd user timer
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
